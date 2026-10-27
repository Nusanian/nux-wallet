import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'config.dart';
import 'locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'theme.dart';
import 'screens/backup_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/send_screen.dart';
import 'services/lsp_service.dart';
import 'utils/format.dart';
import 'utils/coin_alert.dart';
import 'utils/friendly_error.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Muat pilihan tema tersimpan (default gelap) sebelum aplikasi jalan.
  await ThemeController.load();
  // Muat pilihan bahasa tersimpan (default Indonesia) sebelum jalan.
  await LocaleController.load();
  // Layar tetap menyala selama aplikasi hidup (permintaan NUX):
  // dompet harus siap menerima pembayaran, layar tidak boleh
  // mati sendiri. Diaktifkan lagi setiap aplikasi kembali ke depan.
  WakelockPlus.enable().catchError((_) {});
  runApp(const NuxWalletApp());
}

// Global LspService instance (untuk MVP; pakai DI yang proper di produksi)
final lspService = LspService();

class NuxWalletApp extends StatelessWidget {
  const NuxWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([ThemeController.mode, LocaleController.locale]),
      builder: (context, _) {
        return MaterialApp(
          title: 'NUX Wallet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.mode.value,
          locale: LocaleController.locale.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleController.supported,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  bool _booting = true;
  String? _bootError;

  /// Kata frasa backup dompet ini (null bila dompet lama tanpa frasa).
  List<String>? _mnemonicWords;

  /// True bila dompet diwarisi dari versi sebelum fitur frasa backup:
  /// seed-nya ada tapi tidak ada frasa yang bisa ditampilkan ke user.
  bool _legacyWallet = false;

  /// True bila dompet BARU saja dibuat pada boot ini — frasanya wajib
  /// ditampilkan sekali lewat layar Backup sebelum user memakai dompet.
  bool _isNewWallet = false;

  /// Berkas & direktori dompet (diisi _boot; dipakai aksi reset dompet).
  File? _seedFile;
  File? _mnemonicFile;
  Directory? _storageDir;

  /// Sapaan mengikuti jam lokal HP user.
  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 11) return context.l10n.greetingMorning;
    if (h >= 11 && h < 15) return context.l10n.greetingAfternoon;
    if (h >= 15 && h < 18) return context.l10n.greetingEvening;
    return context.l10n.greetingNight;
  }

  /// Saldo Lightning terakhir dari node (msat); null = belum terbaca.
  BigInt? _balanceMsat;

  /// Riwayat pembayaran terakhir dari node (terbaru di depan).
  List<PaymentDetails> _payments = const [];

  /// Deteksi koin masuk: true setelah muat riwayat pertama selesai —
  /// riwayat lama tidak memicu bunyi/getar, hanya kedatangan baru.
  bool _paymentsPrimed = false;

