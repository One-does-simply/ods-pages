import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/engine/settings_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// =========================================================================
// AI settings on SettingsStore (ADR-0003 phase 2). Persistence + setters.
// Avoids touching the live ods_settings.json by pointing the resolver
// at a temp folder via the bootstrap mechanism + a fake path_provider.
// =========================================================================

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

void main() {
  late Directory tmp;
  late SettingsStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ods_settings_ai_');
    PathProviderPlatform.instance = _FakePathProvider(tmp);
    await writeBootstrapStorageFolder(tmp.path);
    store = SettingsStore();
    await store.initialize();
  });

  tearDown(() async {
    if (await tmp.exists()) {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('SettingsStore — AI defaults', () {
    test('aiProvider is null when never set', () {
      expect(store.aiProvider, isNull);
      expect(store.aiApiKey, '');
      expect(store.aiModel, '');
      expect(store.isAiConfigured, isFalse);
    });
  });

  group('SettingsStore — AI setters', () {
    test('setAiProvider("anthropic") + key + model → isAiConfigured', () async {
      await store.setAiProvider('anthropic');
      await store.setAiApiKey('sk-ant-test');
      await store.setAiModel('claude-sonnet-4-6');
      expect(store.aiProvider, 'anthropic');
      expect(store.aiApiKey, 'sk-ant-test');
      expect(store.aiModel, 'claude-sonnet-4-6');
      expect(store.isAiConfigured, isTrue);
    });

    test('isAiConfigured remains false until model is set', () async {
      await store.setAiProvider('openai');
      await store.setAiApiKey('sk-openai-test');
      expect(store.isAiConfigured, isFalse);
      await store.setAiModel('gpt-4o-mini');
      expect(store.isAiConfigured, isTrue);
    });

    test('setAiProvider(null) clears key and model too', () async {
      await store.setAiProvider('anthropic');
      await store.setAiApiKey('sk-ant-test');
      await store.setAiModel('claude-sonnet-4-6');
      expect(store.isAiConfigured, isTrue);
      await store.setAiProvider(null);
      expect(store.aiProvider, isNull);
      expect(store.aiApiKey, '');
      expect(store.aiModel, '');
      expect(store.isAiConfigured, isFalse);
    });

    test('rejects unknown provider names', () async {
      expect(
        () => store.setAiProvider('cohere'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SettingsStore — AI persistence', () {
    test('settings round-trip across initialize()', () async {
      await store.setAiProvider('anthropic');
      await store.setAiApiKey('sk-ant-roundtrip');
      await store.setAiModel('claude-sonnet-4-6');

      // Spin up a fresh store pointing at the same folder.
      final reloaded = SettingsStore();
      await reloaded.initialize();
      expect(reloaded.aiProvider, 'anthropic');
      expect(reloaded.aiApiKey, 'sk-ant-roundtrip');
      expect(reloaded.aiModel, 'claude-sonnet-4-6');
      expect(reloaded.isAiConfigured, isTrue);
    });

    test('clears persisted values when provider is set to null', () async {
      await store.setAiProvider('openai');
      await store.setAiApiKey('sk-openai-test');
      await store.setAiModel('gpt-4o-mini');
      await store.setAiProvider(null);

      final reloaded = SettingsStore();
      await reloaded.initialize();
      expect(reloaded.aiProvider, isNull);
      expect(reloaded.aiApiKey, '');
      expect(reloaded.aiModel, '');
    });
  });
}
