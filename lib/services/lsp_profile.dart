import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Profil koneksi LSP: satu paket endpoint yang dipakai node untuk
/// terhubung ke LSP dan ke data chain.
///
/// Satu profil = satu operator, bukan satu field lepas, karena tiga
/// nilai ini harus berubah bersamaan: alamat P2P LSP, node_id-nya,
/// dan server Electrum-nya. Kalau hanya alamat yang diganti tanpa
/// node_id, node akan bicara ke host yang salah dengan identitas
/// yang salah.
///
/// PERSIAPAN SAJA (keputusan NUX, 29 Okt 2026): layar konfigurasi
/// belum dibuat — saat ini belum perlu, karena baru ada satu LSP.
/// File ini menyiapkan strukturnya supaya layar nanti (daftar LSP
/// resmi + custom di Advanced) tinggal menyimpan profil lewat
/// [LspProfileStore.save] dan me-restart node; alur boot di main.dart
/// sudah membaca profil tersimpan, jadi tidak perlu diubah lagi.
///
/// Dua hal yang WAJIB dijelaskan di layar nanti (bukan di sini,
/// karena belum ada UI-nya):
/// 1. Ganti profil TIDAK memindahkan dana. Channel lama terikat ke
///    LSP lama; dananya tetap di situ sampai dipakai atau ditutup.
///    Profil baru hanya berlaku untuk channel baru dan penerimaan
///    berikutnya.
/// 2. Ganti profil butuh mulai ulang node. Seed dan storage dompet
///    tidak berubah — yang berubah hanya operator yang dihubungi.
class LspProfile {
  /// Pengenal stabil profil ini ('official' untuk bawaan build).
  /// Layar daftar nanti memakai id ini untuk menandai yang aktif.
  final String id;

  /// Nama tampil di daftar nanti (mis. "LSP Resmi Nusacoin").
  final String name;

  /// Alamat P2P node LSP, format "host:port".
  final String lspAddress;

  /// Public key (node id) node LSP, 66 karakter hex diawali 02/03.
  final String lspNodeId;

  /// Token akses LSPS2 dari operator. Boleh kosong (sebagian LSP
  /// tidak memakainya). Ini token operator, BUKAN kunci dompet user
  /// — tapi tetap jangan pernah ditampilkan penuh atau di-log.
  final String lspToken;

  /// URL server Electrum (electrs) untuk data chain,
  /// format "tcp://host:port" atau "ssl://host:port".
  final String electrumUrl;

  /// Jaringan profil ini. Harus sama dengan build yang menjalankan
  /// (AppConfig.isTestnet) — profil jaringan lain tidak pernah
  /// dipakai, lihat [LspProfileStore.load].
  final bool isTestnet;

  const LspProfile({
    required this.id,
    required this.name,
    required this.lspAddress,
    required this.lspNodeId,
    required this.lspToken,
    required this.electrumUrl,
    required this.isTestnet,
  });

  /// Profil bawaan build ini: nilai dari AppConfig per-branch
  /// (testnet/mainnet), tanpa menulis apa pun ke penyimpanan.
  /// Tidak ditulis supaya update build berikutnya (termasuk token
  /// mainnet dari CI) langsung berlaku, tidak tertahan nilai lama.
  static LspProfile get official => LspProfile(
        id: 'official',
        name: 'LSP Resmi Nusacoin',
        lspAddress: AppConfig.lspAddress,
        lspNodeId: AppConfig.lspNodeId,
        lspToken: AppConfig.lspToken,
        electrumUrl: AppConfig.electrumUrl,
        isTestnet: AppConfig.isTestnet,
      );

  /// true bila profil ini layak dipakai untuk boot node.
  /// Token sengaja tidak ikut: token kosong tetap sah.
  bool get isValid =>
      _isValidHostPort(lspAddress) &&
      _isValidNodeId(lspNodeId) &&
      _isValidElectrumUrl(electrumUrl);

  /// Sama dengan [isValid], dengan nama yang dipakai boot node
  /// (dulu AppConfig.lspConfigured) supaya maksudnya jelas di sana.
  bool get isConfigured => isValid;

  static bool _isValidHostPort(String value) {
    final text = value.trim();
    final sep = text.lastIndexOf(':');
    if (sep <= 0 || sep == text.length - 1) return false;
    final host = text.substring(0, sep);
    final port = int.tryParse(text.substring(sep + 1));
    if (host.contains(' ') || host.contains('://')) return false;
    return port != null && port >= 1 && port <= 65535;
  }

  static bool _isValidNodeId(String value) {
    final text = value.trim();
    return RegExp(r'^(02|03)[0-9a-fA-F]{64}$').hasMatch(text);
  }

