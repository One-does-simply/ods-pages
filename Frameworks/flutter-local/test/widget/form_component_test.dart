
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_flutter_local/models/ods_action.dart';
import 'package:ods_flutter_local/models/ods_component.dart';
import 'package:ods_flutter_local/models/ods_field_definition.dart';
import 'package:ods_flutter_local/models/ods_style_hint.dart';
import 'package:ods_flutter_local/renderer/components/form_component.dart';

import '_test_harness.dart';

/// Spec with a questions data source so `recordSource` pre-fill can be tested.
const String _kFormSpec = '''
{
  "appName": "FormTest",
  "startPage": "home",
  "pages": {
    "home": {
      "component": "page",
      "title": "Home",
      "content": [
        {
          "component": "form",
          "id": "quizForm",
          "recordSource": "questions",
          "fields": [
            {"name": "question", "type": "text", "label": "Q"},
            {"name": "answer", "type": "text", "label": "A"}
          ]
        }
      ]
    }
  },
  "dataSources": {
    "questions": {
      "url": "local://questions",
      "method": "POST",
      "fields": [
        {"name": "question", "type": "text", "label": "Q"},
        {"name": "answer", "type": "text", "label": "A"}
      ]
    }
  }
}
''';

void main() {
  group('OdsFormWidget', () {
    testWidgets('Renders all supported field types', (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'mixedForm',
          fields: [
            OdsFieldDefinition(name: 'name', type: 'text', label: 'Name'),
            OdsFieldDefinition(name: 'age', type: 'number', label: 'Age'),
            OdsFieldDefinition(name: 'dob', type: 'date', label: 'DOB'),
            OdsFieldDefinition(
              name: 'color',
              type: 'select',
              label: 'Color',
              options: ['Red', 'Blue'],
            ),
            OdsFieldDefinition(
              name: 'subscribe',
              type: 'checkbox',
              label: 'Subscribe',
            ),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Age'), findsOneWidget);
        expect(find.text('DOB'), findsOneWidget);
        expect(find.text('Color'), findsOneWidget);
        expect(find.text('Subscribe'), findsOneWidget);

        // Multiple TextField widgets (text, number, date) plus a dropdown
        // and a switch.
        expect(find.byType(TextField), findsWidgets);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Entering text updates form state on engine',
        (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'simpleForm',
          fields: [
            OdsFieldDefinition(name: 'title', type: 'text', label: 'Title'),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );

        await tester.enterText(find.byType(TextField).first, 'Hello');
        await tester.pump();

        final state = booted.engine.getFormState('simpleForm');
        expect(state['title'], 'Hello',
            reason:
                'onChanged should push the typed value into engine form state.');
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets(
        'Required field label has trailing " *" marker — submit-time '
        'validation is NOT a widget concern',
        (WidgetTester tester) async {
      // The widget itself does not show inline errors until the user types
      // or submits. This test verifies the visible " *" marker.
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'reqForm',
          fields: [
            OdsFieldDefinition(
              name: 'name',
              type: 'text',
              label: 'Name',
              required: true,
            ),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        expect(find.text('Name *'), findsOneWidget,
            reason: 'Required field label should have trailing " *".');
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Default values populate on first render',
        (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'defForm',
          fields: [
            OdsFieldDefinition(
              name: 'status',
              type: 'text',
              label: 'Status',
              defaultValue: 'open',
            ),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        expect(booted.engine.getFormState('defForm')['status'], 'open');
        expect(find.text('open'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Computed (formula) field renders read-only with suffix',
        (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'computedForm',
          fields: [
            OdsFieldDefinition(name: 'a', type: 'number', label: 'A'),
            OdsFieldDefinition(name: 'b', type: 'number', label: 'B'),
            OdsFieldDefinition(
              name: 'sum',
              type: 'number',
              label: 'Sum',
              formula: '{a} + {b}',
            ),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        expect(find.text('Sum (computed)'), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('recordSource pre-fills form via firstRecord action',
        (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        // Seed a single question + drive the firstRecord cursor inside
        // tester.runAsync so the SQLite work happens in the real async
        // zone (flutter_test FakeAsync intercepts but never fires the
        // sqflite_ffi native-bridge timers — see _test_harness.dart).
        final ds = booted.engine.dataStore;
        await tester.runAsync(() async {
          await ds.ensureTable('questions', [
            const OdsFieldDefinition(name: 'question', type: 'text'),
            const OdsFieldDefinition(name: 'answer', type: 'text'),
          ]);
          await ds.insert('questions', {'question': 'What?', 'answer': '42'});

          await booted.engine.executeActions(const [
            OdsAction(action: 'firstRecord', target: 'quizForm'),
          ]);
        });

        const model = OdsFormComponent(
          id: 'quizForm',
          recordSource: 'questions',
          fields: [
            OdsFieldDefinition(name: 'question', type: 'text', label: 'Q'),
            OdsFieldDefinition(name: 'answer', type: 'text', label: 'A'),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        final qState = booted.engine.getFormState('quizForm');
        expect(qState['question'], 'What?',
            reason:
                'firstRecord should populate form state with the seeded question.');
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Select dropdown renders with static options',
        (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'selForm',
          fields: [
            OdsFieldDefinition(
              name: 'priority',
              type: 'select',
              label: 'Priority',
              options: ['Low', 'High'],
            ),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });

    testWidgets('Hidden field type does not render any input',
        (WidgetTester tester) async {
      final booted = await bootEngineFor(tester, _kFormSpec);
      try {
        const model = OdsFormComponent(
          id: 'hidForm',
          fields: [
            OdsFieldDefinition(name: 'visible', type: 'text', label: 'Visible'),
            OdsFieldDefinition(
              name: 'secret',
              type: 'hidden',
              defaultValue: 'shh',
            ),
          ],
          styleHint: OdsStyleHint({}),
        );
        await pumpAndSettle(
          tester,
          harness(
            engine: booted.engine,
            child: const OdsFormWidget(model: model),
          ),
        );
        expect(find.text('Visible'), findsOneWidget);
        // Hidden field should still initialize form state from defaultValue.
        expect(booted.engine.getFormState('hidForm')['secret'], 'shh');
        // But no UI label for the secret field.
        expect(find.text('secret'), findsNothing);
      } finally {
        await disposeAllFor(tester, booted);
      }
    });
  });
}
