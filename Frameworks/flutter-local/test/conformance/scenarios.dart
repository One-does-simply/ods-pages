/// Dart mirror of Frameworks/conformance/src/scenarios.ts — scenario
/// definitions for the Flutter-side conformance runner.
///
/// Keep in sync with the TS scenarios. A scenario that passes in TS but
/// fails in Dart (or vice versa) is a parity bug; that's the whole point
/// of the contract.
library;

import 'dart:convert';

import 'contract.dart';
import 'load_spec.dart';

/// A parity scenario is a single (name, specFactory, capabilities, run)
/// tuple. The runner constructs the driver, calls `mount(spec())`, invokes
/// `run`, then `unmount()`. Assertions inside `run` throw on failure.
class Scenario {
  const Scenario({
    required this.name,
    required this.spec,
    required this.capabilities,
    required this.run,
  });

  /// Human-readable name (used as the Dart test case name).
  final String name;

  /// Factory — called fresh per run so scenarios can parameterize freely
  /// without leaking state across runs.
  final OdsSpec Function() spec;

  /// Capabilities the scenario exercises. The runner skips (doesn't fail)
  /// a scenario whose capabilities aren't all in the driver's set.
  final List<String> capabilities;

  /// The scenario body. Driver is fresh on entry (mount already called);
  /// runner calls unmount after return or throw.
  final Future<void> Function(OdsDriver driver) run;
}

// ---------------------------------------------------------------------------
// Tiny assertion helpers — scenarios are framework-agnostic, so we can't
// use flutter_test's expect(). These throw plain Errors which the runner
// catches and re-raises as test failures.
// ---------------------------------------------------------------------------

void assertEqual<T>(T actual, T expected, [String? msg]) {
  if (actual != expected) {
    throw StateError(
      '${msg ?? 'assertion failed'}: expected $expected, got $actual',
    );
  }
}

void assertTrue(Object? value, String msg) {
  if (value is! bool || !value) {
    throw StateError(msg);
  }
}

// ---------------------------------------------------------------------------
// Spec helpers
// ---------------------------------------------------------------------------

OdsSpec miniTodoSpec() => loadSpec('miniTodo');
OdsSpec miniTodoWithDeleteSpec() => loadSpec('miniTodoWithDelete');
OdsSpec twoPageSpec() => loadSpec('twoPage');
OdsSpec visibleWhenFieldSpec() => loadSpec('visibleWhenField');
OdsSpec visibleWhenDataSpec() => loadSpec('visibleWhenData');
OdsSpec currentDateDefaultSpec() => loadSpec('currentDateDefault');
OdsSpec multiUserAppSpec() => loadSpec('multiUserApp');
OdsSpec submitThenNavigateSpec() => loadSpec('submitThenNavigate');
OdsSpec rowActionUpdateSpec() => loadSpec('rowActionUpdate');
OdsSpec formulaComputeSpec() => loadSpec('formulaCompute');
OdsSpec summaryAggregateSpec() => loadSpec('summaryAggregate');
OdsSpec ownershipPerUserSpec() => loadSpec('ownershipPerUser');
OdsSpec tabsInitialStateSpec() => loadSpec('tabsInitialState');
OdsSpec chartConfigSpec() => loadSpec('chartConfig');
OdsSpec kanbanDragSpec() => loadSpec('kanbanDrag');
OdsSpec cascadeRenameSpec() => loadSpec('cascadeRename');
OdsSpec themeConfigSpec() => loadSpec('themeConfig');
OdsSpec detailFieldsRoundTripSpec() => loadSpec('detailFieldsRoundTrip');
OdsSpec recordNavigationSpec() => loadSpec('recordNavigation');
OdsSpec currentUserDefaultsSpec() => loadSpec('currentUserDefaults');
OdsSpec listDefaultSortSpec() => loadSpec('listDefaultSort');

// ---------------------------------------------------------------------------
// Scenarios (mirrors of the TS versions; keep ids + names aligned)
// ---------------------------------------------------------------------------

final s01SpecLoads = Scenario(
  name: 'spec loads and start page renders',
  spec: miniTodoSpec,
  capabilities: const ['core'],
  run: (d) async {
    final page = await d.currentPage();
    assertEqual(page.id, 'home', 'current page id');
    assertEqual(page.title, 'Home', 'current page title');
  },
);

final s02FormSubmitInsertsRow = Scenario(
  name: 'form submit inserts a row into the data source',
  spec: miniTodoSpec,
  capabilities: const ['core', 'action:submit'],
  run: (d) async {
    await d.fillField('title', 'Buy milk');
    await d.clickButton('Save');
    final rows = await d.dataRows('tasks');
    assertEqual(rows.length, 1, 'row count after submit');
    assertEqual(rows[0]['title'], 'Buy milk', 'row title');
  },
);

