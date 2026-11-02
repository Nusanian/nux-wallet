/// Layanan pembaruan OTA (over-the-air) berbasis hash berkas —
/// port gaya nusan-catcher ke ELNUX (keputusan NUX 2 Nov 2026).
///
/// Alur:
///
/// 1. [UpdateService.cek] mengunduh `update.json` dari kanal rilis
///    kulit yang sedang berjalan (testnet: rilis GitHub repo ini;
///    mainnet: VPS sendiri sampai pengumuman publik — lihat
///    [_urlUpdateMainnet]), menanyakan jalur APK terpasang + ABI
///    lewat MethodChannel ke sisi native, menghitung SHA-256 APK
///    terpasang di isolate, lalu membandingkannya dengan hash di
///    `update.json`. Hash berbeda = ada versi baru. Deteksi berbasis
///    hash (bukan nomor versi) membuat build ulang apa pun pasti
///    terdeteksi, dan tangga versionCode CI yang selalu naik
///    mengurus sisanya.
/// 2. [UpdateService.unduhDanPasang] mengunduh APK rilis ke cache
///    dengan laporan progres, **memverifikasi SHA-256 hasil unduhan
///    sebelum memasang** (pelajaran lapangan nusan-catcher: unduhan
///    rusak yang tidak diverifikasi membuat instalasi gagal
///    diam-diam), lalu meminta sisi native membuka installer sistem.
///
/// Catatan rilis di `update.json` DWIBAHASA (syarat NUX 2 Nov
/// 2026): field `catatanId` + `catatanEn`; dialog menampilkan yang
/// sesuai bahasa aplikasi ([UpdateInfo.catatanUntuk]).
///
/// Prinsip: pemeriksaan yang gagal (jaringan mati, JSON rusak,
/// native belum siap) TIDAK melempar error ke UI — hasilnya
/// [UpdateCheckStatus.failed], diperlakukan pemanggil sebagai
/// "tidak ada pembaruan" untuk cek otomatis; cek manual di Profil
/// membedakannya lewat status hasil.

library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';

/// Informasi versi baru yang tersedia di kanal rilis.
///
/// `update.json` membawa entri APK per ABI: arm64-v8a (field
/// [sha256]/[urlUnduh], bawaan), armeabi-v7a ([sha256V7a]/
/// [urlUnduhV7a], opsional), dan x86_64 ([sha256X64]/[urlUnduhX64],
/// opsional — untuk emulator; nusan-catcher tidak memakainya,
/// ELNUX menerbitkannya). [cek] memilih entri sesuai ABI aplikasi
/// yang TERPASANG lewat [untukAbi] sebelum membandingkan hash.
class UpdateInfo {
  const UpdateInfo({
    required this.versi,
    required this.versionCode,
    required this.sha256,
    required this.urlUnduh,
    this.catatanId = '',
    this.catatanEn = '',
    this.sha256V7a,
    this.urlUnduhV7a,
    this.sha256X64,
    this.urlUnduhX64,
  });

  final String versi;
  final int versionCode;
  final String sha256;
  final String urlUnduh;
  final String catatanId;
  final String catatanEn;

  /// Entri APK armeabi-v7a (null bila `update.json` tanpa entri v7a).
  final String? sha256V7a;
  final String? urlUnduhV7a;

  /// Entri APK x86_64 (null bila `update.json` tanpa entri x86_64).
  final String? sha256X64;
  final String? urlUnduhX64;

  /// Salinan info dengan entri sesuai [abi] terpasang
  /// ('arm64-v8a', 'armeabi-v7a', 'x86_64', atau lainnya). ABI yang
  /// entri khususnya tidak ada / tidak lengkap jatuh ke entri
  /// arm64 bawaan. Fungsi murni — diuji di
  /// test/update_service_test.dart.
  UpdateInfo untukAbi(String abi) {
    if (abi == 'armeabi-v7a' && sha256V7a != null && urlUnduhV7a != null) {
      return UpdateInfo(
        versi: versi,
        versionCode: versionCode,
        sha256: sha256V7a!,
        urlUnduh: urlUnduhV7a!,
        catatanId: catatanId,
        catatanEn: catatanEn,
      );
    }
    if (abi == 'x86_64' && sha256X64 != null && urlUnduhX64 != null) {
      return UpdateInfo(
        versi: versi,
        versionCode: versionCode,
        sha256: sha256X64!,
        urlUnduh: urlUnduhX64!,
        catatanId: catatanId,
        catatanEn: catatanEn,
      );
    }
    return this;
  }

  /// Catatan rilis untuk bahasa [languageCode] ('en' → Inggris,
  /// selain itu Indonesia). Bila bahasa yang diminta kosong, jatuh
  /// ke bahasa satunya; keduanya kosong → string kosong.
  /// Fungsi murni — diuji.
  String catatanUntuk(String languageCode) {
    if (languageCode == 'en') {
      return catatanEn.isNotEmpty ? catatanEn : catatanId;
    }
    return catatanId.isNotEmpty ? catatanId : catatanEn;
  }

