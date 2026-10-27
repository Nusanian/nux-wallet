// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appLanguage => 'Bahasa';

  @override
  String get chooseLanguage => 'Pilih Bahasa';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSubtitle => 'Gelap atau terang, sesuai selera';

  @override
  String get changeThemeTooltip => 'Ganti tema';

  @override
  String get greetingMorning => 'Selamat pagi';

  @override
  String get greetingAfternoon => 'Selamat siang';

  @override
  String get greetingEvening => 'Selamat sore';

  @override
  String get greetingNight => 'Selamat malam';

  @override
  String get bootConnecting => 'Menghubungkan ke LSP…';

  @override
  String get bootFailedTitle => 'Gagal menghubungkan node';

  @override
  String get bootFailedRetry => 'Coba lagi';

  @override
  String get bootGenericError => 'Terjadi kendala saat memulai dompet.';

  @override
  String get lspNodeIdMissing =>
      'lspNodeId belum diisi di lib/config.dart — minta node id LSP ke operator.';

  @override
  String seedCorrupt(int length, String path) {
    return 'File seed korup (panjang $length, harus 64). Hapus $path untuk generate ulang (DANA LAMA HILANG).';
  }

  @override
  String get exitTitle => 'Keluar dari ELNUX?';

  @override
  String get exitBody =>
      'Aplikasi akan ditutup. Selama aplikasi tertutup, dompet tidak dapat menerima pembayaran.';

  @override
  String get cancel => 'Batal';

  @override
  String get exitConfirm => 'Keluar';

  @override
  String get totalBalance => 'Total Saldo';

  @override
  String get networkTestnet => 'Lightning Network • Testnet';

  @override
  String get networkMainnet => 'Lightning Network • Mainnet';

  @override
  String get lightningActive => 'Lightning aktif — siap terima instan';

  @override
  String get lightningConnecting => 'Menghubungkan Lightning…';

  @override
  String get legacyStrip =>
      'Dompet ini belum punya frasa backup. Buka tab Profil untuk membuat dompet baru dengan frasa sebelum menerima dana.';

  @override
  String get send => 'Kirim';

  @override
  String get receive => 'Terima';

  @override
  String get buy => 'Beli';

  @override
  String get swap => 'Tukar';

  @override
  String get activity => 'Aktivitas';

  @override
  String get seeAll => 'Lihat semua';

  @override
  String get noActivity => 'Belum ada aktivitas';

  @override
  String get market => 'Pasar';

  @override
  String get marketSoon => 'Info pasar NUX — segera hadir.';

  @override
  String get home => 'Beranda';

  @override
  String get history => 'Riwayat';

  @override
  String get profile => 'Profil';

  @override
  String get received => 'Diterima';

  @override
  String get sent => 'Terkirim';

  @override
  String get pending => 'Menunggu';

  @override
  String get failed => 'Gagal';

  @override
  String get noTransactions =>
      'Belum ada transaksi. Pembayaran masuk dan keluar akan tampil di sini.';

  @override
  String get backupWallet => 'Backup Wallet';

  @override
  String get legacyWalletSubtitle =>
      'Dompet ini dibuat sebelum fitur frasa backup ada';

  @override
  String get backupSubtitle => 'Lihat frasa backup dompet Anda';

  @override
  String get noPhraseTitle => 'Dompet ini tidak punya frasa backup';

  @override
  String get noPhraseBody =>
      'Dompet ini dibuat oleh versi aplikasi sebelumnya yang menyimpan kunci tanpa frasa. Bila HP hilang atau rusak, dana di dompet ini tidak bisa dipulihkan.\n\nBila dompet ini masih KOSONG (belum pernah menerima dana), buat dompet baru yang dilengkapi frasa backup sekarang:';

  @override
  String get createNewWalletTitle => 'Buat dompet baru?';

  @override
  String get deleteOldWalletBody =>
      'Dompet lama akan DIHAPUS PERMANEN beserta seluruh datanya. Lanjutkan HANYA bila dompet lama masih kosong — dana apa pun di dalamnya hilang selamanya.';

  @override
  String get deleteAndCreate => 'Hapus & buat baru';

  @override
  String get createNewWalletButton => 'Buat dompet baru dengan frasa';

  @override
  String get networkTestnetLabel => 'Jaringan: Nusacoin Testnet';

  @override
  String get networkMainnetLabel => 'Jaringan: Nusacoin Mainnet';

  @override
  String get backupWarning =>
      'Tulis kata-kata ini di kertas dan simpan di tempat aman. Siapa pun yang punya kata-kata ini bisa mengambil danamu.';

  @override
  String get showBackupWords => 'Tampilkan Kata Backup';

  @override
  String get backupCopied => 'Kata backup disalin';

  @override
  String get copy => 'Salin';

  @override
  String get backupConfirmed =>
      'Saya sudah menulis kata-kata ini di tempat aman';

  @override
  String get done => 'Selesai';

  @override
  String get invalidAmount => 'Masukkan nominal yang valid';

  @override
  String receiveInvoiceDesc(String amount) {
    return 'Terima $amount nusan';
  }

  @override
  String get createInvoiceFailed => 'Gagal membuat invoice. Coba lagi.';

  @override
  String get receiveTitle => 'Terima NUX';

  @override
  String get jitInfo =>
      'Invoice Lightning dengan channel instan (JIT). Tidak perlu tunggu konfirmasi block.';

  @override
  String get amountLabel => 'Nominal (nusan)';

  @override
  String get createInvoice => 'Buat Invoice';

  @override
  String get paymentReceived => 'Pembayaran Diterima';

  @override
  String receivedAmount(String amount) {
    return '+$amount nusan';
  }

  @override
  String get fundsArrived => 'Dana sudah masuk ke channel Lightning kamu.';

  @override
  String get invoiceTitle => 'Invoice Lightning';

  @override
  String get invoiceCopied => 'Invoice disalin';

  @override
  String get shareInvoiceHint =>
      'Bagikan invoice ini ke pengirim. Channel akan dibuka otomatis saat pembayaran diterima.';

  @override
  String get pasteInvoiceFirst => 'Tempel invoice dulu';

  @override
  String get invalidInvoice => 'Ini bukan invoice Lightning yang valid';

  @override
  String get payFailed => 'Pembayaran gagal. Coba lagi.';

  @override
  String get sendTitle => 'Kirim NUX';

  @override
  String get sendInfo =>
      'Tempel atau scan invoice Lightning dari penerima. Pembayaran instan via channel.';

  @override
  String get paste => 'Tempel';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get pay => 'Bayar';

  @override
  String get paymentSuccess => 'Pembayaran Berhasil!';

  @override
  String get scanTitle => 'Scan QR Invoice';

  @override
  String get cameraDenied =>
      'Izin kamera ditolak. Aktifkan izin kamera untuk ELNUX di Pengaturan HP, lalu coba lagi.';

  @override
  String get cameraUnavailable => 'Kamera tidak dapat dibuka di perangkat ini.';

  @override
  String get pointCamera => 'Arahkan kamera ke QR invoice';

  @override
  String get errorConnection =>
      'Tidak dapat terhubung. Periksa koneksi internet Anda, lalu coba lagi.';

  @override
  String get errorBalance => 'Saldo tidak mencukupi.';

  @override
  String get errorInvoice => 'Invoice tidak valid atau sudah kedaluwarsa.';

  @override
  String get errorWalletData =>
      'Data dompet bermasalah. Hubungi operator untuk bantuan.';
}
