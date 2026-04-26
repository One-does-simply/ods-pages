import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ods_flutter_local/engine/app_engine.dart';

/// Wraps [child] in a MaterialApp + Scaffold with the given [engine] exposed
/// via Provider, so components that call `context.watch<AppEngine>()` /
/// `context.read<AppEngine>()` can locate it.
Widget harness({required AppEngine engine, required Widget child}) {
  return MaterialApp(
    home: ChangeNotifierProvider<AppEngine>.value(
      value: engine,
      child: Scaffold(body: child),
    ),
  );
}

/// Creates a fully-initialized [AppEngine] against a throwaway temp folder
/// so widget tests get real data-store behavior without polluting shared dirs.
///
/// [specJson] should be the full app-spec JSON string.
///
/// MUST be called inside [WidgetTester.runAsync]. sqflite_ffi schedules
/// native-bridge work that flutter_test's FakeAsync zone intercepts but
/// never fires — without `runAsync`, `loadSpec` deadlocks. Use [bootEngineFor]
/// for the common case; this raw form exists for non-widget tests.
Future<_BootedEngine> bootEngine(String specJson) async {
  final tmp = await Directory.systemTemp.createTemp('ods_widget_');
  final engine = AppEngine();
  engine.storageFolder = tmp.path;
  final ok = await engine.loadSpec(specJson);
  if (!ok) {
    throw StateError('loadSpec failed: ${engine.loadError}');
  }
  return _BootedEngine(engine: engine, tmp: tmp);
}

/// Convenience: runs [bootEngine] inside the tester's real async zone so
/// sqflite_ffi work completes. Always prefer this in `testWidgets`.
Future<_BootedEngine> bootEngineFor(WidgetTester tester, String specJson) async {
  final booted = await tester.runAsync(() => bootEngine(specJson));
  if (booted == null) {
    throw StateError('bootEngineFor: tester.runAsync returned null');
  }
  return booted;
}

class _BootedEngine {
  final AppEngine engine;
  final Directory tmp;
  _BootedEngine({required this.engine, required this.tmp});

  /// Tear down. Run inside [WidgetTester.runAsync] from a `testWidgets`
  /// body — see [disposeAllFor] for the convenience wrapper.
  Future<void> disposeAll() async {
    await engine.reset();
    engine.dispose();
    if (await tmp.exists()) {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }
}

/// Convenience: runs [_BootedEngine.disposeAll] inside the tester's real
/// async zone so the SQLite close + temp-dir delete don't deadlock.
Future<void> disposeAllFor(WidgetTester tester, _BootedEngine booted) async {
  await tester.runAsync(() => booted.disposeAll());
}

/// Pumps [widget] into [tester]. Cannot use [WidgetTester.pumpAndSettle]:
/// it waits for FakeAsync to drain, but sqflite_ffi keeps native-bridge
/// timers alive that FakeAsync never fires, so pumpAndSettle would always
/// hit its max-iterations timeout.
///
/// Instead we alternate `tester.runAsync(delay)` (which lets the real
/// event loop run so SQLite-bound FutureBuilders resolve) with `pump()`
/// (which flushes the rebuild). For widgets with chained futures we may
/// need several rounds before the tree stabilises; [maxRounds] caps the
/// loop. Empirically 4 rounds × 50ms covers every component in this
/// codebase including FormComponent's recordSource cursor.
Future<void> pumpAndSettle(
  WidgetTester tester,
  Widget widget, {
  Duration roundDuration = const Duration(milliseconds: 50),
  int maxRounds = 4,
}) async {
  await tester.pumpWidget(widget);
  for (var i = 0; i < maxRounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(roundDuration));
    await tester.pump();
  }
}
