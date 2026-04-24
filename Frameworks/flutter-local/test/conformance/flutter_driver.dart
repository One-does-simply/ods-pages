/// FlutterDriver — ODS conformance driver for the `ods_flutter_local`
/// framework.
///
/// Mirrors the TS ReactDriver at
/// Frameworks/react-web/tests/conformance/react-driver.ts. The job of both
/// drivers is to present the same observable behavior to the same scenario
/// running the same spec.
///
/// MVP implements the `core` + submit/showMessage/navigate capabilities.
/// Unimplemented methods throw `UnimplementedError`; the scenario runner
/// will skip any scenario whose declared capabilities exceed what we
/// advertise.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ods_flutter_local/engine/aggregate_evaluator.dart';
import 'package:ods_flutter_local/engine/app_engine.dart';
import 'package:ods_flutter_local/engine/formula_evaluator.dart';
import 'package:ods_flutter_local/models/ods_action.dart';
import 'package:ods_flutter_local/models/ods_app.dart';
import 'package:ods_flutter_local/models/ods_component.dart';

import 'contract.dart';

class FlutterDriver implements OdsDriver {
  @override
  final Set<String> capabilities = const {
    'core',
    'action:submit',
    'action:showMessage',
    'action:navigate',
    'action:delete',
    'action:update',
    'rowActions',
    'formulas',
    'summary',
    'tabs',
    'auth:multiUser',
    'auth:selfRegistration',
    'auth:ownership',
  };

  AppEngine? _engine;
  Directory? _tempDir;
  String? _specJson;
  /// Fixed "now" for magic default resolution (set by setClock). Null means
  /// "use wall-clock time." Lazily consulted by formValues.
  DateTime? _fakeNow;

  // -- Lifecycle -------------------------------------------------------------

  @override
  Future<void> mount(OdsSpec spec) async {
    _specJson = jsonEncode(spec);
    await _boot(_specJson!);
  }

  @override
  Future<void> unmount() async {
    _engine?.dispose();
    _engine = null;
    _specJson = null;
    _fakeNow = null;
    await _cleanupTempDir();
  }

  @override
  Future<void> reset() async {
    // Keep the spec; rebuild the engine (and its DataStore) over a fresh
    // temp dir so data state is empty. Cheapest path to "same spec, no
    // data" given AppEngine constructs its own DataStore internally.
    if (_specJson == null) {
      throw StateError('reset called before mount');
    }
    _engine?.dispose();
    _engine = null;
    await _cleanupTempDir();
    await _boot(_specJson!);
  }

  Future<void> _boot(String specJson) async {
    _tempDir = await Directory.systemTemp.createTemp('ods_conformance_');
    final engine = AppEngine();
    engine.storageFolder = _tempDir!.path;
    // Only skip app-level auth when the spec is single-user — for
    // multi-user specs we want AuthService.initialize() to run so the
    // users table exists and register/login scenarios work end-to-end.
    final specMap = jsonDecode(specJson) as Map<String, Object?>;
    final authMap = specMap['auth'] as Map<String, Object?>?;
    final isMultiUser = (authMap?['multiUser'] as bool?) ?? false;
    engine.skipAppAuth = !isMultiUser;
    final ok = await engine.loadSpec(specJson);
    if (!ok) {
      throw StateError(
        'FlutterDriver.mount: loadSpec failed: ${engine.loadError ?? '(no error)'}',
      );
    }
    _engine = engine;
  }