  /// Penyegar berkala dashboard selama aplikasi terbuka.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Pastikan wakelock aktif lagi — beberapa perangkat melepasnya
      // saat aplikasi sempat ke latar.
      WakelockPlus.enable().catchError((_) {});
      if (!_booting && _bootError == null) {
        _refreshDashboard();
      }
    }
  }

  /// Baca ulang saldo Lightning dari node dan tampilkan di dashboard.
  /// Kegagalan baca (mis. node belum sinkron) tidak mengosongkan nilai
  /// terakhir yang berhasil dibaca.
  Future<void> _refreshBalance() async {
    if (!lspService.isRunning) return;
    try {
      final balance = await lspService.getLightningBalance();
      if (mounted) setState(() => _balanceMsat = balance);
    } catch (_) {
      // Abaikan — saldo lama tetap ditampilkan.
    }
  }

  /// Baca ulang riwayat pembayaran dari node untuk daftar Aktivitas
  /// dashboard dan tab Riwayat. Pola sama seperti saldo: kegagalan
  /// baca mempertahankan daftar terakhir yang berhasil dibaca.
  String _paymentKey(PaymentDetails p) =>
      p.id.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _refreshPayments() async {
    if (!lspService.isRunning) return;
    try {
      final payments = await lspService.listPayments();
      // Deteksi koin masuk: pembayaran inbound yang berhasil dan
      // belum pernah terlihat → bunyi cling + getar. Muat pertama
      // (riwayat lama) TIDAK memicu — hanya kedatangan baru.
      if (_paymentsPrimed) {
        final seen = _payments.map(_paymentKey).toSet();
        final coinIn = payments.any((p) =>
            p.direction == PaymentDirection.inbound &&
            p.status == PaymentStatus.succeeded &&
            !seen.contains(_paymentKey(p)));
        if (coinIn) CoinAlert.play();
      }
      _paymentsPrimed = true;
      if (mounted) setState(() => _payments = payments);
    } catch (_) {
      // Abaikan — daftar lama tetap ditampilkan.
    }
  }

  /// Segarkan saldo + riwayat sekaligus. Dipakai di titik-titik
  /// refresh yang sebelumnya hanya menyegarkan saldo.
  Future<void> _refreshDashboard() async {
    await _refreshBalance();
    await _refreshPayments();
  }

  /// Inisialisasi node LDK + LSPS2 saat aplikasi dibuka.
  ///
  /// Dompet baru lahir dari frasa BIP39 12 kata: seed node (64 byte)
  /// diturunkan dari frasa itu (mnemonicToSeed), lalu frasa + seed
  /// disimpan di app support dir dan frasa ditampilkan sekali ke user.
  /// Dompet lama (seed ada, frasa tidak ada) ditandai legacy.
  /// CATATAN MVP: berkas disimpan sebagai file biasa. Untuk produksi,
  /// pindah ke flutter_secure_storage (Keychain/Keystore).
  Future<void> _boot() async {
    try {
      if (!AppConfig.lspConfigured) {
        throw StateError(
            context.l10n.lspNodeIdMissing);
      }
      final dir = await getApplicationSupportDirectory();
      // Seed & storage dipisah per network: build mainnet memakai nama
      // berakhiran _mainnet supaya tidak mewarisi seed/storage testnet
      // (APK mainnet menimpa paket yang sama). Nama testnet dibiarkan
      // persis seperti sebelumnya — wallet testnet yang ada tidak berubah.
      final seedName =
          AppConfig.isTestnet ? 'lsp_seed.bin' : 'lsp_seed_mainnet.bin';
      final storageName =
          AppConfig.isTestnet ? 'lsp_storage' : 'lsp_storage_mainnet';
      final mnemonicName = AppConfig.isTestnet
          ? 'wallet_mnemonic.txt'
          : 'wallet_mnemonic_mainnet.txt';
      final seedFile = File('${dir.path}/$seedName');
      final mnemonicFile = File('${dir.path}/$mnemonicName');
      _seedFile = seedFile;
      _mnemonicFile = mnemonicFile;
      List<int>? seedBytes;
      if (await seedFile.exists()) {
        final existing = await seedFile.readAsBytes();
        if (existing.length == 64) {
          seedBytes = existing;
        } else if (existing.length != 32) {
          throw StateError(context.l10n.seedCorrupt(
              existing.length, seedFile.path));
        }
        // Panjang 32 = berkas dari versi awal yang keliru (builder
        // mensyaratkan 64 byte dan selalu menolak 32, jadi node tidak
        // pernah terbangun dengannya) — belum ada wallet/dana di
        // bawah seed itu, aman dibuat ulang di bawah ini.
      }
      if (seedBytes != null) {
        // Dompet yang sudah ada: frasa hanya tersedia bila berkas
        // frasanya ikut ada (dompet dibuat oleh versi frasa BIP39).
        // Dompet dari versi sebelumnya tidak punya frasa — tandai
        // legacy supaya user ditawari membuat dompet baru berfrasa.
        if (await mnemonicFile.exists()) {
          final words = (await mnemonicFile.readAsString())
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
          if (words.length >= 12 &&
              bip39.validateMnemonic(words.join(' '))) {
            _mnemonicWords = words;
          } else {
            _legacyWallet = true;
          }
        } else {
          _legacyWallet = true;
        }
      }
      if (seedBytes == null) {
        // Dompet BARU: lahir dari frasa BIP39 12 kata. Seed node =
        // mnemonicToSeed (PBKDF2-HMAC-SHA512, 64 byte) — persis format
        // yang diminta builder LDK. Frasa disimpan terpisah supaya bisa
        // ditampilkan lagi dari tab Profil; seed tetap disimpan sebagai
        // berkas 64 byte seperti sebelumnya supaya identitas node
        // stabil antar-update aplikasi.
        final mnemonic = bip39.generateMnemonic();
        seedBytes = bip39.mnemonicToSeed(mnemonic);
        await seedFile.writeAsBytes(seedBytes, flush: true);
        await mnemonicFile.writeAsString(mnemonic, flush: true);
        _mnemonicWords = mnemonic.split(' ');
        _legacyWallet = false;
        _isNewWallet = true;
      }
      final storageDir = Directory('${dir.path}/$storageName');
      _storageDir = storageDir;
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }
      await lspService.init(
        seedBytes: seedBytes,
        storagePath: storageDir.path,
        lspAddress: AppConfig.lspAddress,
        lspNodeId: AppConfig.lspNodeId,
        lspToken: AppConfig.lspToken,
        electrumUrl: AppConfig.electrumUrl,
        isTestnet: AppConfig.isTestnet,
      );
      await _refreshDashboard();
      if (mounted) setState(() => _booting = false);
      // Segarkan berkala selama aplikasi terbuka: saldo + riwayat
      // selalu mutakhir, dan koin masuk terdeteksi untuk peringatan
      // bunyi + getar (lihat _refreshPayments).
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshDashboard(),
      );
      if (_isNewWallet && mounted) {
        _isNewWallet = false;
        // Dompet baru: tampilkan frasa backup sekali sebelum user
        // memakai dompet — frasa ini satu-satunya cadangan dananya.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _mnemonicWords == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BackupScreen(mnemonic: _mnemonicWords!),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _booting = false;
          _bootError =
              friendlyError(e,
                  fallback: context.l10n.bootGenericError,
                  l10n: context.l10n);
        });
      }
    }
  }

  /// Hapus dompet lama tanpa frasa dan buat dompet baru berfrasa.
  /// Hanya ditawarkan untuk dompet legacy; pemanggil (tab Profil)
  /// sudah memastikan user paham dompet lama harus KOSONG — dana di
  /// dompet lama hilang permanen begitu berkasnya dihapus.
  Future<void> _resetWalletWithPhrase() async {
    try {
      await lspService.stop();
    } catch (_) {
      // Node mungkin belum sempat start penuh — abaikan.
    }
    if (_seedFile != null && await _seedFile!.exists()) {
      await _seedFile!.delete();
    }
    if (_mnemonicFile != null && await _mnemonicFile!.exists()) {
      await _mnemonicFile!.delete();
    }
    if (_storageDir != null && await _storageDir!.exists()) {
      await _storageDir!.delete(recursive: true);
    }
    if (!mounted) return;
    setState(() {
      _mnemonicWords = null;
      _legacyWallet = false;
      _balanceMsat = null;
      _payments = const [];
      _tabIndex = 0;
      _booting = true;
      _bootError = null;
    });
    await _boot();
  }

  /// Dialog konfirmasi keluar aplikasi, desain selaras tema:
  /// permukaan mengikuti tema, sudut membulat, aksen emerald.
  Future<void> _confirmExit() async {
    final keluar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.palette.border),
        ),
        title: Text(context.l10n.exitTitle,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          context.l10n.exitBody,
          style: TextStyle(
              fontSize: 13.5, color: ctx.palette.secondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel,
                style: TextStyle(color: ctx.palette.secondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n.exitConfirm),
          ),
        ],
      ),
    );
    if (keluar == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cegat tombol kembali di layar utama: minta konfirmasi dulu
    // sebelum aplikasi benar-benar keluar.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_booting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF10B981)),
              SizedBox(height: 16),
              Text(context.l10n.bootConnecting,
                  style: TextStyle(color: context.palette.secondary)),
            ],
          ),
        ),
      );
    }
    if (_bootError != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('⚠️',
                    style: TextStyle(fontSize: 40),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(context.l10n.bootFailedTitle,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_bootError!,
                    style: TextStyle(
                        fontSize: 13, color: context.palette.secondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _booting = true;
                      _bootError = null;
                    });
                    _boot();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.l10n.bootFailedRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: [
            SingleChildScrollView(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_greeting,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.palette.secondary)),
                            const SizedBox(width: 7),
                            // Duplikat ikon live dari kartu saldo
                            // (permintaan NUX) — hijau emerald agar
                            // lebih terlihat di header.
                            _PulseDot(
                              active: lspService.isRunning,
                              color: const Color(0xFF34D399),
                              size: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Nusanian \u2726',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                      ],
                    ),
                    Row(
                      children: [
                        // Toggle tema Gelap/Terang — pilihan tersimpan
                        // dan berlaku di semua layar.
                        IconButton(
                          onPressed: ThemeController.toggle,
                          tooltip: context.l10n.changeThemeTooltip,
                          icon: Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: context.palette.muted,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: context.palette.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side:
                                BorderSide(color: context.palette.border),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Lencana ikon aplikasi — ketuk untuk ke tab Profil.
                        GestureDetector(
                          onTap: () => setState(() => _tabIndex = 3),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: context.palette.border),
                            ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset('assets/app_icon.png',
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                      ],
                    ),
                  ],
                ),
              ),
              // Balance hero card
              Container(
                margin: const EdgeInsets.all(18),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.totalBalance,
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                            _balanceMsat == null
                                ? '\u2014'
                                : formatNusan(_balanceMsat!),
                            style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: Colors.white)),
                        const SizedBox(width: 6),
                        const Text('nusan',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70)),
                      ],
                    ),
                    Text(
                        AppConfig.isTestnet
                            ? context.l10n.networkTestnet
                            : context.l10n.networkMainnet,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulseDot(active: lspService.isRunning),
                          const SizedBox(width: 7),
                          Text(
                              lspService.isRunning
                                  ? context.l10n.lightningActive
                                  : context.l10n.lightningConnecting,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Peringatan dompet lama tanpa frasa backup
              if (_legacyWallet)
                GestureDetector(
                  onTap: () => setState(() => _tabIndex = 3),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: context.palette.warningIcon, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.legacyStrip,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: context.palette.warningText,
                                height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _quickAction(
                        const Icon(Icons.arrow_outward_rounded, size: 25),
                        context.l10n.send, true, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SendScreen(lspService: lspService),
                        ),
                      ).then((_) => _refreshDashboard());
                    }),
                    const SizedBox(width: 10),
                    // Keamanan: Terima NONAKTIF selama dompet belum punya
                    // frasa backup (dompet legacy) — dana yang masuk ke
                    // dompet tanpa frasa tidak bisa dipulihkan bila HP
                    // hilang/rusak. Strip peringatan di atas menjelaskan
                    // cara mengaktifkannya (buat dompet berfrasa).
                    _quickAction(
                        const Icon(Icons.south_west_rounded, size: 25),
                        context.l10n.receive, !_legacyWallet, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiveScreen(lspService: lspService),
                        ),
                      ).then((_) => _refreshDashboard());
                    }),
                    const SizedBox(width: 10),
