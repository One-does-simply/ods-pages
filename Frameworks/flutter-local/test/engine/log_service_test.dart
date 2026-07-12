import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/engine/log_service.dart';

// =========================================================================
// Regression: LogService must not leave a dangling flush Timer when it has
// no file sink (i.e. before initialize(), which is the state in every unit
// and widget test — the harness boots AppEngine, never LogService).
//
// Why this matters: DataStore.query calls logDebug on every query. If the
// deferred 1s flush Timer is created while flutter_test's FakeAsync zone is
// active (during a pump()), it never fires and stays pending until
// teardown, tripping the binding's `!timersPending` assertion. That was the
// root cause of the long-standing, load-sensitive widget-test flake
// (chart/list/detail/kanban/text "Renders …" tests failing intermittently
// with a shifting blame set).
//
// The fix: _scheduleFlush() no-ops when _logFile == null. This test pins
// that behavior at the timer boundary so the flake can't silently return.
// =========================================================================

void main() {
  group('LogService flush scheduling', () {
    test('does not schedule a Timer when uninitialized (no file sink)', () {
      fakeAsync((async) {
        // Singleton is uninitialized in this fresh test isolate — _logFile
        // is null, so logging must buffer without arming a flush Timer.
        LogService.instance.debug('Test', 'query-style debug log');
        LogService.instance.info('Test', 'another entry');

        expect(
          async.pendingTimers,
          isEmpty,
          reason: 'an uninitialized LogService must not leave a dangling '
              'flush Timer — it would trip flutter_test !timersPending when '
              'the log fires inside a pump() in the FakeAsync zone',
        );
      });
    });
  });
}
