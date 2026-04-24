/// ODS conformance runner for the Flutter renderer.
///
/// Mirrors conformance.test.ts — iterates the scenarios declared in
/// scenarios.dart and runs each against a fresh FlutterDriver. Scenarios
/// whose required capabilities exceed what the driver advertises are
/// skipped (not failed), matching the TS runner's behavior.
library;

import 'package:flutter_test/flutter_test.dart';

import 'flutter_driver.dart';
import 'scenarios.dart';

void main() {
  group('ODS conformance (FlutterDriver)', () {
    for (final scenario in allScenarios) {
      final driverCaps = FlutterDriver().capabilities;
      final supported = scenario.capabilities.every(driverCaps.contains);

      if (!supported) {
        test(scenario.name, () {}, skip: 'driver lacks required capabilities');
        continue;
      }

      test(scenario.name, () async {
        final driver = FlutterDriver();
        try {
          await driver.mount(scenario.spec());
          await driver.setSeed(0);
          await driver.setClock('2026-01-01T00:00:00Z');
          await scenario.run(driver);
        } finally {
          await driver.unmount();
        }
      });
    }
  });
}