  /// Parse byte mentah `update.json` (selalu didekode UTF-8).
  ///
  /// PENTING: jangan memakai `respons.body` dari paket http untuk
  /// berkas ini — unduhan GitHub tidak menyertakan charset pada
  /// headernya sehingga `body` didekode sebagai Latin-1 dan semua
  /// karakter non-ASCII (emoji, tanda •) pada catatan rilis berubah
  /// menjadi mojibake (temuan nusan-catcher 21 Okt 2026).
  /// Fungsi murni — diuji.
  static UpdateInfo? dariBytes(List<int> bytes) {
    try {
      final dinamis = jsonDecode(utf8.decode(bytes));
      if (dinamis is! Map<String, dynamic>) return null;
      return dariJson(dinamis);
    } catch (_) {
      return null;
    }
  }

  /// Pasangan hash + URL opsional diterima hanya bila KEDUANYA
  /// lengkap dan URL-nya berskema; pasangan rusak diabaikan
  /// (jatuh ke entri arm64) agar tidak merusak pembaruan pengguna
  /// ABI lain.
  static (String?, String?) _pasanganOpsional(
    Map<String, dynamic> json,
    String kunciHash,
    String kunciUrl,
  ) {
    final hash = json[kunciHash];
    final url = json[kunciUrl];
    if (hash is String &&
        hash.trim().isNotEmpty &&
        url is String &&
        url.trim().isNotEmpty) {
      final uri = Uri.tryParse(url.trim());
      if (uri != null && uri.hasScheme) {
        return (hash.trim(), url.trim());
      }
    }
    return (null, null);
  }

  /// Parse isi `update.json`. Kembalikan null bila format tidak
  /// valid. Fungsi murni — diuji di test/update_service_test.dart.
  static UpdateInfo? dariJson(Map<String, dynamic> json) {
    final versi = json['versi'];
    final versionCode = json['versionCode'];
    final sha256 = json['sha256'];
    final urlUnduh = json['urlUnduh'];
    final catatanId = json['catatanId'];
    final catatanEn = json['catatanEn'];
    if (versi is! String || versi.isEmpty) return null;
    if (versionCode is! num) return null;
    if (sha256 is! String || sha256.trim().isEmpty) return null;
    if (urlUnduh is! String || urlUnduh.trim().isEmpty) return null;
    if (catatanId != null && catatanId is! String) return null;
    if (catatanEn != null && catatanEn is! String) return null;
    final uri = Uri.tryParse(urlUnduh.trim());
    if (uri == null || !uri.hasScheme) return null;
    final (shaV7a, urlV7a) = _pasanganOpsional(
      json,
      'sha256V7a',
      'urlUnduhV7a',
    );
    final (shaX64, urlX64) = _pasanganOpsional(
      json,
      'sha256X64',
      'urlUnduhX64',
    );
    return UpdateInfo(
      versi: versi,
      versionCode: versionCode.toInt(),
      sha256: sha256.trim(),
      urlUnduh: urlUnduh.trim(),
      catatanId: (catatanId as String?)?.trim() ?? '',
      catatanEn: (catatanEn as String?)?.trim() ?? '',
      sha256V7a: shaV7a,
      urlUnduhV7a: urlV7a,
      sha256X64: shaX64,
      urlUnduhX64: urlX64,
    );
  }
}

/// true bila hash rilis berbeda dari hash APK yang terpasang.
///
/// Perbandingan tidak peka huruf besar/kecil karena heksadesimal
/// boleh ditulis uppercase. Fungsi murni — diuji.
bool perluPembaruan({
  required String hashTerpasang,
  required String hashRilis,
}) {
  return hashTerpasang.trim().toLowerCase() != hashRilis.trim().toLowerCase();
}

/// Hasil pemeriksaan pembaruan. Cek otomatis hanya bertindak pada
/// [UpdateCheckStatus.updateAvailable]; cek manual melaporkan
/// status lain ke pengguna.
enum UpdateCheckStatus { updateAvailable, upToDate, failed, disabled }

class UpdateCheckResult {
  const UpdateCheckResult(this.status, [this.info]);

  final UpdateCheckStatus status;

  /// Terisi hanya bila [status] adalah updateAvailable.
  final UpdateInfo? info;
}

/// Hitung SHA-256 sebuah berkas. Dijalankan di isolate via
/// [compute] agar UI tidak tersendat saat membaca APK puluhan MB.
String _sha256Berkas(String jalur) {
  final data = File(jalur).readAsBytesSync();
  return sha256.convert(data).toString();
}

class UpdateService {
  UpdateService._();

  /// Kanal testnet: rilis GitHub repo ini (publik). Tag tetap
  /// `update-testnet` adalah rilis penunjuk yang hanya berisi
  /// update.json terbaru; URL unduh APK di dalamnya menunjuk ke
  /// rilis berversi `build-testnet-<run>`. Diterbitkan + dipangkas
  /// (sisa 2 terbaru) oleh workflow kulit testnet.
  static const String _urlUpdateTestnet =
      'https://github.com/Nusanian/nux-wallet'
      '/releases/download/update-testnet/update.json';

