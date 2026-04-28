
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_field_definition.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/components/detail_component.dart';

import '_test_harness.dart';

const String _kSpec = '''
{
  "appName": "DetailTest",
  "startPage": "home",
  "pages": {"home": {"component": "page", "title": "Home", "content": []}},
  "dataSources": {
    "tasks": {
      "url": "local://tasks",
      "method": "POST",
      "fields": [
        {"name": "title", "type": "text", "label": "Title"},
        {"name": "dueDate", "type": "date", "label": "Due Date"}
      ]
    }
  }
}
''';

void main() {
  group('OdsDetailWidget', () {
    testWidgets('Renders fields from data source row', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('tasks', [
            const OdsFieldDefinition(name: 'title', type: 'text'),
            const OdsFieldDefinition(name: 'dueDate', type: 'date'),
          ]);
          await ds.insert('tasks', {'title': 'Buy Milk', 'dueDate': '2026-05-01'});
        });

        const model = OdsDetailComponent(
          dataSource: 'tasks',
          fields: ['title', 'dueDate'],
          styleHint: OdsStyleHint({}),
        );
        await tester.pumpWidget(
          harness(engine: booted.engine, child: const OdsDetailWidget(model: model)),
        );
        // Wait until the seeded row appears — fixed pump rounds flake
        // under full-gate load when many SQLite operations have already
        // happened in this process. pumpUntilFound polls until found.
        await pumpUntilFound(tester, find.text('Buy Milk'));
        expect(find.text('Buy Milk'), findsOneWidget);
        expect(find.text('2026-05-01'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Custom labels map applies', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('tasks', [
            const OdsFieldDefinition(name: 'title', type: 'text'),
          ]);
          await ds.insert('tasks', {'title': 'Task X'});
        });

        const model = OdsDetailComponent(
          dataSource: 'tasks',
          fields: ['title'],
          labels: {'title': 'Task Name'},
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsDetailWidget(model: model)),
        );
        expect(find.text('Task Name'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Empty data source shows no row content', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const model = OdsDetailComponent(
          dataSource: 'tasks',
          fields: ['title'],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsDetailWidget(model: model)),
        );
        // No data was inserted — widget should render without crashing, may show
        // an empty-state or blank. Test just verifies no exception.
        expect(tester.takeException(), isNull);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