final s03ShowMessageAfterSubmit = Scenario(
  name: 'showMessage after submit surfaces a message',
  spec: miniTodoSpec,
  capabilities: const ['core', 'action:submit', 'action:showMessage'],
  run: (d) async {
    await d.fillField('title', 'Eat lunch');
    await d.clickButton('Save');
    final msg = await d.lastMessage();
    assertTrue(msg != null, 'expected a message after Save');
    assertEqual(msg!.text, 'Saved!', 'message text');
    assertEqual(msg.level, 'success', 'message level');
  },
);

final s04ListReflectsSubmittedRows = Scenario(
  name: 'list component row count tracks submitted rows',
  spec: miniTodoSpec,
  capabilities: const ['core', 'action:submit'],
  run: (d) async {
    await d.fillField('title', 'Row one');
    await d.clickButton('Save');
    await d.fillField('title', 'Row two');
    await d.clickButton('Save');

    final content = await d.pageContent();
    final list = content.whereType<ListSnapshot>().firstWhere(
          (c) => true,
          orElse: () =>
              throw StateError('no list component on the current page'),
        );
    assertEqual(list.rowCount, 2, 'list row count');
  },
);

final s05NavigateActionSwitchesPage = Scenario(
  name: 'navigate action moves to the target page',
  spec: twoPageSpec,
  capabilities: const ['core', 'action:navigate'],
  run: (d) async {
    final before = await d.currentPage();
    assertEqual(before.id, 'home', 'start page');

    await d.clickButton('Go Second');

    final after = await d.currentPage();
    assertEqual(after.id, 'second', 'page after navigate');
    assertEqual(after.title, 'Second', 'title after navigate');
  },
);

final s06RowActionDeleteRemovesRow = Scenario(
  name: 'rowAction delete removes the matching row from the data source',
  spec: miniTodoWithDeleteSpec,
  capabilities: const ['core', 'action:submit', 'action:delete', 'rowActions'],
  run: (d) async {
    await d.fillField('title', 'Keep me');
    await d.clickButton('Save');
    await d.fillField('title', 'Delete me');
    await d.clickButton('Save');

    final before = await d.dataRows('tasks');
    assertEqual(before.length, 2, 'two rows before delete');

    final target = before.firstWhere(
      (r) => r['title'] == 'Delete me',
      orElse: () => throw StateError('expected "Delete me" row to exist'),
    );
    await d.clickRowAction('tasks', target['_id'].toString(), 'Delete');

    final after = await d.dataRows('tasks');
    assertEqual(after.length, 1, 'one row after delete');
    assertEqual(after[0]['title'], 'Keep me', 'surviving row is the one we kept');
  },
);

final s07VisibleWhenFieldCondition = Scenario(
  name: 'visibleWhen field-based condition hides/shows components with form state',
  spec: visibleWhenFieldSpec,
  capabilities: const ['core'],
  run: (d) async {
    final before = await d.pageContent();
    final textBefore = before.whereType<TextSnapshot>().first;
    assertEqual(textBefore.visible, false,
        'advanced text hidden before mode is set');

    await d.fillField('mode', 'advanced');

    final after = await d.pageContent();
    final textAfter = after.whereType<TextSnapshot>().first;
    assertEqual(textAfter.visible, true,
        'advanced text visible after mode=advanced');

    await d.fillField('mode', 'basic');
    final later = await d.pageContent();
    final textLater = later.whereType<TextSnapshot>().first;
    assertEqual(textLater.visible, false,
        'advanced text hidden again after mode=basic');
  },
);

final s08VisibleWhenDataCount = Scenario(
  name: 'visibleWhen data-source count condition tracks row additions',
  spec: visibleWhenDataSpec,
  capabilities: const ['core', 'action:submit'],
  run: (d) async {
    final before = await d.pageContent();
    final emptyText = before.whereType<TextSnapshot>().first;
    final list = before.whereType<ListSnapshot>().first;
    assertEqual(emptyText.visible, true, 'empty-state text visible at 0 rows');
    assertEqual(list.visible, false, 'list hidden at 0 rows');

    await d.fillField('title', 'First item');
    await d.clickButton('Save');

    final after = await d.pageContent();
    final emptyTextAfter = after.whereType<TextSnapshot>().first;
    final listAfter = after.whereType<ListSnapshot>().first;
    assertEqual(emptyTextAfter.visible, false,
        'empty-state text hidden after 1 row');
    assertEqual(listAfter.visible, true, 'list visible after 1 row');
  },
);

