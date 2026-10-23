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
    try {
      if (await Vibration.hasVibrator()) {
        // Pola dua denyut: pendek lalu lebih panjang (seperti
        // denting koin) dengan intensitas menanjak.
        Vibration.vibrate(
          pattern: [0, 90, 60, 170],
          intensities: [0, 200, 0, 255],
        );
      }
    } catch (_) {
      // Tanpa vibrator pun tidak masalah.
    }
  }
}
