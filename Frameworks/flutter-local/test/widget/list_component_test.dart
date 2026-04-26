
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_field_definition.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/components/list_component.dart';

import '_test_harness.dart';

const String _kSpec = '''
{
  "appName": "ListTest",
  "startPage": "home",
  "pages": {"home": {"component": "page", "title": "Home", "content": []}},
  "dataSources": {
    "tasks": {
      "url": "local://tasks",
      "method": "POST",
      "fields": [
        {"name": "title", "type": "text", "label": "Title"},
        {"name": "status", "type": "text", "label": "Status"}
      ]
    }
  }
}
''';

void main() {
  group('OdsListWidget', () {
    testWidgets('Renders column headers', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        // Headers only render once there's at least one row — empty data
        // sources show a "No data yet." placeholder instead. Seed a row.
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('tasks', [
            const OdsFieldDefinition(name: 'title', type: 'text'),
            const OdsFieldDefinition(name: 'status', type: 'text'),
          ]);
          await ds.insert('tasks', {'title': 'Seed', 'status': 'open'});
        });

        const model = OdsListComponent(
          dataSource: 'tasks',
          columns: [
            OdsListColumn(header: 'Task Name', field: 'title'),
            OdsListColumn(header: 'Status', field: 'status'),
          ],
          rowActions: [],
          summary: [],
          searchable: false,
          displayAs: 'table',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsListWidget(model: model)),
        );
        expect(find.text('Task Name'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Renders rows from data source', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('tasks', [
            const OdsFieldDefinition(name: 'title', type: 'text'),
            const OdsFieldDefinition(name: 'status', type: 'text'),
          ]);
          await ds.insert('tasks', {'title': 'Task A', 'status': 'open'});
          await ds.insert('tasks', {'title': 'Task B', 'status': 'done'});
        });

        const model = OdsListComponent(
          dataSource: 'tasks',
          columns: [
            OdsListColumn(header: 'Title', field: 'title'),
            OdsListColumn(header: 'Status', field: 'status'),
          ],
          rowActions: [],
          summary: [],
          searchable: false,
          displayAs: 'table',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsListWidget(model: model)),
        );
        expect(find.text('Task A'), findsOneWidget);
        expect(find.text('Task B'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Empty state when no rows', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const model = OdsListComponent(
          dataSource: 'tasks',
          columns: [OdsListColumn(header: 'Title', field: 'title')],
          rowActions: [],
          summary: [],
          searchable: false,
          displayAs: 'table',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsListWidget(model: model)),
        );
        // Empty data sources render a "No data yet." placeholder rather
        // than an empty header row.
        expect(find.text('No data yet.'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Search input renders when searchable is true', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        // Search input only renders alongside the table — and the table
        // only renders when there's data. Seed a row.
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('tasks', [
            const OdsFieldDefinition(name: 'title', type: 'text'),
          ]);
          await ds.insert('tasks', {'title': 'Seed'});
        });

        const model = OdsListComponent(
          dataSource: 'tasks',
          columns: [OdsListColumn(header: 'Title', field: 'title')],
          rowActions: [],
          summary: [],
          searchable: true,
          displayAs: 'table',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsListWidget(model: model)),
        );
        // Search bar should render a TextField for input.
        expect(find.byType(TextField), findsAtLeastNWidgets(1));
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
