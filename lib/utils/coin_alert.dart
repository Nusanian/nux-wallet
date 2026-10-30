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

  /// Getar sukses tiga denyut dengan intensitas menanjak — penanda
  /// fisik bahwa sebuah pembayaran BENAR-BENAR berhasil (dipakai
  /// peringatan koin masuk maupun layar Kirim saat hasil akhir
  /// pembayaran keluar sukses). Kegagalan ditelan diam-diam.
  static Future<void> vibrateSuccess() async {
    try {
      if (await Vibration.hasVibrator()) {
        // Pola tiga denyut: pendek, sedang, lalu terpanjang
        // (seperti denting koin) dengan intensitas menanjak.
        Vibration.vibrate(
          pattern: [0, 90, 60, 140, 60, 190],
          intensities: [0, 180, 0, 220, 0, 255],
        );
      }
    } catch (_) {
      // Tanpa vibrator pun tidak masalah.
    }
  }
}
