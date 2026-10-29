import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nux_wallet/config.dart';
import 'package:nux_wallet/services/lsp_profile.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official profile is valid', () {
    expect(LspProfile.official.isValid, isTrue);
    expect(LspProfile.official.isConfigured, isTrue);
  });

  test('fromJson roundtrip and invalid rejection', () {
    final profile = LspProfile.official;
    expect(LspProfile.fromJson(profile.toJson()), isNotNull);
    final bad = Map<String, dynamic>.from(profile.toJson())
      ..['lspNodeId'] = '00' + 'ab' * 32;
    expect(LspProfile.fromJson(bad), isNull);
    final badAddress = Map<String, dynamic>.from(profile.toJson())
      ..['lspAddress'] = 'no-port-here';
    expect(LspProfile.fromJson(badAddress), isNull);
  });

  test('save invalid throws, save valid then load returns it', () async {
    SharedPreferences.setMockInitialValues({});
    final bad = LspProfile(
      id: 'x',
      name: 'X',
      lspAddress: 'bad',
      lspNodeId: '02' + 'ab' * 32,
      lspToken: '',
      electrumUrl: 'tcp://example.org:50009',
      isTestnet: AppConfig.isTestnet,
    );
    expect(() => LspProfileStore.save(bad), throwsArgumentError);
    final custom = LspProfile(
      id: 'custom1',
      name: 'LSP Saya',
      lspAddress: 'lsp.example.org:9739',
      lspNodeId: '03' + 'cd' * 32,
      lspToken: 'tok',
      electrumUrl: 'tcp://lsp.example.org:50009',
      isTestnet: AppConfig.isTestnet,
    );
    await LspProfileStore.save(custom);
    final loaded = await LspProfileStore.load();
    expect(loaded.id, 'custom1');
    expect(loaded.lspAddress, 'lsp.example.org:9739');
    await LspProfileStore.clear();
    expect((await LspProfileStore.load()).id, 'official');
  });

  test('saved profile from other network is discarded', () async {
    final other = LspProfile(
      id: 'other-net',
      name: 'Other',
      lspAddress: 'lsp.example.org:9739',
      lspNodeId: '03' + 'cd' * 32,
      lspToken: '',
      electrumUrl: 'tcp://lsp.example.org:50009',
      isTestnet: !AppConfig.isTestnet,
    );
    SharedPreferences.setMockInitialValues({
      'lsp_profile': jsonEncode(other.toJson()),
    });
    // Profil jaringan lain yang tersimpan harus dibuang ke official.
    expect(other.isTestnet, isNot(AppConfig.isTestnet));
    expect((await LspProfileStore.load()).id, 'official');
  });
}
