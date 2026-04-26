
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_page.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/page_renderer.dart';

import '_test_harness.dart';

const String _kSpec = '''
{
  "appName": "PageRendererTest",
  "startPage": "home",
  "pages": {"home": {"component": "page", "title": "Home", "content": []}}
}
''';

void main() {
  group('PageRenderer', () {
    testWidgets('Dispatches to text component', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const page = OdsPage(
          title: 'Home',
          content: [
            OdsTextComponent(content: 'Hello from page renderer', styleHint: OdsStyleHint({})),
          ],
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const PageRenderer(page: page),
          ),
        );
        expect(find.text('Hello from page renderer'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Renders multiple components in order', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        const page = OdsPage(
          title: 'Home',
          content: [
            OdsTextComponent(content: 'First', styleHint: OdsStyleHint({})),
            OdsTextComponent(content: 'Second', styleHint: OdsStyleHint({})),
            OdsTextComponent(content: 'Third', styleHint: OdsStyleHint({})),
          ],
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const PageRenderer(page: page),
          ),
        );
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Third'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Empty content renders nothing but no crash', (tester) async {
      final booted = await bootEngineFor(tester, _kSpec);
      try {
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const PageRenderer(page: OdsPage(title: 'Home', content: [])),
          ),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