final s09CurrentDateDefaultHonorsClock = Scenario(
  name: 'CURRENTDATE default value resolves using the driver clock',
  spec: currentDateDefaultSpec,
  capabilities: const ['core'],
  run: (d) async {
    // Harness already set the clock to 2026-01-01T00:00:00Z before run.
    final initial = await d.formValues('editForm');
    assertEqual(initial['createdAt'], '2026-01-01',
        'CURRENTDATE resolved using the clock set by the harness');

    await d.setClock('2026-06-15T12:00:00Z');
    final later = await d.formValues('editForm');
    assertEqual(later['createdAt'], '2026-06-15',
        'CURRENTDATE reflects the updated clock on the next formValues call');

    await d.fillField('createdAt', '2020-12-25');
    final overridden = await d.formValues('editForm');
    assertEqual(overridden['createdAt'], '2020-12-25',
        'explicit fillField overrides the magic default');
  },
);

final s10RegisterThenLoginFlow = Scenario(
  name: 'registerUser creates an account; subsequent login authenticates that user',
  spec: multiUserAppSpec,
  capabilities: const ['core', 'auth:multiUser', 'auth:selfRegistration'],
  run: (d) async {
    final beforeAny = await d.currentUser();
    assertEqual(beforeAny, null, 'no user before registration');

    final newId = await d.registerUser(
      email: 'alice@example.com',
      password: 'secret-password',
      displayName: 'Alice',
    );
    assertTrue(newId != null, 'registerUser should return a non-null id');

    final afterRegister = await d.currentUser();
    assertEqual(afterRegister, null, 'registerUser does not auto-login');

    final ok = await d.login('alice@example.com', 'secret-password');
    assertEqual(ok, true, 'login with correct credentials succeeds');

    final loggedIn = await d.currentUser();
    assertTrue(loggedIn != null, 'currentUser non-null after login');
    assertEqual(loggedIn!.email, 'alice@example.com', 'currentUser email');
    assertEqual(loggedIn.displayName, 'Alice', 'currentUser displayName');
    assertTrue(loggedIn.roles.contains('user'),
        'currentUser roles include default "user" (got ${loggedIn.roles})');

    await d.logout();
    final afterLogout = await d.currentUser();
    assertEqual(afterLogout, null, 'currentUser null after logout');
  },
);

final s11LoginWithWrongPasswordFails = Scenario(
  name: 'login with wrong password returns false and leaves session unchanged',
  spec: multiUserAppSpec,
  capabilities: const ['core', 'auth:multiUser', 'auth:selfRegistration'],
  run: (d) async {
    await d.registerUser(
      email: 'bob@example.com',
      password: 'correct-password',
    );

    final bad = await d.login('bob@example.com', 'wrong-password');
    assertEqual(bad, false, 'login with wrong password should return false');

    final user = await d.currentUser();
    assertEqual(user, null, 'no session after failed login');

    final good = await d.login('bob@example.com', 'correct-password');
    assertEqual(good, true, 'subsequent login with correct password succeeds');
  },
);

final s12SubmitOnEndNavigate = Scenario(
  name: 'submit action with onEnd navigate lands on the target page after insert',
  spec: submitThenNavigateSpec,
  capabilities: const ['core', 'action:submit', 'action:navigate'],
  run: (d) async {
    final before = await d.currentPage();
    assertEqual(before.id, 'home', 'start on home page');

    await d.fillField('title', 'Go-to task');
    await d.clickButton('Save');

    final after = await d.currentPage();
    assertEqual(after.id, 'list', 'onEnd navigate lands us on the list page');
    assertEqual(after.title, 'All Tasks', 'page title reflects destination');

    final rows = await d.dataRows('tasks');
    assertEqual(rows.length, 1, 'submit inserted a row before firing onEnd');
    assertEqual(rows[0]['title'], 'Go-to task', 'inserted row matches fillField');
  },
);

final s13RowActionUpdateChangesField = Scenario(
  name: 'rowAction update writes new field values to the matched row',
  spec: rowActionUpdateSpec,
  capabilities: const ['core', 'action:submit', 'action:update', 'rowActions'],
  run: (d) async {
    await d.fillField('title', 'Test task');
    await d.fillField('status', 'todo');
    await d.clickButton('Save');

    final before = await d.dataRows('tasks');
    assertEqual(before.length, 1, 'one row after submit');
    assertEqual(before[0]['status'], 'todo', 'row starts with status=todo');

    await d.clickRowAction('tasks', before[0]['_id'].toString(), 'Mark Done');

    final after = await d.dataRows('tasks');
    assertEqual(after.length, 1, 'update preserves row count');
    assertEqual(after[0]['status'], 'done', 'update set status=done');
    assertEqual(after[0]['title'], 'Test task', 'update leaves other fields alone');
  },
);