  static bool _isValidElectrumUrl(String value) {
    final text = value.trim();
    if (!text.startsWith('tcp://') && !text.startsWith('ssl://')) {
      return false;
    }
    return _isValidHostPort(text.substring(text.indexOf('://') + 3));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lspAddress': lspAddress,
        'lspNodeId': lspNodeId,
        'lspToken': lspToken,
        'electrumUrl': electrumUrl,
        'isTestnet': isTestnet,
      };

  /// Kembalikan null bila JSON bukan profil yang sah (bentuk salah,
  /// field bukan string, atau nilai tidak lolos [isValid]). Pemanggil
  /// yang menerima null WAJIB jatuh kembali ke [official], jangan
  /// pernah boot dengan profil setengah jadi.
  static LspProfile? fromJson(dynamic json) {
    try {
      if (json is! Map<String, dynamic>) return null;
      final id = json['id'];
      final name = json['name'];
      final lspAddress = json['lspAddress'];
      final lspNodeId = json['lspNodeId'];
      final lspToken = json['lspToken'];
      final electrumUrl = json['electrumUrl'];
      final isTestnet = json['isTestnet'];
      if (id is! String ||
          name is! String ||
          lspAddress is! String ||
          lspNodeId is! String ||
          lspToken is! String ||
          electrumUrl is! String ||
          isTestnet is! bool) {
        return null;
      }
      final profile = LspProfile(
        id: id.trim(),
        name: name.trim(),
        lspAddress: lspAddress.trim(),
        lspNodeId: lspNodeId.trim(),
        lspToken: lspToken.trim(),
        electrumUrl: electrumUrl.trim(),
        isTestnet: isTestnet,
      );
      if (profile.id.isEmpty || profile.name.isEmpty) return null;
      return profile.isValid ? profile : null;
    } catch (_) {
      return null;
    }
  }
}

/// Penyimpanan profil pilihan user, pola yang sama dengan
/// LocaleController dan ThemeController: SharedPreferences, kunci
/// 'lsp_profile', gagal baca/tulis bukan fatal (jatuh ke official).
///
/// Yang disimpan HANYA profil pilihan user. Kalau tidak ada yang
/// tersimpan, [load] mengembalikan [LspProfile.official] tanpa
/// menulis — supaya nilai bawaan build selalu segar.
class LspProfileStore {
  static const _prefsKey = 'lsp_profile';

  /// Profil aktif: tersimpan bila sah DAN jaringannya sama dengan
  /// build ini, selain itu profil bawaan.
  ///
  /// Guard jaringan ini penting: seed dan storage dipisah per
  /// network, dan dompet mainnet tidak boleh diarahkan ke LSP
  /// testnet (atau sebaliknya) hanya karena profil lama tertinggal
  /// — misalnya setelah user pindah build testnet/mainnet yang
  /// menimpa paket yang sama. Profil jaringan lain dibuang diam-diam
  /// (tidak dimigrasi), bukan dipakai.
  static Future<LspProfile> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return LspProfile.official;
      final profile = LspProfile.fromJson(jsonDecode(raw));
      if (profile == null || profile.isTestnet != AppConfig.isTestnet) {
        return LspProfile.official;
      }
      return profile;
    } catch (_) {
      return LspProfile.official;
    }
  }

  /// Simpan profil pilihan user. Lempar [ArgumentError] bila profil
  /// tidak valid atau jaringannya beda dengan build ini — layar
  /// nanti menangkap ini untuk menampilkan pesan kesalahan, bukan
  /// menyimpan diam-diam lalu gagal boot di kemudian hari.
  /// Gagal tulis SharedPreferences sendiri ditelan (pola yang sama
  /// dengan controller lain): pilihan berlaku sesi ini lewat profil
  /// yang dipegang pemanggil, dan boot berikutnya jatuh ke official.
  static Future<void> save(LspProfile profile) async {
    // Normalisasi dulu: nilai ber-spasi di ujung (tempelan user)
    // tidak boleh lolos ke penyimpanan lalu ke init node.
    final normalized = LspProfile(
      id: profile.id.trim(),
      name: profile.name.trim(),
      lspAddress: profile.lspAddress.trim(),
      lspNodeId: profile.lspNodeId.trim(),
      lspToken: profile.lspToken.trim(),
      electrumUrl: profile.electrumUrl.trim(),
      isTestnet: profile.isTestnet,
    );
    if (!normalized.isValid) {
      throw ArgumentError(
          'Profil LSP tidak valid: ${normalized.id} (${normalized.name})');
    }
    if (normalized.isTestnet != AppConfig.isTestnet) {
      throw ArgumentError(
          'Profil LSP jaringannya beda dengan build ini.');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(normalized.toJson()));
    } catch (_) {
      // Gagal simpan bukan fatal — lihat keterangan di atas.
    }
  }

  /// Hapus pilihan user; boot berikutnya kembali ke profil bawaan.
  /// Dipakai layar nanti untuk tombol "Kembali ke LSP resmi".
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Gagal hapus bukan fatal; load berikutnya tetap memvalidasi.
    }
  }
}
