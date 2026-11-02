import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux_wallet/services/update_service.dart';

/// Uji logika murni layanan OTA: parse update.json (termasuk
/// catatan dwibahasa + entri per ABI), pemilihan entri ABI,
/// pemilihan bahasa catatan, dan perbandingan hash. Pola mencontek
/// test OTA nusan-catcher, diperluas untuk x86_64 dan dwibahasa
/// (syarat NUX 2 Nov 2026).
void main() {
  Map<String, dynamic> jsonLengkap() => {
    'versi': 'Build 2070',
    'versionCode': 2070,
    'sha256': 'AAAA',
    'urlUnduh': 'https://contoh.id/elnux-arm64.apk',
    'catatanId': 'Perbaikan filter riwayat • lebih cepat',
    'catatanEn': 'History filter fixes • faster',
    'sha256V7a': 'BBBB',
    'urlUnduhV7a': 'https://contoh.id/elnux-v7a.apk',
    'sha256X64': 'CCCC',
    'urlUnduhX64': 'https://contoh.id/elnux-x64.apk',
  };

  group('UpdateInfo.dariJson', () {
    test('format lengkap ter-parse semua field', () {
      final info = UpdateInfo.dariJson(jsonLengkap())!;
      expect(info.versi, 'Build 2070');
      expect(info.versionCode, 2070);
      expect(info.sha256, 'AAAA');
      expect(info.urlUnduh, 'https://contoh.id/elnux-arm64.apk');
      expect(info.catatanId, contains('filter'));
      expect(info.catatanEn, contains('History'));
      expect(info.sha256V7a, 'BBBB');
      expect(info.sha256X64, 'CCCC');
    });

    test('tanpa entri opsional tetap sah, catatan kosong', () {
      final info = UpdateInfo.dariJson({
        'versi': 'Build 1',
        'versionCode': 1,
        'sha256': 'AA',
        'urlUnduh': 'https://contoh.id/a.apk',
      })!;
      expect(info.sha256V7a, isNull);
      expect(info.sha256X64, isNull);
      expect(info.catatanId, '');
      expect(info.catatanEn, '');
    });

    test('field wajib rusak -> null', () {
      final dasar = jsonLengkap();
      for (final kunci in ['versi', 'versionCode', 'sha256', 'urlUnduh']) {
        final rusak = Map<String, dynamic>.from(dasar)..remove(kunci);
        expect(UpdateInfo.dariJson(rusak), isNull, reason: kunci);
      }
      final urlTakBerskema = Map<String, dynamic>.from(dasar)
        ..['urlUnduh'] = 'elnux-arm64.apk';
      expect(UpdateInfo.dariJson(urlTakBerskema), isNull);
      final catatanRusak = Map<String, dynamic>.from(dasar)..['catatanId'] = 42;
      expect(UpdateInfo.dariJson(catatanRusak), isNull);
    });

    test('pasangan opsional setengah rusak diabaikan, bukan menggagalkan', () {
      final j = jsonLengkap()
        ..remove('urlUnduhV7a')
        ..['sha256X64'] = '   ';
      final info = UpdateInfo.dariJson(j)!;
      expect(info.sha256V7a, isNull);
      expect(info.urlUnduhV7a, isNull);
      expect(info.sha256X64, isNull);
      expect(info.sha256, 'AAAA');
    });
  });

  group('UpdateInfo.dariBytes', () {
    test('UTF-8 utuh: emoji catatan tidak mojibake', () {
      final bytes = utf8.encode(jsonEncode(jsonLengkap()));
      final info = UpdateInfo.dariBytes(bytes)!;
      expect(info.catatanId, contains('•'));
      expect(info.catatanId, isNot(contains('â')));
    });

    test('byte sampah / bukan peta -> null', () {
      expect(UpdateInfo.dariBytes([0xFF, 0x00, 0x41]), isNull);
      expect(UpdateInfo.dariBytes(utf8.encode('[1,2,3]')), isNull);
      expect(UpdateInfo.dariBytes(utf8.encode('{}')), isNull);
    });
  });

  group('UpdateInfo.untukAbi', () {
    final info = UpdateInfo.dariJson(jsonLengkap())!;

    test('armeabi-v7a memilih entri v7a', () {
      final v = info.untukAbi('armeabi-v7a');
      expect(v.sha256, 'BBBB');
      expect(v.urlUnduh, contains('v7a'));
      // Catatan + versi ikut terbawa.
      expect(v.catatanEn, info.catatanEn);
      expect(v.versi, info.versi);
    });

    test('x86_64 memilih entri x86_64', () {
      final v = info.untukAbi('x86_64');
      expect(v.sha256, 'CCCC');
      expect(v.urlUnduh, contains('x64'));
    });

    test('arm64 / tak dikenal tetap entri bawaan', () {
      expect(info.untukAbi('arm64-v8a').sha256, 'AAAA');
      expect(info.untukAbi('unknown').sha256, 'AAAA');
    });

    test('entri khusus tak ada -> jatuh ke bawaan', () {
      final polos = UpdateInfo.dariJson({
        'versi': 'B',
        'versionCode': 1,
        'sha256': 'AA',
        'urlUnduh': 'https://contoh.id/a.apk',
      })!;
      expect(polos.untukAbi('armeabi-v7a').sha256, 'AA');
      expect(polos.untukAbi('x86_64').sha256, 'AA');
    });
  });

  group('UpdateInfo.catatanUntuk', () {
    test('en -> Inggris, id -> Indonesia', () {
      final info = UpdateInfo.dariJson(jsonLengkap())!;
      expect(info.catatanUntuk('en'), contains('History'));
      expect(info.catatanUntuk('id'), contains('filter'));
    });

    test('bahasa diminta kosong -> jatuh ke bahasa satunya', () {
      const hanyaId = UpdateInfo(
        versi: 'B',
        versionCode: 1,
        sha256: 'AA',
        urlUnduh: 'https://contoh.id/a.apk',
        catatanId: 'Hanya Indonesia',
      );
      expect(hanyaId.catatanUntuk('en'), 'Hanya Indonesia');
      const kosong = UpdateInfo(
        versi: 'B',
        versionCode: 1,
        sha256: 'AA',
        urlUnduh: 'https://contoh.id/a.apk',
      );
      expect(kosong.catatanUntuk('en'), '');
      expect(kosong.catatanUntuk('id'), '');
    });
  });

  group('perluPembaruan', () {
    test('hash sama (beda huruf besar/kecil + spasi) -> false', () {
      expect(
        perluPembaruan(hashTerpasang: ' abCD ', hashRilis: 'ABcd'),
        isFalse,
      );
    });

    test('hash berbeda -> true', () {
      expect(perluPembaruan(hashTerpasang: 'aaaa', hashRilis: 'aaab'), isTrue);
    });
  });
}