final s14FormulaFieldsComputeFromDependencies = Scenario(
  name: 'formula fields compute from their dependencies and update on change',
  spec: formulaComputeSpec,
  capabilities: const ['core', 'formulas'],
  run: (d) async {
    final empty = await d.formValues('orderForm');
    assertEqual(empty['total'], '', 'total empty before dependencies filled');
    assertEqual(empty['fullName'], '',
        'fullName empty when any dependency is blank');

    await d.fillField('quantity', '5');
    await d.fillField('unitPrice', '10');
    final math = await d.formValues('orderForm');
    assertEqual(math['total'], '50', 'total = quantity * unitPrice');

    await d.fillField('quantity', '6');
    final updated = await d.formValues('orderForm');
    assertEqual(updated['total'], '60',
        'total updates when a dependency changes');

    await d.fillField('firstName', 'Ada');
    await d.fillField('lastName', 'Lovelace');
    final text = await d.formValues('orderForm');
    assertEqual(text['fullName'], 'Ada Lovelace',
        'text formula interpolates field values');
  },
);

final s15SummaryAggregateCountsRows = Scenario(
  name: 'summary component value resolves aggregate expressions against data',
  spec: summaryAggregateSpec,
  capabilities: const ['core', 'action:submit', 'summary'],
  run: (d) async {
    final before = await d.pageContent();
    final sBefore = before.whereType<SummarySnapshot>().firstOrNull;
    assertTrue(sBefore != null, 'summary component present in snapshot');
    assertEqual(sBefore!.value, '0', 'COUNT(tasks) is 0 with no rows');

    for (final title in const ['a', 'b', 'c']) {
      await d.fillField('title', title);
      await d.clickButton('Save');
    }

    final after = await d.pageContent();
    final sAfter = after.whereType<SummarySnapshot>().first;
    assertEqual(sAfter.value, '3', 'COUNT(tasks) reflects three submissions');
    assertEqual(sAfter.label, 'Total Tasks',
        'summary label is passed through from the spec');
  },
);

final s16OwnershipScopesListToCurrentUser = Scenario(
  name: 'ownership-enabled data source hides rows owned by other users',
  spec: ownershipPerUserSpec,
  capabilities: const [
    'core',
    'action:submit',
    'auth:multiUser',
    'auth:selfRegistration',
    'auth:ownership',
  ],
  run: (d) async {
    // Alice creates two tasks.
    await d.registerUser(email: 'alice@example.com', password: 'pw-alice-1');
    await d.login('alice@example.com', 'pw-alice-1');
    await d.fillField('title', 'Alice task 1');
    await d.clickButton('Save');
    await d.fillField('title', 'Alice task 2');
    await d.clickButton('Save');

    final aliceView = await d.pageContent();
    final aliceList = aliceView.whereType<ListSnapshot>().first;
    assertEqual(aliceList.rowCount, 2, 'Alice sees her two rows');

    // Bob creates one task.
    await d.logout();
    await d.registerUser(email: 'bob@example.com', password: 'pw-bob-1');
    await d.login('bob@example.com', 'pw-bob-1');
    await d.fillField('title', 'Bob task 1');
    await d.clickButton('Save');

    final bobView = await d.pageContent();
    final bobList = bobView.whereType<ListSnapshot>().first;
    assertEqual(
        bobList.rowCount, 1, 'Bob sees only his own row, not Alice\'s');

    // Swap back to Alice.
    await d.logout();
    await d.login('alice@example.com', 'pw-alice-1');
    final aliceAgain = await d.pageContent();
    final aliceList2 = aliceAgain.whereType<ListSnapshot>().first;
    assertEqual(aliceList2.rowCount, 2,
        'Alice still sees her two rows after Bob logged in and out');

    // God view is unfiltered.
    final allRows = await d.dataRows('tasks');
    assertEqual(allRows.length, 3, 'dataRows is unfiltered — sees all 3 rows');
  },
);

