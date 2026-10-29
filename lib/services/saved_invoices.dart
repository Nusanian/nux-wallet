import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Invoice JIT yang dibuat aplikasi ini dan disimpan di HP.
///
/// Latar belakang: string invoice dari node LDK hanya hidup di
/// ingatan layar Terima dan catatan pembayaran node TIDAK menyimpan
/// string-nya (hanya hash, nominal, status). Tanpa simpanan lokal
/// ini, user yang aplikasinya tertutup tidak bisa melihat atau
/// menyalin kembali invoice pending-nya — padahal baris Pending-nya
/// tetap muncul di Riwayat. Karena itu setiap invoice yang dibuat
/// disimpan di sini lengkap dengan hash-nya, supaya layar detail
/// riwayat bisa menautkannya ke catatan pembayaran node.
class SavedInvoice {
  /// String invoice BOLT11 utuh (untuk QR + Salin).
  final String invoice;

  /// Payment hash invoice (hex 64 karakter) — kunci tautan ke
  /// PaymentKind_Bolt11/Bolt11Jit.hash di catatan node.
  final String paymentHashHex;

  final BigInt amountMsat;
  final DateTime createdAt;

  /// Kedaluwarsa menurut invoice itu sendiri (timestamp + tag 'x').
  final DateTime expiresAt;

  const SavedInvoice({
    required this.invoice,
    required this.paymentHashHex,
    required this.amountMsat,
    required this.createdAt,
    required this.expiresAt,
  });

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  Map<String, Object?> toJson() => {
        'invoice': invoice,
        'payment_hash': paymentHashHex,
        'amount_msat': amountMsat.toString(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  /// Parse satu entri; null bila ada field yang hilang/salah bentuk
  /// (entri rusak dibuang, bukan menggagalkan seluruh daftar).
  static SavedInvoice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final invoice = raw['invoice'];
    final hash = raw['payment_hash'];
    final amount = raw['amount_msat'];
    final created = raw['created_at'];
    final expires = raw['expires_at'];
    if (invoice is! String || invoice.isEmpty) return null;
    if (hash is! String || hash.length != 64) return null;
    if (amount is! String) return null;
    final amountMsat = BigInt.tryParse(amount);
    if (amountMsat == null) return null;
    if (created is! int || expires is! int) return null;
    return SavedInvoice(
      invoice: invoice,
      paymentHashHex: hash,
      amountMsat: amountMsat,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires),
    );
  }
}

/// Penyimpanan daftar [SavedInvoice] di SharedPreferences.
///
/// Pola sama seperti LspProfileStore: semua kegagalan baca dianggap
/// "tidak ada simpanan" (fail-open), kegagalan tulis ditelan — fitur
/// ini tambahan kenyamanan, tidak boleh menggagalkan pembuatan
/// invoice atau pembayaran.
class SavedInvoiceStore {
  static const String storageKey = 'saved_jit_invoices';

  /// Batas simpanan: invoice lama terbuang dari yang paling lama.
  /// 20 cukup untuk pola pakai normal (invoice berlaku 1 jam) dan
  /// menjaga ukuran simpanan tetap kecil.
  static const int maxKeep = 20;

  /// Muat seluruh simpanan, terbaru di depan. Entri rusak dibuang.
  ///
  /// Daftar hasil WAJIB bisa dimutasi (bukan const): save() dan
  /// removeByHash() memutasi daftar dari load() sebelum menulis
  /// balik — daftar const akan melempar UnsupportedOperation yang
  /// tertelan diam-diam oleh tangkapan fail-open di save().
  Future<List<SavedInvoice>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return <SavedInvoice>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SavedInvoice>[];
      final out = <SavedInvoice>[];
      for (final e in decoded) {
        final parsed = SavedInvoice.fromJson(e);
        if (parsed != null) out.add(parsed);
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (_) {
      return <SavedInvoice>[];
    }
  }

  /// Simpan invoice baru (atau perbarui yang hash-nya sama), lalu
  /// potong daftar menjadi [maxKeep] entri terbaru.
  Future<void> save(SavedInvoice entry) async {
    try {
      final list = await load();
      list.removeWhere((e) => e.paymentHashHex == entry.paymentHashHex);
      list.insert(0, entry);
      final trimmed = list.take(maxKeep).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          storageKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Gagal simpan = invoice tidak bisa dilihat kembali, tetapi
      // pembuatan invoice barusan tetap sah. Jangan ganggu user.
    }
  }

  /// Cari simpanan berdasarkan payment hash (hex); null bila tidak
  /// ada (mis. invoice dibuat sebelum fitur ini ada).
  Future<SavedInvoice?> findByHash(String paymentHashHex) async {
    final list = await load();
    for (final e in list) {
      if (e.paymentHashHex == paymentHashHex) return e;
    }
    return null;
  }

  /// Invoice tersimpan terakhir yang belum kedaluwarsa — dipakai
  /// layar Terima untuk memulihkan invoice pending saat aplikasi
  /// dibuka lagi setelah tertutup.
  Future<SavedInvoice?> latestUnexpired({DateTime? now}) async {
    final ref = now ?? DateTime.now();
    final list = await load();
    for (final e in list) {
      if (!e.isExpiredAt(ref)) return e;
    }
    return null;
  }

  /// Hapus simpanan berdasarkan hash (mis. setelah lunas).
  Future<void> removeByHash(String paymentHashHex) async {
    try {
      final list = await load();
      list.removeWhere((e) => e.paymentHashHex == paymentHashHex);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          storageKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Abaikan — entri basi akan tertutup oleh batas maxKeep.
    }
  }
}
