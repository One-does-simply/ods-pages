/// Dart mirror of Frameworks/conformance/src/scenarios.ts — scenario
/// definitions for the Flutter-side conformance runner.
///
/// Keep in sync with the TS scenarios. A scenario that passes in TS but
/// fails in Dart (or vice versa) is a parity bug; that's the whole point
/// of the contract.
library;

import 'contract.dart';

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

OdsSpec miniTodoSpec() => {
      'appName': 'Mini Todo',
      'startPage': 'home',
      'pages': {
        'home': {
          'component': 'page',
          'title': 'Home',
          'content': [
            {
              'component': 'form',
              'id': 'addForm',
              'dataSource': 'tasks',
              'fields': [
                {'name': 'title', 'type': 'text', 'label': 'Title', 'required': true},
                {'name': 'done', 'type': 'checkbox', 'label': 'Done'},
              ],
            },
            {
              'component': 'button',
              'label': 'Save',
              'onClick': [
                {'action': 'submit', 'dataSource': 'tasks', 'target': 'addForm'},
                {'action': 'showMessage', 'message': 'Saved!', 'level': 'success'},
              ],
            },
            {
              'component': 'list',
              'dataSource': 'tasks',
              'columns': [
                {'field': 'title', 'header': 'Title'},
                {'field': 'done', 'header': 'Done'},
              ],
            },
          ],
        },
      },
      'dataSources': {
        'tasks': {
          'url': 'local://tasks',
          'method': 'POST',
          'fields': [
            {'name': 'title', 'type': 'text'},
            {'name': 'done', 'type': 'checkbox'},
          ],
        },
      },
    };

OdsSpec twoPageSpec() => {
      'appName': 'Two Page',
      'startPage': 'home',
      'menu': [
        {'label': 'Home', 'mapsTo': 'home'},
        {'label': 'Second', 'mapsTo': 'second'},
      ],
      'pages': {
        'home': {
          'component': 'page',
          'title': 'Home',
          'content': [
            {'component': 'text', 'content': 'Welcome home'},
            {
              'component': 'button',
              'label': 'Go Second',
              'onClick': [
                {'action': 'navigate', 'target': 'second'},
              ],
            },
          ],
        },
        'second': {
          'component': 'page',
          'title': 'Second',
          'content': [
            {'component': 'text', 'content': 'On the second page'},
          ],
        },
      },
      'dataSources': <String, Object?>{},
    };

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

/// Full list of scenarios the runner executes.
final List<Scenario> allScenarios = [
  s01SpecLoads,
  s02FormSubmitInsertsRow,
  s03ShowMessageAfterSubmit,
  s04ListReflectsSubmittedRows,
  s05NavigateActionSwitchesPage,
];