final s17TabsSnapshotExposesLabelsAndFirstActive = Scenario(
  name: 'tabs component snapshot reports labels in order with the first tab active',
  spec: tabsInitialStateSpec,
  capabilities: const ['core', 'tabs'],
  run: (d) async {
    final content = await d.pageContent();
    final tabs = content.whereType<TabsSnapshot>().firstOrNull;
    assertTrue(tabs != null, 'tabs component present on the page');

    final tabList = tabs!.tabs;
    assertEqual(tabList.length, 3, 'three tabs declared in the spec');
    assertEqual(tabList[0].label, 'Overview', 'tab 0 label');
    assertEqual(tabList[1].label, 'Details', 'tab 1 label');
    assertEqual(tabList[2].label, 'Settings', 'tab 2 label');

    final activeCount = tabList.where((t) => t.active).length;
    assertEqual(activeCount, 1, 'exactly one tab is active');
    assertEqual(tabList[0].active, true, 'first tab is the active one by default');
  },
);

final s18ChartSnapshotPreservesConfig = Scenario(
  name: 'chart component snapshot preserves chartType, title, and dataSource',
  spec: chartConfigSpec,
  capabilities: const ['core', 'chart'],
  run: (d) async {
    final content = await d.pageContent();
    final chart = content.whereType<ChartSnapshot>().firstOrNull;
    assertTrue(chart != null, 'chart component present on the page');
    assertEqual(chart!.chartType, 'bar', 'chart type propagates from spec');
    assertEqual(chart.title, 'Tasks by Status',
        'chart title propagates from spec');
    assertEqual(chart.dataSource, 'tasks',
        'chart dataSource propagates from spec');
  },
);

final s19KanbanDragUpdatesStatus = Scenario(
  name: 'dragging a kanban card updates the row status field',
  spec: kanbanDragSpec,
  capabilities: const [
    'core',
    'action:submit',
    'action:update',
    'kanban',
  ],
  run: (d) async {
    for (final entry in const [
      ['Task todo', 'todo'],
      ['Task doing', 'doing'],
      ['Task done', 'done'],
    ]) {
      await d.fillField('title', entry[0]);
      await d.fillField('status', entry[1]);
      await d.clickButton('Save');
    }

    final rowsBefore = await d.dataRows('tasks');
    assertEqual(rowsBefore.length, 3, 'three rows inserted');

    final before = await d.pageContent();
    final kBefore = before.whereType<KanbanSnapshot>().firstOrNull;
    assertTrue(kBefore != null, 'kanban component present');
    final todoBefore = kBefore!.columns
        .where((col) => col.status == 'todo')
        .firstOrNull
        ?.cardCount ?? 0;
    final doingBefore = kBefore.columns
        .where((col) => col.status == 'doing')
        .firstOrNull
        ?.cardCount ?? 0;
    assertEqual(todoBefore, 1, 'todo column has 1 card before drag');
    assertEqual(doingBefore, 1, 'doing column has 1 card before drag');

    final todoRow = rowsBefore.firstWhere(
      (r) => r['title'] == 'Task todo',
      orElse: () => throw StateError('todo row missing'),
    );
    await d.dragCard('tasks', todoRow['_id'].toString(), 'doing');

    final rowsAfter = await d.dataRows('tasks');
    final draggedAfter = rowsAfter.firstWhere(
      (r) => r['_id'] == todoRow['_id'],
      orElse: () => throw StateError('dragged row missing after'),
    );
    assertEqual(draggedAfter['status'], 'doing',
        'dragged row now has status=doing');

    final after = await d.pageContent();
    final kAfter = after.whereType<KanbanSnapshot>().first;
    final todoAfter = kAfter.columns
        .where((col) => col.status == 'todo')
        .firstOrNull
        ?.cardCount ?? 0;
    final doingAfter = kAfter.columns
        .where((col) => col.status == 'doing')
        .firstOrNull
        ?.cardCount ?? 0;
    assertEqual(todoAfter, 0, 'todo column empty after drag');
    assertEqual(doingAfter, 2, 'doing column has 2 cards after drag');
  },
);

final s20CascadeRenamePropagatesToChildren = Scenario(
  name: 'cascade update renames matching children after renaming the parent',
  spec: cascadeRenameSpec,
  capabilities: const ['core', 'action:update', 'cascadeRename'],
  run: (d) async {
    final cats0 = await d.dataRows('categories');
    final tasks0 = await d.dataRows('tasks');
    assertEqual(cats0.length, 2, 'two categories seeded');
    assertEqual(tasks0.length, 3, 'three tasks seeded');
    final workCount0 = tasks0.where((t) => t['category'] == 'Work').length;
    assertEqual(workCount0, 2, 'two tasks start with category=Work');

    await d.clickButton('Rename Work to Projects');

    final cats1 = await d.dataRows('categories');
    final names = cats1.map((c) => c['name'].toString()).toList()..sort();
    assertEqual(names.toString(), ['Home', 'Projects'].toString(),
        'parent rename: Work -> Projects, Home untouched');

    final tasks1 = await d.dataRows('tasks');
    final projectsCount =
        tasks1.where((t) => t['category'] == 'Projects').length;
    final homeCount = tasks1.where((t) => t['category'] == 'Home').length;
    final workCount1 = tasks1.where((t) => t['category'] == 'Work').length;
    assertEqual(projectsCount, 2, 'both Work tasks cascaded to Projects');
    assertEqual(homeCount, 1, 'Home task untouched by cascade');
    assertEqual(workCount1, 0, 'no tasks still pointing at old Work name');
  },
);

