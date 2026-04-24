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

import 'package:ods_flutter_local/engine/app_engine.dart';
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
  };

  AppEngine? _engine;
  Directory? _tempDir;
  String? _specJson;

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
    // Skip app-level auth gating for conformance so scenarios that don't
    // declare auth don't hit the admin-setup / login walls.
    engine.skipAppAuth = true;
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
    throw UnimplementedError(
      'clickRowAction: not yet implemented in the Flutter MVP driver',
    );
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
    return Map<String, FieldValue>.from(state);
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
    throw UnimplementedError('login: not yet implemented (MVP driver)');
  }

  @override
  Future<void> logout() async {
    // No-op in the MVP — scenarios that need it declare auth capabilities,
    // which we don't advertise yet.
  }

  @override
  Future<String?> registerUser({
    required String email,
    required String password,
    String? displayName,
    String? role,
  }) async {
    throw UnimplementedError('registerUser: not yet implemented (MVP driver)');
  }

  @override
  Future<UserSnapshot?> currentUser() async {
    // MVP treats everything as guest until auth scenarios land.
    return null;
  }

  // -- Determinism -----------------------------------------------------------

  @override
  Future<void> setClock(String isoTimestamp) async {
    // Not implemented for MVP — Dart time-freezing is scenario-dependent.
    // Follow-up work.
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

  Future<ComponentSnapshot?> _snapshot(
    OdsComponent c,
    OdsApp app,
    AppEngine engine,
  ) async {
    // visibleWhen evaluation — MVP treats missing visibleWhen as visible.
    // Mirrors the MVP ReactDriver before s07/s08 added full evaluation.
    const visible = true;

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
      final ds = app.dataSources[c.dataSource];
      final rows = ds != null
          ? await engine.dataStore.query(ds.tableName)
          : const <Map<String, dynamic>>[];
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
    // Other component kinds not yet rendered in the MVP driver.
    return null;
  }
}