  /// Kanal mainnet: VPS sendiri sampai NUX mengumumkan rilis
  /// publik (keputusan 2 Nov 2026). Nilainya TIDAK di-commit:
  /// workflow kulit mainnet mengganti placeholder ini dari secret
  /// `UPDATE_MAINNET_URL` hanya di dalam runner saat build —
  /// pola yang sama dengan token LSP mainnet. Selama placeholder
  /// belum terganti, kanal mainnet nonaktif dan pemeriksaan
  /// menghasilkan [UpdateCheckStatus.disabled].
  static const String _urlUpdateMainnet = 'ISI_URL_UPDATE_MAINNET';

  static bool get _kanalAktif =>
      AppConfig.isTestnet || !_urlUpdateMainnet.startsWith('ISI_URL_UPDATE');

  static String get _urlUpdateJson =>
      AppConfig.isTestnet ? _urlUpdateTestnet : _urlUpdateMainnet;

  static const MethodChannel _saluran = MethodChannel('nux_wallet/ota');

  /// Cek pembaruan. Tidak pernah melempar: kegagalan apa pun
  /// menjadi [UpdateCheckStatus.failed].
  static Future<UpdateCheckResult> cek() async {
    if (!_kanalAktif) {
      return const UpdateCheckResult(UpdateCheckStatus.disabled);
    }
    try {
      final respons = await http
          .get(Uri.parse(_urlUpdateJson))
          .timeout(const Duration(seconds: 15));
      if (respons.statusCode != 200) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }
      final mentah = UpdateInfo.dariBytes(respons.bodyBytes);
      if (mentah == null) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }

      // ABI aplikasi yang terpasang (bukan kemampuan perangkat):
      // HP 32-bit mengunduh OTA v7a, HP 64-bit arm64, emulator
      // x86_64. Gagal membaca ABI → fallback arm64 (perilaku
      // nusan-catcher), bukan menggagalkan pemeriksaan.
      var abi = 'arm64-v8a';
      try {
        final dibaca = await _saluran.invokeMethod<String>('abiTerpasang');
        if (dibaca != null && dibaca.isNotEmpty) abi = dibaca;
      } catch (_) {
        // Fallback di atas.
      }
      final info = mentah.untukAbi(abi);

      final jalurApk = await _saluran.invokeMethod<String>('jalurApk');
      if (jalurApk == null || jalurApk.isEmpty) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }
      if (!await File(jalurApk).exists()) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }

      final hashTerpasang = await compute(_sha256Berkas, jalurApk);
      if (perluPembaruan(
        hashTerpasang: hashTerpasang,
        hashRilis: info.sha256,
      )) {
        return UpdateCheckResult(UpdateCheckStatus.updateAvailable, info);
      }
      return const UpdateCheckResult(UpdateCheckStatus.upToDate);
    } catch (_) {
      // Jaringan mati, JSON rusak, native belum siap — diam saja.
      return const UpdateCheckResult(UpdateCheckStatus.failed);
    }
  }

  /// Unduh APK [info] ke direktori cache, verifikasi hash-nya,
  /// lalu buka installer sistem lewat sisi native.
  ///
  /// [onProgres] dipanggil dengan nilai 0..1 selama mengunduh.
  /// Kembalikan true bila installer berhasil dibuka, false bila
  /// unduhan, verifikasi, atau pemasangan gagal.
  static Future<bool> unduhDanPasang(
    UpdateInfo info, {
    void Function(double progres)? onProgres,
  }) async {
    final klien = http.Client();
    try {
      final permintaan = http.Request('GET', Uri.parse(info.urlUnduh));
      final respons = await klien
          .send(permintaan)
          .timeout(const Duration(seconds: 30));
      if (respons.statusCode != 200) return false;
      final total = respons.contentLength ?? -1;
      var diterima = 0;

      final dir = await getTemporaryDirectory();
      final berkas = File('${dir.path}/elnux-update.apk');
      final penulis = berkas.openWrite();
      try {
        await for (final potong in respons.stream) {
          penulis.add(potong);
          diterima += potong.length;
          if (total > 0) onProgres?.call(diterima / total);
        }
      } finally {
        await penulis.close();
      }
      onProgres?.call(1.0);

      // Verifikasi SHA-256 berkas hasil unduhan SEBELUM memasang:
      // unduhan rusak/tidak lengkap harus gagal secara TERLIHAT di
      // dialog (Coba Lagi), bukan sesudahnya secara diam-diam di
      // installer (pelajaran lapangan nusan-catcher v31→v32).
      final hashUnduhan = await compute(_sha256Berkas, berkas.path);
      if (perluPembaruan(hashTerpasang: hashUnduhan, hashRilis: info.sha256)) {
        return false;
      }

      final dibuka = await _saluran.invokeMethod<bool>('pasangApk', {
        'jalur': berkas.path,
      });
      return dibuka == true;
    } catch (_) {
      return false;
    } finally {
      klien.close();
    }
  }
}