final s21ThemeConfigRoundTrips = Scenario(
  name: 'theme config round-trips through the framework parser (ADR-0002)',
  spec: themeConfigSpec,
  capabilities: const ['core', 'theme'],
  run: (d) async {
    final t = await d.themeConfig();
    assertEqual(t.base, 'nord', 'theme.base from spec');
    assertEqual(t.mode, 'dark', 'theme.mode from spec');
    assertEqual(t.headerStyle, 'solid', 'theme.headerStyle from spec');
    assertEqual(
      t.overrides['primary'],
      'oklch(50% 0.2 260)',
      'theme.overrides.primary from spec',
    );
    assertEqual(
      t.overrides['fontSans'],
      'Inter',
      'theme.overrides.fontSans from spec',
    );
    assertEqual(
      t.logo,
      'https://example.com/logo.png',
      'top-level logo lifted out of branding',
    );
    assertEqual(
      t.favicon,
      'https://example.com/favicon.ico',
      'top-level favicon lifted out of branding',
    );
  },
);

final s22DetailFieldsRoundTrip = Scenario(
  name: 'detail component snapshot exposes name/label/value for each field',
  spec: detailFieldsRoundTripSpec,
  capabilities: const ['core', 'detail', 'action:submit'],
  run: (d) async {
    await d.fillField('name', 'Widget');
    await d.fillField('qty', 7);
    await d.clickButton('Save');

    final content = await d.pageContent();
    final detail = content.whereType<DetailSnapshot>().firstOrNull;
    assertTrue(detail != null, 'detail component present on the page');

    final fields = detail!.fields;
    assertEqual(fields.length, 2, 'detail emits one entry per declared field');

    final byName = {for (final f in fields) f.name: f};
    assertEqual(byName['name']?.label, 'Name', 'name field label round-trips');
    assertEqual(
      byName['name']?.value,
      'Widget',
      'name field value matches the submitted row',
    );
    assertEqual(byName['qty']?.label, 'Quantity', 'qty field label round-trips');
    // String form so the assertion holds on both drivers (see TS scenario).
    assertEqual(
      byName['qty']?.value?.toString(),
      '7',
      'qty field value matches the submitted row',
    );
  },
);

final s23RecordNavigationStepsThroughSeedData = Scenario(
  name: 'firstRecord/nextRecord/previousRecord/lastRecord step through a recordSource',
  spec: recordNavigationSpec,
  capabilities: const ['core', 'action:recordNav', 'action:showMessage'],
  run: (d) async {
    // See TS scenario comment: assertions are order-agnostic because
    // backend defaults differ (PocketBase=created-desc, SQLite=insertion).
    // What we pin is the structural contract.
    final before = await d.formValues('questionForm');
    assertEqual(
      (before['ord'] ?? '').toString(),
      '',
      'form is empty before firstRecord',
    );

    await d.clickButton('First');
    final r0 = (await d.formValues('questionForm'))['ord']!.toString();
    await d.clickButton('Next');
    final r1 = (await d.formValues('questionForm'))['ord']!.toString();
    await d.clickButton('Next');
    final r2 = (await d.formValues('questionForm'))['ord']!.toString();

    final seen = {r0, r1, r2};
    assertEqual(seen.length, 3, 'First→Next→Next visits three distinct rows');
    assertTrue(
      seen.contains('1') && seen.contains('2') && seen.contains('3'),
      'cursor visits all three seeded ords (1,2,3) regardless of order',
    );

    await d.clickButton('Next');
    final msg = await d.lastMessage();
    assertTrue(
      msg != null,
      'onEnd showMessage fires when nextRecord runs off the end',
    );
    assertEqual(msg!.text, 'End of records', 'onEnd message text from spec');
    assertEqual(msg.level, 'info', 'onEnd message level from spec');
    assertEqual(
      (await d.formValues('questionForm'))['ord']!.toString(),
      r2,
      'cursor stays on the last row after end-of-records',
    );

    await d.clickButton('Last');
    assertEqual(
      (await d.formValues('questionForm'))['ord']!.toString(),
      r2,
      'lastRecord matches the row reached by walking Next to the end',
    );

    await d.clickButton('Previous');
    assertEqual(
      (await d.formValues('questionForm'))['ord']!.toString(),
      r1,
      'previousRecord moves backward one position',
    );

    await d.clickButton('First');
    assertEqual(
      (await d.formValues('questionForm'))['ord']!.toString(),
      r0,
      'firstRecord returns to the start of the cursor',
    );
  },
);

