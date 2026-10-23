import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ldk_node/src/generated/api/types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'config.dart';
import 'screens/backup_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/send_screen.dart';
import 'services/lsp_service.dart';
import 'utils/format.dart';
import 'utils/friendly_error.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'NUX Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          surface: Color(0xFF101412),
        ),
      ),
      home: const HomeScreen(),
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
    if (h >= 4 && h < 11) return 'Selamat pagi';
    if (h >= 11 && h < 15) return 'Selamat siang';
    if (h >= 15 && h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  /// Saldo Lightning terakhir dari node (msat); null = belum terbaca.
  BigInt? _balanceMsat;

  /// Riwayat pembayaran terakhir dari node (terbaru di depan).
  List<PaymentDetails> _payments = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
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
  Future<void> _refreshPayments() async {
    if (!lspService.isRunning) return;
    try {
      final payments = await lspService.listPayments();
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
            'lspNodeId belum diisi di lib/config.dart — minta node id LSP ke operator.');
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
          throw StateError(
              'File seed korup (panjang ${existing.length}, harus 64). '
              'Hapus ${seedFile.path} untuk generate ulang (DANA LAMA HILANG).');
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
              friendlyError(e, fallback: 'Terjadi kendala saat memulai dompet.');
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
  /// permukaan gelap, sudut membulat, aksen emerald.
  Future<void> _confirmExit() async {
    final keluar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101412),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        title: const Text('Keluar dari ELNUX?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text(
          'Aplikasi akan ditutup. Selama aplikasi tertutup, dompet tidak '
          'dapat menerima pembayaran.',
          style: TextStyle(
              fontSize: 13.5, color: Color(0xFF8A9A90), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(color: Color(0xFF8A9A90))),
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
            child: const Text('Keluar'),
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF10B981)),
              SizedBox(height: 16),
              Text('Menghubungkan ke LSP…',
                  style: TextStyle(color: Color(0xFF8A9A90))),
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
                const Text('Gagal menghubungkan node',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_bootError!,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8A9A90)),
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
                  child: const Text('Coba lagi'),
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
                        Text(_greeting,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF8A9A90))),
                        const SizedBox(height: 2),
                        const Text('Nusanian \u2726',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                      ],
                    ),
                    // Lencana ikon aplikasi — ketuk untuk ke tab Profil.
                    GestureDetector(
                      onTap: () => setState(() => _tabIndex = 3),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
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
                    const Text('Total Saldo',
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
                                letterSpacing: -1)),
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
                            ? 'Lightning Network \u2022 Testnet'
                            : 'Lightning Network \u2022 Mainnet',
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
                                  ? 'Lightning aktif \u2014 siap terima instan'
                                  : 'Menghubungkan Lightning\u2026',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
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
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFBBF24), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dompet ini belum punya frasa backup. Buka tab Profil '
                            'untuk membuat dompet baru dengan frasa sebelum menerima dana.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFFDE68A),
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
                    _quickAction(Icons.arrow_outward_rounded, 'Kirim', true, () {
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
                    _quickAction(Icons.south_west_rounded, 'Terima',
                        !_legacyWallet, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiveScreen(lspService: lspService),
                        ),
                      ).then((_) => _refreshDashboard());
                    }),
                    const SizedBox(width: 10),
                    _quickAction(Icons.add_rounded, 'Beli', false, () {}),
                    const SizedBox(width: 10),
                    _quickAction(Icons.swap_horiz_rounded, 'Tukar', false, () {}),
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
                    const Text('Aktivitas',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () {
                        setState(() => _tabIndex = 2);
                        _refreshDashboard();
                      },
                      child: const Text('Lihat semua',
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Text('Belum ada aktivitas',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF7D8F86))),
                )
              else
                ..._payments.take(5).map(_paymentRow),
              const SizedBox(height: 80),
            ],
          ),
            ),
            const _ComingSoonPage(
              icon: '\u25CD',
              title: 'Pasar',
              message: 'Info pasar NUX \u2014 segera hadir.',
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
          color: const Color(0xFF101412),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            _tab(0, '\u25C9', 'Beranda'),
            _tab(1, '\u25CD', 'Pasar'),
            _tab(2, '\u21BA', 'Riwayat'),
            _tab(3, '\u25CB', 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, bool enabled, VoidCallback onTap) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF121715),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  child: Center(
                      child: Icon(icon,
                          size: 22, color: const Color(0xFF34D399))),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB8C8BF),
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
    final time = formatTxTime(DateTime.fromMillisecondsSinceEpoch(
        payment.latestUpdateTimestamp.toInt() * 1000));
    return _txRow(
      isIn ? '\u2193' : '\u2191',
      isIn ? 'Diterima' : 'Terkirim',
      _shortPaymentId(payment.id),
      tag,
      isIn,
      amount,
      time,
      status: switch (payment.status) {
        PaymentStatus.pending => 'Menunggu',
        PaymentStatus.failed => 'Gagal',
        PaymentStatus.succeeded => null,
      },
      statusBad: payment.status == PaymentStatus.failed,
    );
  }

  Widget _txRow(String icon, String title, String addr, String tag, bool isIn,
      String amount, String time,
      {String? status, bool statusBad = false}) {
    final isJit = tag.contains('JIT');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF101412),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
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
              color: isIn ? null : Colors.white.withOpacity(0.05),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
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
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7D8F86))),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isJit
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isJit
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF9AA8A0))),
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
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFFFBBF24))),
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
                      const TextStyle(fontSize: 11, color: Color(0xFF7D8F86))),
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
                      color: active ? Colors.white : const Color(0xFF6B7D73))),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : const Color(0xFF6B7D73))),
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

