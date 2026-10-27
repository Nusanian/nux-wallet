// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appLanguage => 'Language';

  @override
  String get chooseLanguage => 'Choose Language';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSubtitle => 'Dark or light, as you like';

  @override
  String get changeThemeTooltip => 'Change theme';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get bootConnecting => 'Connecting to LSP…';

  @override
  String get splashTagline => 'Your money, your control.';

  @override
  String get bootFailedTitle => 'Failed to connect node';

  @override
  String get bootFailedRetry => 'Try again';

  @override
  String get bootGenericError =>
      'Something went wrong while starting the wallet.';

  @override
  String get lspNodeIdMissing =>
      'lspNodeId is not set in lib/config.dart — ask the operator for the LSP node id.';

  @override
  String seedCorrupt(int length, String path) {
    return 'Seed file corrupted (length $length, must be 64). Delete $path to regenerate (OLD FUNDS WILL BE LOST).';
  }

  @override
  String get exitTitle => 'Exit ELNUX?';

  @override
  String get exitBody =>
      'The app will close. While the app is closed, the wallet cannot receive payments.';

  @override
  String get cancel => 'Cancel';

  @override
  String get exitConfirm => 'Exit';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get networkTestnet => 'Lightning Network • Testnet';

  @override
  String get networkMainnet => 'Lightning Network • Mainnet';

  @override
  String get lightningActive => 'Lightning active — ready for instant receive';

  @override
  String get lightningConnecting => 'Connecting Lightning…';

  @override
  String get legacyStrip =>
      'This wallet has no backup phrase yet. Open the Profile tab to create a new wallet with a phrase before receiving funds.';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get buy => 'Buy';

  @override
  String get swap => 'Swap';

  @override
  String get activity => 'Activity';

  @override
  String get seeAll => 'See all';

  @override
  String get noActivity => 'No activity yet';

  @override
  String get market => 'Market';

  @override
  String get marketSoon => 'NUX market info — coming soon.';

  @override
  String get home => 'Home';

  @override
  String get history => 'History';

  @override
  String get profile => 'Profile';

  @override
  String get received => 'Received';

  @override
  String get sent => 'Sent';

  @override
  String get pending => 'Pending';

  @override
  String get failed => 'Failed';

  @override
  String get noTransactions =>
      'No transactions yet. Incoming and outgoing payments will appear here.';

  @override
  String get backupWallet => 'Backup Wallet';

  @override
  String get legacyWalletSubtitle =>
      'This wallet was created before the backup phrase feature existed';

  @override
  String get backupSubtitle => 'View your wallet backup phrase';

  @override
  String get noPhraseTitle => 'This wallet has no backup phrase';

  @override
  String get noPhraseBody =>
      'This wallet was created by a previous app version that stored keys without a phrase. If the phone is lost or damaged, funds in this wallet cannot be recovered.\n\nIf this wallet is still EMPTY (never received funds), create a new phrase-backed wallet now:';

  @override
  String get createNewWalletTitle => 'Create a new wallet?';

  @override
  String get deleteOldWalletBody =>
      'The old wallet will be PERMANENTLY DELETED along with all its data. Continue ONLY if the old wallet is still empty — any funds in it will be lost forever.';

  @override
  String get deleteAndCreate => 'Delete & create new';

  @override
  String get createNewWalletButton => 'Create a new wallet with a phrase';

  @override
  String get networkTestnetLabel => 'Network: Nusacoin Testnet';

  @override
  String get networkMainnetLabel => 'Network: Nusacoin Mainnet';

  @override
  String get backupWarning =>
      'Write these words on paper and store them somewhere safe. Anyone who has these words can take your funds.';

  @override
  String get showBackupWords => 'Show Backup Words';

  @override
  String get backupCopied => 'Backup words copied';

  @override
  String get copy => 'Copy';

  @override
  String get backupConfirmed => 'I have written these words somewhere safe';

  @override
  String get done => 'Done';

  @override
  String get invalidAmount => 'Enter a valid amount';

  @override
  String receiveInvoiceDesc(String amount) {
    return 'Receive $amount nusan';
  }

  @override
  String get createInvoiceFailed => 'Failed to create invoice. Try again.';

  @override
  String get receiveTitle => 'Receive NUX';

  @override
  String get jitInfo =>
      'Lightning invoice with an instant channel (JIT). No need to wait for block confirmation.';

  @override
  String get amountLabel => 'Amount (nusan)';

  @override
  String get createInvoice => 'Create Invoice';

  @override
  String get paymentReceived => 'Payment Received';

  @override
  String receivedAmount(String amount) {
    return '+$amount nusan';
  }

  @override
  String get fundsArrived => 'Funds have arrived in your Lightning channel.';

  @override
  String get invoiceTitle => 'Lightning Invoice';

  @override
  String get invoiceCopied => 'Invoice copied';

  @override
  String get shareInvoiceHint =>
      'Share this invoice with the sender. The channel will open automatically when the payment is received.';

  @override
  String get pasteInvoiceFirst => 'Paste an invoice first';

  @override
  String get invalidInvoice => 'This is not a valid Lightning invoice';

  @override
  String get payFailed => 'Payment failed. Try again.';

  @override
  String get sendTitle => 'Send NUX';

  @override
  String get sendInfo =>
      'Paste or scan a Lightning invoice from the recipient. Instant payment via channel.';

  @override
  String get paste => 'Paste';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get pay => 'Pay';

  @override
  String get paymentSuccess => 'Payment Successful!';

  @override
  String get scanTitle => 'Scan QR Invoice';

  @override
  String get cameraDenied =>
      'Camera permission denied. Enable camera permission for ELNUX in phone Settings, then try again.';

  @override
  String get cameraUnavailable => 'Camera cannot be opened on this device.';

  @override
  String get pointCamera => 'Point the camera at the QR invoice';

  @override
  String get errorConnection =>
      'Cannot connect. Check your internet connection, then try again.';

  @override
  String get errorBalance => 'Insufficient balance.';

  @override
  String get errorInvoice => 'Invoice is invalid or has expired.';

  @override
  String get errorWalletData =>
      'Wallet data is corrupted. Contact the operator for help.';

  @override
  String get restoreWallet => 'Restore Phrase';

  @override
  String get restoreSubtitle => 'Restore your wallet from a backup phrase';

  @override
  String get restoreIntro =>
      'Enter the backup phrase of the wallet you want to restore. ELNUX phrases are in English, in the original order.';

  @override
  String get restoreHint =>
      'Type or paste the phrase, separating each word with a space';

  @override
  String restoreWordCount(int count) {
    return '$count words';
  }

  @override
  String get restoreInvalidCount =>
      'The phrase must have 12, 15, 18, 21, or 24 words (ELNUX phrases have 12 words).';

  @override
  String get restoreInvalidWords =>
      'Invalid phrase — check the spelling and word order.';

  @override
  String get restoreButton => 'Restore Wallet';

  @override
  String get restoreConfirmTitle => 'Restore this wallet?';

  @override
  String get restoreConfirmBody =>
      'The active wallet will be PERMANENTLY DELETED with all its data. Continue ONLY if the active wallet is still empty, or its phrase is already backed up. A phrase restores the wallet — Lightning channel states are not restored.';

  @override
  String get restoreConfirmAction => 'Delete & Restore';

  @override
  String get restoreWorking => 'Restoring wallet…';

  @override
  String get restoreSuccess => 'Wallet restored successfully';

  @override
  String get restoreFailed => 'Failed to restore the wallet. Try again.';
}