final s24ClickMenuItemNavigatesBetweenPages = Scenario(
  name: 'clickMenuItem dispatches navigation by menu label, both directions',
  spec: twoPageSpec,
  capabilities: const ['core', 'action:navigate'],
  run: (d) async {
    final start = await d.currentPage();
    assertEqual(start.id, 'home', 'starts on home page');

    await d.clickMenuItem('Second');
    final after = await d.currentPage();
    assertEqual(after.id, 'second', 'menu item "Second" navigates to second page');
    assertEqual(after.title, 'Second', 'page title reflects the new page');

    await d.clickMenuItem('Home');
    final back = await d.currentPage();
    assertEqual(back.id, 'home', 'menu item "Home" navigates back');
    assertEqual(back.title, 'Home', 'page title reflects the home page');
  },
);

final s25CurrentUserMagicDefaultsResolveAfterLogin = Scenario(
  name: 'CURRENT_USER.EMAIL / .NAME default values resolve to the logged-in user',
  spec: currentUserDefaultsSpec,
  capabilities: const ['core', 'auth:multiUser', 'auth:selfRegistration'],
  run: (d) async {
    final beforeLogin = await d.formValues('noteForm');
    assertEqual(
      beforeLogin['author'] ?? '',
      '',
      'CURRENT_USER.EMAIL resolves to empty string when no user is logged in',
    );
    assertEqual(
      beforeLogin['name'] ?? '',
      '',
      'CURRENT_USER.NAME resolves to empty string when no user is logged in',
    );

    await d.registerUser(
      email: 'alice@example.com',
      password: 'secret-password',
      displayName: 'Alice',
    );
    final loggedIn = await d.login('alice@example.com', 'secret-password');
    assertEqual(loggedIn, true, 'login should succeed for the freshly-registered user');

    final afterLogin = await d.formValues('noteForm');
    assertEqual(
      afterLogin['author'],
      'alice@example.com',
      'CURRENT_USER.EMAIL resolves to the logged-in user email',
    );
    assertEqual(
      afterLogin['name'],
      'Alice',
      'CURRENT_USER.NAME resolves to the logged-in user displayName',
    );
    assertEqual(
      afterLogin['body'] ?? '',
      '',
      'fields without a default are not affected by CURRENT_USER resolution',
    );
  },
);

final s26ListDefaultSortOrdersDisplayedRows = Scenario(
  name: 'list defaultSort propagates to displayed row order (asc + desc + numeric)',
  spec: listDefaultSortSpec,
  capabilities: const ['core'],
  run: (d) async {
    final content = await d.pageContent();
    final lists = content.whereType<ListSnapshot>().toList();
    assertEqual(lists.length, 2, 'two lists are present on the page');

    final rows = await d.dataRows('people');
    assertEqual(rows.length, 3, 'three seed rows present');
    final byId = {for (final r in rows) r['_id'].toString(): r};

    final ascList = lists[0];
    assertEqual(ascList.sortField, 'name', 'asc list sortField from spec defaultSort');
    assertEqual(ascList.sortDir, 'asc', 'asc list sortDir from spec defaultSort');
    assertEqual(
      ascList.displayedRowIds.length,
      3,
      'asc list shows all three rows',
    );
    final ascNames =
        ascList.displayedRowIds.map((id) => byId[id]?['name']).toList();
    assertEqual(
      ascNames.toString(),
      ['Alice', 'Bob', 'Charlie'].toString(),
      'asc list rows are alphabetical by name',
    );

    final descList = lists[1];
    assertEqual(descList.sortField, 'age', 'desc list sortField from spec defaultSort');
    assertEqual(descList.sortDir, 'desc', 'desc list sortDir from spec defaultSort');
    final descAges = descList.displayedRowIds
        .map((id) => int.tryParse(byId[id]?['age'].toString() ?? ''))
        .toList();
    assertEqual(
      descAges.toString(),
      [44, 33, 22].toString(),
      'desc list rows are numeric-descending by age',
    );
  },
);

