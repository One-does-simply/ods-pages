/// Dart mirror of Frameworks/conformance/src/scenarios.ts — scenario
/// definitions for the Flutter-side conformance runner.
///
/// Keep in sync with the TS scenarios. A scenario that passes in TS but
/// fails in Dart (or vice versa) is a parity bug; that's the whole point
/// of the contract.
library;

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
];
