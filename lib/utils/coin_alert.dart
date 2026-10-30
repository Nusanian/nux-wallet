import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Peringatan "koin masuk": bunyi cling singkat nan nyaring + getar.
///
/// Dipanggil saat pembayaran masuk BARU terdeteksi berhasil. Semua
/// kegagalan (perangkat tanpa vibrator, audio sibuk, izin, dll.)
/// ditelan diam-diam — peringatan tidak boleh mengganggu alur dompet.
class CoinAlert {
  static final AudioPlayer _player = AudioPlayer();
  static bool _configured = false;

  static Future<void> play() async {
    try {
      if (!_configured) {
        await _player.setPlayerMode(PlayerMode.lowLatency);
        _configured = true;
      }
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/cling.wav'));
    } catch (_) {
      // Audio gagal tidak masalah — getar tetap dicoba.
    }
    await vibrateSuccess();
  }

  /// Getar sukses — penanda fisik bahwa sebuah pembayaran
  /// BENAR-BENAR berhasil (dipakai peringatan koin masuk maupun
  /// layar Kirim saat hasil akhir pembayaran keluar sukses).
  /// Pola persis seperti ditentukan NUX (31 Okt 2026):
  /// [500, 500, 500, 500] ms (tunggu, getar, jeda, getar).
  /// Kegagalan ditelan diam-diam.
  static Future<void> vibrateSuccess() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [500, 500, 500, 500]);
      }
    } catch (_) {
      // Tanpa vibrator pun tidak masalah.
    }
  }
}
