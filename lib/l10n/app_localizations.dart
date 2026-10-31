import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appLanguage.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get appLanguage;

  /// No description provided for @chooseLanguage.
  ///
  /// In id, this message translates to:
  /// **'Pilih Bahasa'**
  String get chooseLanguage;

  /// No description provided for @languageIndonesian.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeTitle.
  ///
  /// In id, this message translates to:
  /// **'Tema'**
  String get themeTitle;

  /// No description provided for @themeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Gelap atau terang, sesuai selera'**
  String get themeSubtitle;

  /// No description provided for @changeThemeTooltip.
  ///
  /// In id, this message translates to:
  /// **'Ganti tema'**
  String get changeThemeTooltip;

  /// No description provided for @greetingMorning.
  ///
  /// In id, this message translates to:
  /// **'Selamat pagi'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In id, this message translates to:
  /// **'Selamat siang'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In id, this message translates to:
  /// **'Selamat sore'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In id, this message translates to:
  /// **'Selamat malam'**
  String get greetingNight;

  /// No description provided for @bootConnecting.
  ///
  /// In id, this message translates to:
  /// **'Menghubungkan ke LSP…'**
  String get bootConnecting;

  /// No description provided for @splashTagline.
  ///
  /// In id, this message translates to:
  /// **'Uangmu, Kendalimu.'**
  String get splashTagline;

  /// No description provided for @bootFailedTitle.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghubungkan node'**
  String get bootFailedTitle;

  /// No description provided for @bootFailedRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get bootFailedRetry;

  /// No description provided for @bootGenericError.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kendala saat memulai dompet.'**
  String get bootGenericError;

  /// No description provided for @lspNodeIdMissing.
  ///
  /// In id, this message translates to:
  /// **'lspNodeId belum diisi di lib/config.dart — minta node id LSP ke operator.'**
  String get lspNodeIdMissing;

  /// No description provided for @seedCorrupt.
  ///
  /// In id, this message translates to:
  /// **'File seed korup (panjang {length}, harus 64). Hapus {path} untuk generate ulang (DANA LAMA HILANG).'**
  String seedCorrupt(int length, String path);

  /// No description provided for @exitTitle.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari ELNUX?'**
  String get exitTitle;

  /// No description provided for @exitBody.
  ///
  /// In id, this message translates to:
  /// **'Aplikasi akan ditutup. Selama aplikasi tertutup, dompet tidak dapat menerima pembayaran.'**
  String get exitBody;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @exitConfirm.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get exitConfirm;

  /// No description provided for @totalBalance.
  ///
  /// In id, this message translates to:
  /// **'Total Saldo'**
  String get totalBalance;

  /// No description provided for @networkTestnet.
  ///
  /// In id, this message translates to:
  /// **'Lightning Network • Testnet'**
  String get networkTestnet;

  /// No description provided for @networkMainnet.
  ///
  /// In id, this message translates to:
  /// **'Lightning Network • Mainnet'**
  String get networkMainnet;

  /// No description provided for @lightningActive.
  ///
  /// In id, this message translates to:
  /// **'Lightning aktif — siap terima instan'**
  String get lightningActive;

  /// No description provided for @lightningConnecting.
  ///
  /// In id, this message translates to:
  /// **'Menghubungkan Lightning…'**
  String get lightningConnecting;

  /// No description provided for @legacyStrip.
  ///
  /// In id, this message translates to:
  /// **'Dompet ini belum punya frasa backup. Buka tab Profil untuk membuat dompet baru dengan frasa sebelum menerima dana.'**
  String get legacyStrip;

  /// No description provided for @send.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In id, this message translates to:
  /// **'Terima'**
  String get receive;

  /// No description provided for @buy.
  ///
  /// In id, this message translates to:
  /// **'Beli'**
  String get buy;

  /// No description provided for @swap.
  ///
  /// In id, this message translates to:
  /// **'Tukar'**
  String get swap;

  /// No description provided for @activity.
  ///
  /// In id, this message translates to:
  /// **'Aktivitas'**
  String get activity;

  /// No description provided for @seeAll.
  ///
  /// In id, this message translates to:
  /// **'Lihat semua'**
  String get seeAll;

  /// No description provided for @noActivity.
  ///
  /// In id, this message translates to:
  /// **'Belum ada aktivitas'**
  String get noActivity;

  /// No description provided for @market.
  ///
  /// In id, this message translates to:
  /// **'Pasar'**
  String get market;

  /// No description provided for @marketSoon.
  ///
  /// In id, this message translates to:
  /// **'Info pasar NUX — segera hadir.'**
  String get marketSoon;

  /// No description provided for @home.
  ///
  /// In id, this message translates to:
  /// **'Beranda'**
  String get home;

  /// No description provided for @history.
  ///
  /// In id, this message translates to:
  /// **'Riwayat'**
  String get history;

  /// No description provided for @profile.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @received.
  ///
  /// In id, this message translates to:
  /// **'Diterima'**
  String get received;

  /// No description provided for @sent.
  ///
  /// In id, this message translates to:
  /// **'Terkirim'**
  String get sent;

  /// No description provided for @pending.
  ///
  /// In id, this message translates to:
  /// **'Menunggu'**
  String get pending;

  /// No description provided for @processing.
  ///
  /// In id, this message translates to:
  /// **'Sedang diproses'**
  String get processing;

  /// No description provided for @failed.
  ///
  /// In id, this message translates to:
  /// **'Gagal'**
  String get failed;

  /// No description provided for @noTransactions.
  ///
  /// In id, this message translates to:
  /// **'Belum ada transaksi. Pembayaran masuk dan keluar akan tampil di sini.'**
  String get noTransactions;

  /// No description provided for @txDetailTitle.
  ///
  /// In id, this message translates to:
  /// **'Detail Transaksi'**
  String get txDetailTitle;

  /// No description provided for @txType.
  ///
  /// In id, this message translates to:
  /// **'Jenis'**
  String get txType;

  /// No description provided for @txStatus.
  ///
  /// In id, this message translates to:
  /// **'Status'**
  String get txStatus;

  /// No description provided for @txTime.
  ///
  /// In id, this message translates to:
  /// **'Waktu'**
  String get txTime;

  /// No description provided for @txPaymentId.
  ///
  /// In id, this message translates to:
  /// **'ID Pembayaran'**
  String get txPaymentId;

  /// No description provided for @txPaymentHash.
  ///
  /// In id, this message translates to:
  /// **'Hash Pembayaran'**
  String get txPaymentHash;

  /// No description provided for @txSucceeded.
  ///
  /// In id, this message translates to:
  /// **'Berhasil'**
  String get txSucceeded;

  /// No description provided for @txExpiredBadge.
  ///
  /// In id, this message translates to:
  /// **'Kedaluwarsa'**
  String get txExpiredBadge;

  /// No description provided for @txInvoiceExpiredNote.
  ///
  /// In id, this message translates to:
  /// **'Invoice ini sudah kedaluwarsa dan tidak bisa dibayar lagi. Buat invoice baru untuk menerima pembayaran.'**
  String get txInvoiceExpiredNote;

  /// No description provided for @txInvoiceNotSavedNote.
  ///
  /// In id, this message translates to:
  /// **'Invoice ini dibuat sebelum fitur simpan invoice tersedia, jadi string invoice-nya tidak tersimpan di aplikasi dan tidak bisa ditampilkan kembali.'**
  String get txInvoiceNotSavedNote;

  /// No description provided for @txProcessingNote.
  ///
  /// In id, this message translates to:
  /// **'Uangmu aman dan sedang menunggu giliran tercatat di jaringan. Akan selesai sendiri.'**
  String get txProcessingNote;

  /// No description provided for @txJitNote.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran ini sekaligus membuatkan jalur penerimaan baru untukmu, jadi ada potongan biaya pembuatan 0,5%. Pembayaran berikutnya lewat jalur ini tidak dipotong lagi.'**
  String get txJitNote;

  /// No description provided for @txCopied.
  ///
  /// In id, this message translates to:
  /// **'Disalin'**
  String get txCopied;

  /// No description provided for @receiveRestoredHint.
  ///
  /// In id, this message translates to:
  /// **'Invoice terakhir yang belum dibayar dipulihkan dari simpanan.'**
  String get receiveRestoredHint;

  /// No description provided for @backupWallet.
  ///
  /// In id, this message translates to:
  /// **'Backup Wallet'**
  String get backupWallet;

  /// No description provided for @legacyWalletSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Dompet ini dibuat sebelum fitur frasa backup ada'**
  String get legacyWalletSubtitle;

  /// No description provided for @backupSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Lihat frasa backup dompet Anda'**
  String get backupSubtitle;

  /// No description provided for @noPhraseTitle.
  ///
  /// In id, this message translates to:
  /// **'Dompet ini tidak punya frasa backup'**
  String get noPhraseTitle;

  /// No description provided for @noPhraseBody.
  ///
  /// In id, this message translates to:
  /// **'Dompet ini dibuat oleh versi aplikasi sebelumnya yang menyimpan kunci tanpa frasa. Bila HP hilang atau rusak, dana di dompet ini tidak bisa dipulihkan.\n\nBila dompet ini masih KOSONG (belum pernah menerima dana), buat dompet baru yang dilengkapi frasa backup sekarang:'**
  String get noPhraseBody;

  /// No description provided for @createNewWalletTitle.
  ///
  /// In id, this message translates to:
  /// **'Buat dompet baru?'**
  String get createNewWalletTitle;

  /// No description provided for @deleteOldWalletBody.
  ///
  /// In id, this message translates to:
  /// **'Dompet lama akan DIHAPUS PERMANEN beserta seluruh datanya. Lanjutkan HANYA bila dompet lama masih kosong — dana apa pun di dalamnya hilang selamanya.'**
  String get deleteOldWalletBody;

  /// No description provided for @deleteAndCreate.
  ///
  /// In id, this message translates to:
  /// **'Hapus & buat baru'**
  String get deleteAndCreate;

  /// No description provided for @createNewWalletButton.
  ///
  /// In id, this message translates to:
  /// **'Buat dompet baru dengan frasa'**
  String get createNewWalletButton;

  /// No description provided for @networkTestnetLabel.
  ///
  /// In id, this message translates to:
  /// **'Jaringan: Nusacoin Testnet'**
  String get networkTestnetLabel;

  /// No description provided for @networkMainnetLabel.
  ///
  /// In id, this message translates to:
  /// **'Jaringan: Nusacoin Mainnet'**
  String get networkMainnetLabel;

  /// No description provided for @backupWarning.
  ///
  /// In id, this message translates to:
  /// **'Tulis kata-kata ini di kertas dan simpan di tempat aman. Siapa pun yang punya kata-kata ini bisa mengambil danamu.'**
  String get backupWarning;

  /// No description provided for @showBackupWords.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan Kata Backup'**
  String get showBackupWords;

  /// No description provided for @backupCopied.
  ///
  /// In id, this message translates to:
  /// **'Kata backup disalin'**
  String get backupCopied;

  /// No description provided for @copy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get copy;

  /// No description provided for @backupConfirmed.
  ///
  /// In id, this message translates to:
  /// **'Saya sudah menulis kata-kata ini di tempat aman'**
  String get backupConfirmed;

  /// No description provided for @done.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get done;

  /// No description provided for @invalidAmount.
  ///
  /// In id, this message translates to:
  /// **'Masukkan nominal yang valid'**
  String get invalidAmount;

  /// No description provided for @receiveInvoiceDesc.
  ///
  /// In id, this message translates to:
  /// **'Terima {amount} nusan'**
  String receiveInvoiceDesc(String amount);

  /// No description provided for @createInvoiceFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat invoice. Coba lagi.'**
  String get createInvoiceFailed;

  /// No description provided for @receiveJitMinimumNote.
  ///
  /// In id, this message translates to:
  /// **'Untuk penerimaan pertama (sekaligus membuatkan jalur penerimaanmu), jumlah terkecilnya 1.000 nusan. Setelah jalurmu jadi, kamu bisa menerima berapa pun, termasuk di bawah 1.000 nusan.'**
  String get receiveJitMinimumNote;

  /// No description provided for @receiveTitle.
  ///
  /// In id, this message translates to:
  /// **'Terima NUX'**
  String get receiveTitle;

  /// No description provided for @jitInfo.
  ///
  /// In id, this message translates to:
  /// **'Invoice Lightning dengan channel instan (JIT). Tidak perlu tunggu konfirmasi block.'**
  String get jitInfo;

  /// No description provided for @amountLabel.
  ///
  /// In id, this message translates to:
  /// **'Nominal (nusan)'**
  String get amountLabel;

  /// No description provided for @createInvoice.
  ///
  /// In id, this message translates to:
  /// **'Buat Invoice'**
  String get createInvoice;

  /// No description provided for @paymentReceived.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran Diterima'**
  String get paymentReceived;

  /// No description provided for @receivedAmount.
  ///
  /// In id, this message translates to:
  /// **'+{amount} nusan'**
  String receivedAmount(String amount);

  /// No description provided for @fundsArrived.
  ///
  /// In id, this message translates to:
  /// **'Dana sudah masuk ke channel Lightning kamu.'**
  String get fundsArrived;

  /// No description provided for @invoiceTitle.
  ///
  /// In id, this message translates to:
  /// **'Invoice Lightning'**
  String get invoiceTitle;

  /// No description provided for @invoiceCopied.
  ///
  /// In id, this message translates to:
  /// **'Invoice disalin'**
  String get invoiceCopied;

  /// No description provided for @shareInvoiceHint.
  ///
  /// In id, this message translates to:
  /// **'Bagikan invoice ini ke pengirim. Channel akan dibuka otomatis saat pembayaran diterima.'**
  String get shareInvoiceHint;

  /// No description provided for @pasteInvoiceFirst.
  ///
  /// In id, this message translates to:
  /// **'Tempel invoice dulu'**
  String get pasteInvoiceFirst;

  /// No description provided for @invalidInvoice.
  ///
  /// In id, this message translates to:
  /// **'Ini bukan invoice Lightning yang valid'**
  String get invalidInvoice;

  /// No description provided for @payFailed.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran gagal. Coba lagi.'**
  String get payFailed;

  /// No description provided for @payWaitingOutcome.
  ///
  /// In id, this message translates to:
  /// **'Menunggu hasil akhir pembayaran…'**
  String get payWaitingOutcome;

  /// No description provided for @payFailedFinal.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran gagal. Dana tidak terkirim dan saldo Anda tetap utuh.'**
  String get payFailedFinal;

  /// No description provided for @payStillPending.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran masih diproses melewati batas tunggu. Hasil akhirnya akan tampil di Riwayat — jangan bayar ulang invoice yang sama sebelum statusnya jelas.'**
  String get payStillPending;

  /// No description provided for @sendTitle.
  ///
  /// In id, this message translates to:
  /// **'Kirim NUX'**
  String get sendTitle;

  /// No description provided for @sendInfo.
  ///
  /// In id, this message translates to:
  /// **'Tempel atau scan invoice Lightning dari penerima. Pembayaran instan via channel.'**
  String get sendInfo;

  /// No description provided for @paste.
  ///
  /// In id, this message translates to:
  /// **'Tempel'**
  String get paste;

  /// No description provided for @scanQr.
  ///
  /// In id, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @pay.
  ///
  /// In id, this message translates to:
  /// **'Bayar'**
  String get pay;

  /// No description provided for @confirmPayTitle.
  ///
  /// In id, this message translates to:
  /// **'Bayar invoice ini?'**
  String get confirmPayTitle;

  /// No description provided for @confirmPayBody.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran Lightning bersifat instan dan tidak bisa dibatalkan. Periksa lagi invoice di bawah sebelum lanjut.'**
  String get confirmPayBody;

  /// No description provided for @paymentSuccess.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran Berhasil!'**
  String get paymentSuccess;

  /// No description provided for @scanTitle.
  ///
  /// In id, this message translates to:
  /// **'Scan QR Invoice'**
  String get scanTitle;

  /// No description provided for @cameraDenied.
  ///
  /// In id, this message translates to:
  /// **'Izin kamera ditolak. Aktifkan izin kamera untuk ELNUX di Pengaturan HP, lalu coba lagi.'**
  String get cameraDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Kamera tidak dapat dibuka di perangkat ini.'**
  String get cameraUnavailable;

  /// No description provided for @pointCamera.
  ///
  /// In id, this message translates to:
  /// **'Arahkan kamera ke QR invoice'**
  String get pointCamera;

  /// No description provided for @errorConnection.
  ///
  /// In id, this message translates to:
  /// **'Tidak dapat terhubung. Periksa koneksi internet Anda, lalu coba lagi.'**
  String get errorConnection;

  /// No description provided for @errorBalance.
  ///
  /// In id, this message translates to:
  /// **'Saldo tidak mencukupi.'**
  String get errorBalance;

  /// No description provided for @errorInvoice.
  ///
  /// In id, this message translates to:
  /// **'Invoice tidak valid atau sudah kedaluwarsa.'**
  String get errorInvoice;

  /// No description provided for @errorWalletData.
  ///
  /// In id, this message translates to:
  /// **'Data dompet bermasalah. Hubungi operator untuk bantuan.'**
  String get errorWalletData;

  /// No description provided for @restoreWallet.
  ///
  /// In id, this message translates to:
  /// **'Restore Phrase'**
  String get restoreWallet;

  /// No description provided for @restoreSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan dompet dari frasa backup'**
  String get restoreSubtitle;

  /// No description provided for @restoreIntro.
  ///
  /// In id, this message translates to:
  /// **'Masukkan frasa backup dompet yang ingin dipulihkan. Frasa ELNUX berbahasa Inggris, sesuai urutan saat pertama dibuat.'**
  String get restoreIntro;

  /// No description provided for @restoreHint.
  ///
  /// In id, this message translates to:
  /// **'Ketik atau tempel frasa, pisahkan tiap kata dengan spasi'**
  String get restoreHint;

  /// No description provided for @restoreWordCount.
  ///
  /// In id, this message translates to:
  /// **'{count} kata'**
  String restoreWordCount(int count);

  /// No description provided for @restoreInvalidCount.
  ///
  /// In id, this message translates to:
  /// **'Jumlah kata harus 12, 15, 18, 21, atau 24 (frasa ELNUX 12 kata).'**
  String get restoreInvalidCount;

  /// No description provided for @restoreInvalidWords.
  ///
  /// In id, this message translates to:
  /// **'Frasa tidak valid — periksa ejaan dan urutan kata.'**
  String get restoreInvalidWords;

  /// No description provided for @restoreButton.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan Dompet'**
  String get restoreButton;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan dompet ini?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In id, this message translates to:
  /// **'Dompet yang sedang aktif akan DIHAPUS PERMANEN beserta seluruh datanya. Lanjutkan HANYA bila dompet aktif masih kosong, atau frasanya sudah dicadangkan. Frasa hanya memulihkan dompet — status channel Lightning tidak ikut pulih.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreConfirmAction.
  ///
  /// In id, this message translates to:
  /// **'Hapus & Pulihkan'**
  String get restoreConfirmAction;

  /// No description provided for @restoreWorking.
  ///
  /// In id, this message translates to:
  /// **'Memulihkan dompet…'**
  String get restoreWorking;

  /// No description provided for @restoreSuccess.
  ///
  /// In id, this message translates to:
  /// **'Dompet berhasil dipulihkan'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memulihkan dompet. Coba lagi.'**
  String get restoreFailed;

  /// No description provided for @shareLog.
  ///
  /// In id, this message translates to:
  /// **'Bagikan Log'**
  String get shareLog;

  /// No description provided for @shareLogSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kirim catatan teknis node saat ada kendala'**
  String get shareLogSubtitle;

  /// No description provided for @shareLogUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Log belum tersedia.'**
  String get shareLogUnavailable;

  /// No description provided for @shareLogFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membagikan log. Coba lagi.'**
  String get shareLogFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
