
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_field_definition.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/components/chart_component.dart';

import '_test_harness.dart';

const String _kSpec = '''
{
  "appName": "ChartTest",
  "startPage": "home",
  "pages": {"home": {"component": "page", "title": "Home", "content": []}},
  "dataSources": {
    "sales": {
      "url": "local://sales",
      "method": "POST",
      "fields": [
        {"name": "month", "type": "text", "label": "Month"},
        {"name": "revenue", "type": "number", "label": "Revenue"}
      ]
    }
  }
}
''';

void main() {
  group('OdsChartWidget', () {
    testWidgets('Renders without crash on empty data', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const model = OdsChartComponent(
          dataSource: 'sales',
          chartType: 'bar',
          labelField: 'month',
          valueField: 'revenue',
          aggregate: 'sum',
          styleHint: OdsStyleHint({}),
        );
        // Empty-data path renders synchronously; a long pumpAndSettle
        // gives stale FutureBuilders from prior tests time to throw
        // into takeException (intermittent flake under full-gate load).
        // A single short pump is enough — the no-data branch doesn't
        // need any SQLite round-trip to render.
        await tester.pumpWidget(
          harness(engine: booted.engine, child: const OdsChartWidget(model: model)),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Renders bar chart with data', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('sales', [
            const OdsFieldDefinition(name: 'month', type: 'text'),
            const OdsFieldDefinition(name: 'revenue', type: 'number'),
          ]);
          await ds.insert('sales', {'month': 'Jan', 'revenue': '100'});
          await ds.insert('sales', {'month': 'Feb', 'revenue': '200'});
        });

        const model = OdsChartComponent(
          dataSource: 'sales',
          chartType: 'bar',
          labelField: 'month',
          valueField: 'revenue',
          aggregate: 'sum',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsChartWidget(model: model)),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Renders title when provided', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        // Title only renders inside the chart-with-data branch; the
        // empty-data path shows "No data for chart." instead. Seed a row.
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('sales', [
            const OdsFieldDefinition(name: 'month', type: 'text'),
            const OdsFieldDefinition(name: 'revenue', type: 'number'),
          ]);
          await ds.insert('sales', {'month': 'Jan', 'revenue': '100'});
        });

        const model = OdsChartComponent(
          dataSource: 'sales',
          chartType: 'bar',
          labelField: 'month',
          valueField: 'revenue',
          aggregate: 'sum',
          title: 'Monthly Revenue',
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsChartWidget(model: model)),
        );
        expect(find.text('Monthly Revenue'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
