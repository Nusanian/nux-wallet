/// Pembaca info dasar invoice BOLT11 (payment hash + masa berlaku).
///
/// ELNUX perlu dua hal dari invoice yang dibuatnya sendiri:
///
/// 1. **payment hash** — untuk mencocokkan invoice tersimpan dengan
///    catatan pembayaran di node (PaymentKind_Bolt11/Jit menyimpan
///    hash yang sama), supaya layar detail riwayat bisa menampilkan
///    kembali invoice yang masih pending.
/// 2. **waktu kedaluwarsa** — dihitung dari timestamp invoice +
///    tag 'x' (default 3600 detik bila tag tidak ada), supaya
///    aplikasi tahu invoice masih layak ditampilkan atau sudah mati.
///
/// Ini BUKAN decoder lengkap dan TIDAK memverifikasi tanda tangan
/// invoice: fungsinya hanya membaca dua field di atas dari invoice
/// yang dibuat node sendiri. Checksum bech32 tetap diverifikasi —
/// invoice yang checksum-nya rusak dianggap tidak valid dan fungsi
/// mengembalikan null (fail-open: pemanggil cukup tidak menautkan
/// invoice tersimpan, tanpa error ke user).
library;

/// Info hasil baca invoice: payment hash (hex 64 karakter) dan
/// waktu kedaluwarsa menurut jam invoice itu sendiri.
class Bolt11Info {
  final String paymentHashHex;
  final DateTime expiresAt;

  const Bolt11Info({required this.paymentHashHex, required this.expiresAt});

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}

const _bech32Charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

/// Baca payment hash + kedaluwarsa dari [invoice].
///
/// Mengembalikan null bila invoice bukan bech32 yang valid, checksum
/// salah, atau field payment hash ('p') tidak ditemukan/utuh.
Bolt11Info? parseBolt11Info(String invoice) {
  final s = invoice.trim().toLowerCase();
  if (!s.startsWith('ln')) return null;
  final sep = s.lastIndexOf('1');
  if (sep < 1) return null;
  final dataPart = s.substring(sep + 1);
  if (dataPart.length < 6) return null;

  // Decode bech32: setiap karakter → nilai 5-bit.
  final words = <int>[];
  for (var i = 0; i < dataPart.length; i++) {
    final v = _bech32Charset.indexOf(dataPart[i]);
    if (v < 0) return null;
    words.add(v);
  }
  if (!_bech32ChecksumValid(s.substring(0, sep), words)) return null;

  // Buang 6 kata checksum di ujung.
  final payload = words.sublist(0, words.length - 6);
  // 7 kata pertama = timestamp (35 bit).
  if (payload.length < 7) return null;
  var timestamp = 0;
  for (var i = 0; i < 7; i++) {
    timestamp = (timestamp << 5) | payload[i];
  }

  String? paymentHashHex;
  int? expirySecs;
  var i = 7;
  while (i + 3 <= payload.length) {
    final type = payload[i];
    final len = (payload[i + 1] << 5) | payload[i + 2];
    i += 3;
    if (i + len > payload.length) break; // tag terpotong — berhenti
    final data = payload.sublist(i, i + len);
    i += len;
    if (type == 1 && paymentHashHex == null) {
      // 'p' = payment_hash: 52 kata 5-bit → 32 byte.
      final bytes = _convertBits(data, 5, 8, pad: false);
      if (bytes != null && bytes.length == 32) {
        paymentHashHex =
            bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      }
    } else if (type == 6 && expirySecs == null) {
      // 'x' = expiry: bilangan bulat basis-32 big-endian.
      var v = 0;
      for (final w in data) {
        v = (v << 5) | w;
      }
      expirySecs = v;
    }
  }
  if (paymentHashHex == null) return null;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (timestamp + (expirySecs ?? 3600)) * 1000,
      isUtc: true);
  return Bolt11Info(paymentHashHex: paymentHashHex, expiresAt: expiresAt);
}

/// Verifikasi checksum bech32 (polymod harus 1).
bool _bech32ChecksumValid(String hrp, List<int> dataWithChecksum) {
  var chk = 1;
  void polymodStep(int v) {
    final top = chk >> 25;
    chk = ((chk & 0x1ffffff) << 5) ^ v;
    const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    for (var i = 0; i < 5; i++) {
      if ((top >> i) & 1 == 1) chk ^= gen[i];
    }
  }

  // Expand HRP: nilai tinggi, 0, nilai rendah.
  for (var i = 0; i < hrp.length; i++) {
    polymodStep(hrp.codeUnitAt(i) >> 5);
  }
  polymodStep(0);
  for (var i = 0; i < hrp.length; i++) {
    polymodStep(hrp.codeUnitAt(i) & 31);
  }
  for (final v in dataWithChecksum) {
    polymodStep(v);
  }
  return chk == 1;
}

/// Konversi kelompok bit (pola convertbits BIP-173).
///
/// Dengan pad=false, sisa bit di ujung harus nol dan tidak boleh
/// membentuk byte utuh tambahan; bila tidak, hasil dianggap rusak
/// dan null dikembalikan.
List<int>? _convertBits(List<int> data, int fromBits, int toBits,
    {required bool pad}) {
  var acc = 0;
  var bits = 0;
  final out = <int>[];
  final maxv = (1 << toBits) - 1;
  for (final v in data) {
    if (v < 0 || (v >> fromBits) != 0) return null;
    acc = (acc << fromBits) | v;
    bits += fromBits;
    while (bits >= toBits) {
      bits -= toBits;
      out.add((acc >> bits) & maxv);
    }
  }
  if (pad) {
    if (bits > 0) out.add((acc << (toBits - bits)) & maxv);
  } else {
    if (bits >= fromBits) return null;
    if ((acc << (toBits - bits)) & maxv != 0) return null;
  }
  return out;
}
