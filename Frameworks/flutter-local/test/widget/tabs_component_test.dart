
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/components/tabs_component.dart';

import '_test_harness.dart';

const String _kSpec = '''
{
  "appName": "TabsTest",
  "startPage": "home",
  "pages": {"home": {"component": "page", "title": "Home", "content": []}}
}
''';

void main() {
  group('OdsTabsWidget', () {
    testWidgets('Renders all tab labels', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const model = OdsTabsComponent(
          tabs: [
            OdsTabDefinition(label: 'Overview', content: [
              OdsTextComponent(content: 'Overview content', styleHint: OdsStyleHint({}))
            ]),
            OdsTabDefinition(label: 'Details', content: [
              OdsTextComponent(content: 'Details content', styleHint: OdsStyleHint({}))
            ]),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsTabsWidget(model: model)),
        );
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Details'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('First tab content renders by default', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const model = OdsTabsComponent(
          tabs: [
            OdsTabDefinition(label: 'One', content: [
              OdsTextComponent(content: 'Tab 1 body', styleHint: OdsStyleHint({}))
            ]),
            OdsTabDefinition(label: 'Two', content: [
              OdsTextComponent(content: 'Tab 2 body', styleHint: OdsStyleHint({}))
            ]),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsTabsWidget(model: model)),
        );
        expect(find.text('Tab 1 body'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Tapping second tab switches content', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const model = OdsTabsComponent(
          tabs: [
            OdsTabDefinition(label: 'Alpha', content: [
              OdsTextComponent(content: 'Alpha body', styleHint: OdsStyleHint({}))
            ]),
            OdsTabDefinition(label: 'Beta', content: [
              OdsTextComponent(content: 'Beta body', styleHint: OdsStyleHint({}))
            ]),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(engine: booted.engine, child: const OdsTabsWidget(model: model)),
        );
        await tester.tap(find.text('Beta'));
        await tester.pumpAndSettle();
        expect(find.text('Beta body'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
