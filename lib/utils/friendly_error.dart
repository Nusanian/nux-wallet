import 'package:flutter/foundation.dart';

/// Ubah error teknis menjadi pesan ringkas yang layak tampil ke pengguna.
///
/// Prinsip: UI TIDAK PERNAH menampilkan error mentah — error mentah memuat
/// detail infrastruktur (hostname server, alamat IP, nama exception, stack)
/// yang tidak berguna bagi pengguna dan tidak pantas terekspos. Detail asli
/// hanya ditulis ke log developer lewat [debugPrint].
///
/// [fallback] dipakai bila error tidak cocok pola mana pun — isi dengan
/// pesan ringkas sesuai konteks layar pemanggil.
String friendlyError(Object error, {required String fallback}) {
  debugPrint('[error-teknis] $error');
  final s = error.toString().toLowerCase();

  // Koneksi: offline, timeout, DNS, server tidak terjangkau.
  if (s.contains('socket') ||
      s.contains('connection') ||
      s.contains('timeout') ||
      s.contains('timed out') ||
      s.contains('failed host lookup') ||
      s.contains('unreachable') ||
      s.contains('handshake')) {
    return 'Tidak dapat terhubung. Periksa koneksi internet Anda, '
        'lalu coba lagi.';
  }

  // Saldo / dana tidak cukup.
  if (s.contains('insufficient') || s.contains('balance')) {
    return 'Saldo tidak mencukupi.';
  }

  // Invoice tidak valid / kedaluwarsa.
  if (s.contains('invoice') &&
      (s.contains('invalid') || s.contains('expired') || s.contains('parse'))) {
    return 'Invoice tidak valid atau sudah kedaluwarsa.';
  }

  // Data dompet lokal bermasalah (seed/storage) — jangan tampilkan detail.
  if (s.contains('seed') || s.contains('korup') || s.contains('storage')) {
    return 'Data dompet bermasalah. Hubungi operator untuk bantuan.';
  }

  return fallback;
}