/// Tab Profil — pengaturan dompet: frasa backup & info jaringan.
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
            child: Text('Profil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          // Baris Backup Wallet
          GestureDetector(
            onTap: legacyWallet ? null : onViewBackup,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101412),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                        const Text('Backup Wallet',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          legacyWallet
                              ? 'Dompet ini dibuat sebelum fitur frasa backup ada'
                              : 'Lihat frasa backup dompet Anda',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF7D8F86)),
                        ),
                      ],
                    ),
                  ),
                  if (!legacyWallet)
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF7D8F86)),
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
                  const Text('Dompet ini tidak punya frasa backup',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFDE68A))),
                  const SizedBox(height: 6),
                  const Text(
                    'Dompet ini dibuat oleh versi aplikasi sebelumnya yang '
                    'menyimpan kunci tanpa frasa. Bila HP hilang atau rusak, '
                    'dana di dompet ini tidak bisa dipulihkan.\n\n'
                    'Bila dompet ini masih KOSONG (belum pernah menerima '
                    'dana), buat dompet baru yang dilengkapi frasa backup '
                    'sekarang:',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB8C8BF),
                        height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF101412),
                          title: const Text('Buat dompet baru?'),
                          content: const Text(
                              'Dompet lama akan DIHAPUS PERMANEN beserta '
                              'seluruh datanya. Lanjutkan HANYA bila dompet '
                              'lama masih kosong — dana apa pun di dalamnya '
                              'hilang selamanya.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Hapus & buat baru',
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
                    child: const Text('Buat dompet baru dengan frasa'),
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
                  ? 'Jaringan: Nusacoin Testnet'
                  : 'Jaringan: Nusacoin Mainnet',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7D8F86)),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('\u21BA',
                  style: TextStyle(fontSize: 44, color: Color(0xFF34D399))),
              SizedBox(height: 14),
              Text('Riwayat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                  'Belum ada transaksi. Pembayaran masuk dan keluar akan tampil di sini.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8A9A90)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
          child: Text('Riwayat',
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
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF8A9A90)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({this.active = true});

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
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFA7F3D0),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFA7F3D0).withOpacity(0.8), blurRadius: 10)
          ],
        ),
      ),
    );
  }
}