final s27AiProviderRequestShape = Scenario(
  name: 'AI provider wire shape is identical across frameworks (ADR-0003 phase 5)',
  // miniTodo is a no-op host spec — simulateAiRequest doesn't touch the
  // app, but the runner still mounts something so unmount/reset stay sane.
  spec: miniTodoSpec,
  capabilities: const ['core', 'ai:provider'],
  run: (d) async {
    const system = 'You are an ODS Build Helper.';
    const history = <({String role, String content})>[
      (role: 'user', content: 'Add a priority field'),
      (role: 'assistant', content: 'Sure, here is the update.'),
    ];
    const user = 'Now make the default "medium"';

    // -- Anthropic ---------------------------------------------------------
    final anth = await d.simulateAiRequest(
      provider: 'anthropic',
      model: 'claude-sonnet-4-6',
      apiKey: 'sk-ant-conformance',
      systemPrompt: system,
      history: history,
      userMessage: user,
    );
    assertEqual(
      anth.url,
      'https://api.anthropic.com/v1/messages',
      'anthropic endpoint URL',
    );
    assertEqual(anth.method, 'POST', 'anthropic HTTP method');
    assertEqual(
      anth.authHeader,
      'x-api-key: sk-ant-conformance',
      'anthropic auth header (x-api-key form, normalized lowercase)',
    );
    assertEqual(anth.body['model'], 'claude-sonnet-4-6', 'anthropic body.model');
    assertEqual(anth.body['system'], system, 'anthropic body.system');
    final maxTokens = anth.body['max_tokens'];
    assertTrue(
      maxTokens is int && maxTokens > 0,
      'anthropic body.max_tokens is a positive number',
    );
    // Anthropic format: history then current user, no system in messages array.
    assertEqual(
      jsonEncode(anth.body['messages']),
      jsonEncode([
        for (final m in history) {'role': m.role, 'content': m.content},
        {'role': 'user', 'content': user},
      ]),
      'anthropic body.messages = history + final user turn',
    );

    // -- OpenAI ------------------------------------------------------------
    final oai = await d.simulateAiRequest(
      provider: 'openai',
      model: 'gpt-4o',
      apiKey: 'sk-openai-conformance',
      systemPrompt: system,
      history: history,
      userMessage: user,
    );
    assertEqual(
      oai.url,
      'https://api.openai.com/v1/chat/completions',
      'openai endpoint URL',
    );
    assertEqual(oai.method, 'POST', 'openai HTTP method');
    assertEqual(
      oai.authHeader,
      'authorization: Bearer sk-openai-conformance',
      'openai auth header (Bearer form, normalized lowercase)',
    );
    assertEqual(oai.body['model'], 'gpt-4o', 'openai body.model');
    // OpenAI format: system as first message in the messages array.
    assertEqual(
      jsonEncode(oai.body['messages']),
      jsonEncode([
        {'role': 'system', 'content': system},
        for (final m in history) {'role': m.role, 'content': m.content},
        {'role': 'user', 'content': user},
      ]),
      'openai body.messages = [system, ...history, final user turn]',
    );
  },
);

/// Full list of scenarios the runner executes.
final List<Scenario> allScenarios = [
  s01SpecLoads,
  s02FormSubmitInsertsRow,
  s03ShowMessageAfterSubmit,
  s04ListReflectsSubmittedRows,
  s05NavigateActionSwitchesPage,
  s06RowActionDeleteRemovesRow,
  s07VisibleWhenFieldCondition,
  s08VisibleWhenDataCount,
  s09CurrentDateDefaultHonorsClock,
  s10RegisterThenLoginFlow,
  s11LoginWithWrongPasswordFails,
  s12SubmitOnEndNavigate,
  s13RowActionUpdateChangesField,
  s14FormulaFieldsComputeFromDependencies,
  s15SummaryAggregateCountsRows,
  s16OwnershipScopesListToCurrentUser,
  s17TabsSnapshotExposesLabelsAndFirstActive,
  s18ChartSnapshotPreservesConfig,
  s19KanbanDragUpdatesStatus,
  s20CascadeRenamePropagatesToChildren,
  s21ThemeConfigRoundTrips,
  s22DetailFieldsRoundTrip,
  s23RecordNavigationStepsThroughSeedData,
  s24ClickMenuItemNavigatesBetweenPages,
  s25CurrentUserMagicDefaultsResolveAfterLogin,
  s26ListDefaultSortOrdersDisplayedRows,
  s27AiProviderRequestShape,
];
