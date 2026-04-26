
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_field_definition.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/components/summary_component.dart';

import '_test_harness.dart';

const String _kTasksSpec = '''
{
  "appName": "SummaryTest",
  "startPage": "home",
  "pages": {"home": {"component": "page", "title": "Home", "content": []}},
  "dataSources": {
    "tasks": {
      "url": "local://tasks",
      "method": "POST",
      "fields": [{"name": "title", "type": "text", "label": "Title"}]
    }
  }
}
''';

void main() {
  group('OdsSummaryWidget', () {
    testWidgets('Renders label and plain value', (tester) async {
      final booted = await bootEngineFor(tester, _kTasksSpec);
      try {
        const model = OdsSummaryComponent(
          label: 'Total',
          value: '42',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsSummaryWidget(model: model)),
        );
        expect(find.text('Total'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Value with aggregate resolves count', (tester) async {
      final booted = await bootEngineFor(tester, _kTasksSpec);
      try {
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('tasks', [const OdsFieldDefinition(name: 'title', type: 'text')]);
          await ds.insert('tasks', {'title': 'a'});
          await ds.insert('tasks', {'title': 'b'});
        });

        const model = OdsSummaryComponent(
          label: 'Tasks',
          value: '{COUNT(tasks)}',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsSummaryWidget(model: model)),
        );
        expect(find.text('2'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Empty data source renders 0 count gracefully', (tester) async {
      final booted = await bootEngineFor(tester, _kTasksSpec);
      try {
        const model = OdsSummaryComponent(
          label: 'None',
          value: '{COUNT(tasks)}',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsSummaryWidget(model: model)),
        );
        expect(find.text('0'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Icon renders when specified', (tester) async {
      final booted = await bootEngineFor(tester, _kTasksSpec);
      try {
        const model = OdsSummaryComponent(
          label: 'Done',
          value: '5',
          icon: 'check_circle',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsSummaryWidget(model: model)),
        );
        expect(find.byType(Icon), findsAtLeastNWidgets(1));
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
