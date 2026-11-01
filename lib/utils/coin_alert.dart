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

  /// Cap waktu perayaan terakhir. Satu penerimaan bisa terdeteksi
  /// dua pemicu hampir bersamaan — pengawas event di layar Terima
  /// (jajak 2 detik) dan polling dashboard (jajak 5 detik) — dan
  /// tidak boleh dirayakan dua kali; perayaan yang datang kurang
  /// dari 8 detik sesudah yang sebelumnya dianggap duplikat.
  static DateTime? _lastPlayAt;

  static Future<void> play() async {
    final now = DateTime.now();
    final last = _lastPlayAt;
    if (last != null && now.difference(last) < const Duration(seconds: 8)) {
      return;
    }
    _lastPlayAt = now;
    // Getar dipicu PERTAMA: polanya mulai tanpa jeda, jadi getar
    // harus berangkat bersamaan dengan munculnya tanda pembayaran
    // masuk — bukan sesudah bunyi selesai diputar. Dahulu getar
    // menunggu putaran bunyi tuntas dulu, sehingga terasa terlambat
    // atau seperti tidak bekerja.
    await vibrateSuccess();
    try {
      if (!_configured) {
        await _player.setPlayerMode(PlayerMode.lowLatency);
        _configured = true;
      }
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/cling.wav'));
    } catch (_) {
      // Audio gagal tidak masalah — getar sudah terpicu di atas.
    }
  }

  /// Getar sukses — penanda fisik bahwa sebuah pembayaran
  /// BENAR-BENAR berhasil (dipakai peringatan koin masuk maupun
  /// layar Kirim saat hasil akhir pembayaran keluar sukses).
  /// Pola seperti ditentukan (1 Nov 2026), format pola
  /// [tunggu, getar, jeda, getar]: [0, 1000, 500, 1000] ms —
  /// getar 1 detik, jeda 500 ms, getar 1 detik, selesai.
  /// Panggilan getar ditunggu (await) sampai diterima platform:
  /// tanpa itu panggilan melayang bisa kalah balapan dengan
  /// perpindahan layar atau aplikasi yang masuk latar.
  /// Kegagalan ditelan diam-diam.
  static Future<void> vibrateSuccess() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 1000, 500, 1000]);
      }
    } catch (_) {
      // Tanpa vibrator pun tidak masalah.
    }
  }
}