  Future<void> _cleanupTempDir() async {
    final dir = _tempDir;
    _tempDir = null;
    if (dir != null && await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Some platforms (Windows AV, shared files) can keep handles open
        // briefly after close. We created under systemTemp so the OS will
        // reclaim eventually; swallow best-effort.
      }
    }
  }

  // -- Input -----------------------------------------------------------------

  @override
  Future<void> fillField(
    String fieldName,
    FieldValue value, {
    String? formId,
  }) async {
    final engine = _requireEngine();
    final page = _requireCurrentPage(engine);

    var targetFormId = formId;
    if (targetFormId == null) {
      final form = _findSoleForm(page.content);
      if (form == null) {
        throw StateError('fillField: no form on current page');
      }
      targetFormId = form.id;
    }

    engine.updateFormField(targetFormId, fieldName, value.toString());
  }

  @override
  Future<void> clickButton(String label, {int occurrence = 0}) async {
    final engine = _requireEngine();
    final page = _requireCurrentPage(engine);

    final matches = page.content
        .whereType<OdsButtonComponent>()
        .where((b) => b.label == label)
        .toList();
    if (occurrence >= matches.length) {
      throw StateError(
        'clickButton: no button with label="$label" (occurrence $occurrence); '
        'found ${matches.length} matches',
      );
    }
    final button = matches[occurrence];
    await engine.executeActions(button.onClick);
  }

  @override
  Future<void> clickRowAction(
    String dataSource,
    String rowId,
    String actionLabel,
  ) async {
    final engine = _requireEngine();
    final app = engine.app;
    if (app == null) throw StateError('clickRowAction: no app loaded');
    final ds = app.dataSources[dataSource];
    if (ds == null) {
      throw StateError('clickRowAction: unknown data source "$dataSource"');
    }

    // Locate the list component on the current page bound to this data
    // source; row actions live on the list spec.
    final page = _requireCurrentPage(engine) as dynamic;
    final list = (page.content as List<OdsComponent>)
        .whereType<OdsListComponent>()
        .firstWhere(
          (l) => l.dataSource == dataSource,
          orElse: () => throw StateError(
            'clickRowAction: no list bound to "$dataSource" on current page',
          ),
        );

    final rowAction = list.rowActions.firstWhere(
      (a) => a.label == actionLabel,
      orElse: () => throw StateError(
        'clickRowAction: no row action with label="$actionLabel" on list "$dataSource"',
      ),
    );

    // Resolve the match value. Contract's rowId is the canonical _id;
    // for non-_id matchField, fetch the row first.
    final matchField = rowAction.matchField.isEmpty ? '_id' : rowAction.matchField;
    var matchValue = rowId;
    if (matchField != '_id') {
      final rows = await engine.dataStore.query(ds.tableName);
      final row = rows.firstWhere(
        (r) => r['_id']?.toString() == rowId,
        orElse: () => throw StateError(
          'clickRowAction: no row with _id="$rowId" in "$dataSource"',
        ),
      );
      matchValue = (row[matchField] ?? '').toString();
    }

    switch (rowAction.action) {
      case 'delete':
        await engine.executeDeleteRowAction(
          dataSourceId: rowAction.dataSource.isEmpty ? dataSource : rowAction.dataSource,
          matchField: matchField,
          matchValue: matchValue,
        );
        return;
      case 'update':
        await engine.executeRowAction(
          dataSourceId: rowAction.dataSource.isEmpty ? dataSource : rowAction.dataSource,
          matchField: matchField,
          matchValue: matchValue,
          values: rowAction.values,
        );
        return;
      default:
        throw UnimplementedError(
          'clickRowAction: action "${rowAction.action}" not yet supported '
          '(only "delete"/"update" implemented in MVP)',
        );
    }
  }

  @override
  Future<void> clickMenuItem(String label) async {
    final engine = _requireEngine();
    final app = engine.app;
    if (app == null) throw StateError('clickMenuItem: no app loaded');
    final item = app.menu.firstWhere(
      (m) => m.label == label,
      orElse: () => throw StateError('clickMenuItem: no menu item "$label"'),
    );
    engine.navigateTo(item.mapsTo);
  }

  // -- Observation -----------------------------------------------------------

  @override
  Future<({String id, String title})> currentPage() async {
    final engine = _requireEngine();
    final app = engine.app;
    if (app == null) throw StateError('currentPage: no app loaded');
    final id = engine.currentPageId ?? app.startPage;
    final page = app.pages[id];
    return (id: id, title: page?.title ?? '');
  }

  @override
  Future<List<ComponentSnapshot>> pageContent() async {
    final engine = _requireEngine();
    final app = engine.app;
    if (app == null) return [];
    final pageId = engine.currentPageId;
    if (pageId == null) return [];
    final page = app.pages[pageId];
    if (page == null) return [];

    final out = <ComponentSnapshot>[];
    for (final c in page.content) {
      final snap = await _snapshot(c, app, engine);
      if (snap != null) out.add(snap);
    }
    return out;
  }

  @override
  Future<List<Row>> dataRows(String dataSource) async {
    final engine = _requireEngine();
    final app = engine.app;
    if (app == null) throw StateError('dataRows: no app loaded');
    final ds = app.dataSources[dataSource];
    if (ds == null) {
      throw StateError('dataRows: unknown data source "$dataSource"');
    }
    final rows = await engine.dataStore.query(ds.tableName);
    final copy = List<Row>.from(rows.map((r) => Row.from(r)));
    copy.sort((a, b) =>
        (a['_id']?.toString() ?? '').compareTo(b['_id']?.toString() ?? ''));
    return copy;
  }

  @override
  Future<Map<String, FieldValue>> formValues(String formId) async {
    final engine = _requireEngine();
    final state = engine.getFormState(formId);
    final result = <String, FieldValue>{...state};

    final form = _findFormOnCurrentPage(formId);
    if (form != null) {
      // Lazily resolve magic defaults (CURRENTDATE / NOW) for fields the
      // user hasn't set.
      for (final field in form.fields) {
        if (result.containsKey(field.name)) continue;
        final dv = field.defaultValue;
        if (dv == null || dv.isEmpty) continue;
        final resolved = _resolveMagicDefault(dv, field.type);
        if (resolved != null) result[field.name] = resolved;
      }

      // Evaluate formulas AFTER defaults are in place. Same evaluator
      // the form renderer uses — so the observable form values mirror
      // what a user would see.
      for (final field in form.fields) {
        final formula = field.formula;
        if (formula == null || formula.isEmpty) continue;
        final stringValues = <String, String?>{
          for (final entry in result.entries) entry.key: entry.value.toString(),
        };
        result[field.name] =
            FormulaEvaluator.evaluate(formula, field.type, stringValues);
      }
    }

    return result;
  }

  OdsFormComponent? _findFormOnCurrentPage(String formId) {
    final engine = _engine;
    if (engine == null) return null;
    final app = engine.app;
    if (app == null) return null;
    final pageId = engine.currentPageId ?? app.startPage;
    final page = app.pages[pageId];
    if (page == null) return null;
    for (final c in page.content) {
      if (c is OdsFormComponent && c.id == formId) return c;
    }
    return null;
  }

  /// Subset mirror of FormComponent's resolveMagicDefault: just CURRENTDATE
  /// / NOW on date + datetime fields. Other magic values (CURRENT_USER.*,
  /// +7d, etc.) are out of scope for MVP conformance.
  String? _resolveMagicDefault(String defaultValue, String fieldType) {
    final upper = defaultValue.toUpperCase();
    if (upper == 'NOW' || upper == 'CURRENTDATE') {
      final now = _fakeNow ?? DateTime.now();
      final utc = now.toUtc();
      if (fieldType == 'datetime') {
        // YYYY-MM-DDThh:mm
        return utc.toIso8601String().substring(0, 16);
      }
      // YYYY-MM-DD
      return utc.toIso8601String().substring(0, 10);
    }
    return null;
  }

  @override
  Future<Message?> lastMessage() async {
    final engine = _requireEngine();
    final text = engine.lastMessage;
    if (text == null) return null;

    // Recover the `level` from the last showMessage action in the just-
    // executed chain. The store records the string; the spec's declared
    // level lives on the action itself. We scan the current page's
    // buttons for a showMessage whose `message` matches `text` (newest
    // wins) and take its level. This mirrors ReactDriver's approach.
    final level = _inferMessageLevel(text, engine) ?? 'info';
    return Message(text: text, level: level);
  }

  String? _inferMessageLevel(String messageText, AppEngine engine) {
    final app = engine.app;
    if (app == null) return null;
    final pageId = engine.currentPageId;
    if (pageId == null) return null;
    final page = app.pages[pageId];
    if (page == null) return null;

    // Scan the current page's buttons; the newest matching showMessage
    // wins (mirrors ReactDriver).
    String? match;
    for (final c in page.content) {
      if (c is! OdsButtonComponent) continue;
      for (final action in c.onClick) {
        if (action.action == 'showMessage' && action.message == messageText) {
          match = action.level;
        }
      }
    }
    return match;
  }

  // -- Auth ------------------------------------------------------------------

  @override
  Future<bool> login(String email, String password) async {
    final engine = _requireEngine();
    final result = await engine.authService.login(email, password);
    return result.success;
  }

  @override
  Future<void> logout() async {
    final engine = _engine;
    engine?.authService.logout();
  }

  @override
  Future<String?> registerUser({
    required String email,
    required String password,
    String? displayName,
    String? role,
  }) async {
    final engine = _requireEngine();
    final app = engine.app;
    final defaultRole = role ?? app?.auth.defaultRole ?? 'user';
    return engine.authService.registerUser(
      email: email,
      password: password,
      role: defaultRole,
      displayName: displayName,
    );
  }

  @override
  Future<UserSnapshot?> currentUser() async {
    final engine = _engine;
    if (engine == null) return null;
    final auth = engine.authService;
    if (!auth.isLoggedIn) return null;
    return UserSnapshot(
      id: auth.currentUserId ?? '',
      email: auth.currentEmail,
      displayName: auth.currentDisplayName,
      roles: List<String>.from(auth.currentRoles),
    );
  }

  // -- Determinism -----------------------------------------------------------

  @override
  Future<void> setClock(String isoTimestamp) async {
    // We don't globally mock DateTime.now(); instead, `formValues` consults
    // `_fakeNow` when resolving magic defaults. That covers the current
    // conformance scope (CURRENTDATE / NOW on form fields) without touching
    // production code paths that read wall-clock time.
    _fakeNow = DateTime.parse(isoTimestamp);
  }

  @override
  Future<void> setSeed(int seed) async {
    // No RNG surface exposed in the MVP scenarios.
  }

  // -- Internals -------------------------------------------------------------

  AppEngine _requireEngine() {
    final engine = _engine;
    if (engine == null) {
      throw StateError('FlutterDriver: not mounted — call mount(spec) first');
    }
    return engine;
  }

  dynamic _requireCurrentPage(AppEngine engine) {
    final app = engine.app;
    if (app == null) throw StateError('no current page (app not loaded)');
    final pageId = engine.currentPageId ?? app.startPage;
    final page = app.pages[pageId];
    if (page == null) throw StateError('no current page for id "$pageId"');
    return page;
  }

  OdsFormComponent? _findSoleForm(List<OdsComponent> content) {
    final forms = content.whereType<OdsFormComponent>().toList();
    if (forms.isEmpty) return null;
    if (forms.length > 1) {
      throw StateError(
        'fillField without formId is ambiguous: current page has '
        '${forms.length} forms — pass formId explicitly',
      );
    }
    return forms.first;
  }

  /// Evaluate a component's visibleWhen against live state. Mirrors the
  /// TS driver's logic: field-based conditions consult form state;
  /// data-based conditions consult the data store row count.
  Future<bool> _evaluateVisible(OdsComponent c, AppEngine engine) async {
    final condition = c.visibleWhen;
    if (condition == null) return true;

    if (condition.isFieldBased) {
      final state = engine.getFormState(condition.form!);
      final value = state[condition.field!] ?? '';
      if (condition.equals != null) return value == condition.equals;
      if (condition.notEquals != null) return value != condition.notEquals;
      return true;
    }

    if (condition.isDataBased) {
      final ds = engine.app?.dataSources[condition.source!];
      if (ds == null) return true;
      final rows = await engine.dataStore.query(ds.tableName);
      final count = rows.length;
      if (condition.countEquals != null) return count == condition.countEquals;
      if (condition.countMin != null && count < condition.countMin!) return false;
      if (condition.countMax != null && count > condition.countMax!) return false;
      return true;
    }

    return true;
  }

  Future<ComponentSnapshot?> _snapshot(
    OdsComponent c,
    OdsApp app,
    AppEngine engine,
  ) async {
    final visible = await _evaluateVisible(c, engine);

    if (c is OdsTextComponent) {
      return TextSnapshot(visible: visible, content: c.content);
    }
    if (c is OdsFormComponent) {
      final values = engine.getFormState(c.id);
      return FormSnapshot(
        visible: visible,
        id: c.id,
        fields: c.fields
            .map((f) => FormFieldSnapshot(
                  name: f.name,
                  type: f.type,
                  label: f.label ?? f.name,
                  value: values[f.name],
                  required: f.required,
                  error: null,
                ))
            .toList(),
      );
    }
    if (c is OdsListComponent) {
      // Route through the engine so ownership (and future row-level
      // filters) apply — matches what the user actually sees.
      final rows = await engine.queryDataSource(c.dataSource);
      return ListSnapshot(
        visible: visible,
        dataSource: c.dataSource,
        columnFields: c.columns.map((col) => col.field).toList(),
        rowCount: rows.length,
        sortField: c.defaultSort?.field,
        sortDir: c.defaultSort?.direction,
      );
    }
    if (c is OdsButtonComponent) {
      return ButtonSnapshot(visible: visible, label: c.label, enabled: true);
    }
    if (c is OdsTabsComponent) {
      return TabsSnapshot(
        visible: visible,
        tabs: [
          for (var i = 0; i < c.tabs.length; i++)
            TabsTab(label: c.tabs[i].label, active: i == 0),
        ],
      );
    }
    if (c is OdsSummaryComponent) {
      var value = c.value;
      if (AggregateEvaluator.hasAggregates(value)) {
        value = await AggregateEvaluator.resolve(value, (dsId) async {
          final ds = engine.app?.dataSources[dsId];
          if (ds == null) return <Map<String, dynamic>>[];
          return engine.dataStore.query(ds.tableName);
        });
      }
      return SummarySnapshot(visible: visible, label: c.label, value: value);
    }
    // Other component kinds not yet rendered in the MVP driver.
    return null;
  }
}