_quickAction(const Icon(Icons.add_rounded, size: 25), context.l10n.buy, false, () {}),
                    const SizedBox(width: 10),
                    _quickAction(const Icon(Icons.swap_horiz_rounded, size: 25), context.l10n.swap, false, () {})
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Transactions header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.activity,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () {
                        setState(() => _tabIndex = 2);
                        _refreshDashboard();
                      },
                      child: Text(context.l10n.seeAll,
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Transaction list
              if (_payments.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Text(context.l10n.noActivity,
                      style:
                          TextStyle(fontSize: 13, color: context.palette.muted)),
                )
              else
                ..._payments.take(5).map(_paymentRow),
              const SizedBox(height: 80),
            ],
          ),
            ),
            _ComingSoonPage(
              icon: '\u25CD',
              title: context.l10n.market,
              message: context.l10n.marketSoon,
            ),
            _HistoryPage(payments: _payments, rowBuilder: _paymentRow),
            _ProfilePage(
              mnemonicWords: _mnemonicWords,
              legacyWallet: _legacyWallet,
              isTestnet: AppConfig.isTestnet,
              onViewBackup: () {
                if (_mnemonicWords == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BackupScreen(mnemonic: _mnemonicWords!),
                  ),
                );
              },
              onResetWallet: _resetWalletWithPhrase,
            ),
          ],
        ),
      ),
      // Floating tab bar
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            _tab(0, '\u25C9', context.l10n.home),
            _tab(1, '\u25CD', context.l10n.market),
            _tab(2, '\u21BA', context.l10n.history),
            _tab(3, '\u25CB', context.l10n.profile),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(Widget icon, String label, bool enabled, VoidCallback onTap) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: context.palette.cardAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.2),
                        const Color(0xFF10B981).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: context.palette.label,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ubah satu catatan pembayaran node menjadi baris daftar
  /// aktivitas/riwayat. Nominal ditampilkan bertanda (+ masuk,
  /// − keluar) dalam nusan; label status hanya muncul untuk
  /// pembayaran yang belum sukses (Menunggu/Gagal).
  Widget _paymentRow(PaymentDetails payment) {
    final isIn = payment.direction == PaymentDirection.inbound;
    final kind = payment.kind;
    final tag = kind is PaymentKind_Bolt11Jit
        ? '\u26A1 JIT'
        : kind is PaymentKind_Onchain
            ? '\u26D3 on-chain'
            : '\u26A1';
    final amount = payment.amountMsat == null
        ? '\u2014'
        : '${isIn ? '+' : '\u2212'}${formatNusan(payment.amountMsat!)}';
    final time = formatTxTime(
        DateTime.fromMillisecondsSinceEpoch(
            payment.latestUpdateTimestamp.toInt() * 1000),
        locale: context.l10n.localeName);
    return _txRow(
      isIn
          ? const Icon(Icons.arrow_downward_rounded, size: 22)
          : const Icon(Icons.arrow_upward_rounded, size: 22),
      isIn ? context.l10n.received : context.l10n.sent,
      _shortPaymentId(payment.id),
      tag,
      isIn,
      amount,
      time,
      status: switch (payment.status) {
        PaymentStatus.pending => context.l10n.pending,
        PaymentStatus.failed => context.l10n.failed,
        PaymentStatus.succeeded => null,
      },
      statusBad: payment.status == PaymentStatus.failed,
    );
  }

  Widget _txRow(Widget icon, String title, String addr, String tag, bool isIn,
      String amount, String time,
      {String? status, bool statusBad = false}) {
    final isJit = tag.contains('JIT');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isIn
                  ? LinearGradient(colors: [
                      const Color(0xFF10B981).withOpacity(0.25),
                      const Color(0xFF10B981).withOpacity(0.08),
                    ])
                  : null,
              color: isIn ? null : context.palette.softBg,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(addr,
                        style: TextStyle(
                            fontSize: 12, color: context.palette.muted)),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isJit
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : context.palette.softBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isJit
                                  ? const Color(0xFF34D399)
                                  : context.palette.dim)),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (statusBad
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusBad
                                    ? context.palette.dangerSoft
                                    : context.palette.warningIcon)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isIn
                          ? const Color(0xFF34D399)
                          : Colors.white)),
              const SizedBox(height: 3),
              Text(time,
                  style:
                      TextStyle(fontSize: 11, color: context.palette.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tab(int index, String icon, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabIndex = index);
          if (index == 0 || index == 2) _refreshDashboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)])
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon,
                  style: TextStyle(
                      fontSize: 20,
                      color: active ? Colors.white : context.palette.faint)),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : context.palette.faint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ID pembayaran dipendekkan untuk subjudul baris daftar:
/// 5 karakter hex awal + 4 karakter hex akhir.
String _shortPaymentId(PaymentId id) {
  final hex = id.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  if (hex.length <= 10) return hex;
  return '${hex.substring(0, 5)}\u2026${hex.substring(hex.length - 4)}';
}

/// Tab Profil — pengaturan dompet: tema, frasa backup & info jaringan.
/// Untuk dompet legacy (tanpa frasa) halaman ini menampung tawaran
/// membuat dompet baru berfrasa, lengkap dengan konfirmasi bahaya.
class _ProfilePage extends StatelessWidget {
  final List<String>? mnemonicWords;
  final bool legacyWallet;
  final bool isTestnet;
  final VoidCallback onViewBackup;
  final Future<void> Function() onResetWallet;

  const _ProfilePage({
    required this.mnemonicWords,
    required this.legacyWallet,
    required this.isTestnet,
    required this.onViewBackup,
    required this.onResetWallet,
  });

  /// Dialog pilih bahasa — dua opsi, yang aktif bertanda centang.
  Future<void> _showLanguageDialog(BuildContext context) async {
    final l10n = context.l10n;
    final current = LocaleController.locale.value;
    final picked = await showDialog<Locale>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.card,
        title: Text(l10n.chooseLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _languageOption(ctx, const Locale('id'),
                l10n.languageIndonesian, current.languageCode == 'id'),
            _languageOption(ctx, const Locale('en'), l10n.languageEnglish,
                current.languageCode == 'en'),
          ],
        ),
      ),
    );
    if (picked != null) await LocaleController.setLocale(picked);
  }

  Widget _languageOption(
      BuildContext ctx, Locale locale, String label, bool selected) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Color(0xFF34D399))
          : null,
      onTap: () => Navigator.pop(ctx, locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
            child: Text(context.l10n.profile,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          // Baris Tema — toggle Gelap/Terang (tersimpan, sama
          // seperti tombol di header dashboard).
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.25),
                      const Color(0xFF10B981).withValues(alpha: 0.08),
                    ]),
                  ),
                  child: const Icon(Icons.brightness_6_rounded,
                      color: Color(0xFF34D399), size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.themeTitle,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.themeSubtitle,
                        style: TextStyle(
                            fontSize: 12, color: context.palette.muted),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.mode,
                  builder: (context, mode, _) => Switch(
                    value: mode == ThemeMode.dark,
                    onChanged: (dark) => ThemeController.setMode(
                        dark ? ThemeMode.dark : ThemeMode.light),
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          // Baris Bahasa — pilih Indonesia/English (tersimpan,
          // berlaku di semua layar setelah dipilih).
          GestureDetector(
            onTap: () => _showLanguageDialog(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.25),
                        const Color(0xFF10B981).withValues(alpha: 0.08),
                      ]),
                    ),
                    child: const Icon(Icons.language_rounded,
                        color: Color(0xFF34D399), size: 20),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.appLanguage,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        ValueListenableBuilder<Locale>(
                          valueListenable: LocaleController.locale,
                          builder: (context, locale, _) => Text(
                            locale.languageCode == 'en'
                                ? 'English'
                                : 'Bahasa Indonesia',
                            style: TextStyle(
                                fontSize: 12, color: context.palette.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: context.palette.muted),
                ],
              ),
            ),
          ),
          // Baris Backup Wallet
          GestureDetector(
            onTap: legacyWallet ? null : onViewBackup,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [
                        const Color(0xFF10B981).withOpacity(0.25),
                        const Color(0xFF10B981).withOpacity(0.08),
                      ]),
                    ),
                    child: const Icon(Icons.key_rounded,
                        color: Color(0xFF34D399), size: 20),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.backupWallet,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          legacyWallet
                              ? context.l10n.legacyWalletSubtitle
                              : context.l10n.backupSubtitle,
                          style: TextStyle(
                              fontSize: 12, color: context.palette.muted),
                        ),
                      ],
                    ),
                  ),
                  if (!legacyWallet)
                    Icon(Icons.chevron_right_rounded,
                        color: context.palette.muted),
                ],
              ),
            ),
          ),
          // Kartu dompet legacy: tawarkan buat ulang berfrasa
          if (legacyWallet)
            Container(
              margin: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.l10n.noPhraseTitle,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.palette.warningText)),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.noPhraseBody,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: context.palette.label,
                        height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: ctx.palette.card,
                          title: Text(ctx.l10n.createNewWalletTitle),
                          content: Text(
                              ctx.l10n.deleteOldWalletBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(ctx.l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(ctx.l10n.deleteAndCreate,
                                  style:
                                      TextStyle(color: Color(0xFFEF4444))),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await onResetWallet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(context.l10n.createNewWalletButton),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          // Info jaringan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              isTestnet
                  ? context.l10n.networkTestnetLabel
                  : context.l10n.networkMainnetLabel,
              style: TextStyle(fontSize: 12.5, color: context.palette.muted),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Tab Riwayat — seluruh pembayaran dari node, terbaru di depan.
class _HistoryPage extends StatelessWidget {
  final List<PaymentDetails> payments;
  final Widget Function(PaymentDetails) rowBuilder;

  const _HistoryPage({required this.payments, required this.rowBuilder});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('\u21BA',
                  style: TextStyle(fontSize: 44, color: Color(0xFF34D399))),
              SizedBox(height: 14),
              Text(context.l10n.history,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                  context.l10n.noTransactions,
                  style: TextStyle(fontSize: 13, color: context.palette.secondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
          child: Text(context.l10n.history,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: payments.map(rowBuilder).toList(),
          ),
        ),
      ],
    );
  }
}

/// Halaman placeholder untuk tab yang belum punya konten sendiri.
class _ComingSoonPage extends StatelessWidget {
  final String icon;
  final String title;
  final String message;

  const _ComingSoonPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon,
                style: const TextStyle(
                    fontSize: 44, color: Color(0xFF34D399))),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                style: TextStyle(
                    fontSize: 13, color: context.palette.secondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  final Color color;
  final double size;
  const _PulseDot({
    this.active = true,
    this.color = const Color(0xFFA7F3D0),
    this.size = 8,
  });

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.4).animate(_ctrl),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
                color: widget.color.withOpacity(0.8), blurRadius: 10)
          ],
        ),
      ),
    );
  }
}
