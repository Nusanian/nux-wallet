import 'package:flutter/material.dart';
import 'screens/receive_screen.dart';
import 'screens/send_screen.dart';
import 'services/lsp_service.dart';

void main() {
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

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selamat malam',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8A9A90))),
                        SizedBox(height: 2),
                        Text('nusacoin \u2726',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF34D399), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Text('N',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF06231A))),
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
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('12.50',
                            style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1)),
                        SizedBox(width: 6),
                        Text('NUX',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70)),
                      ],
                    ),
                    const Text('\u2248 \$0.06 USD  \u2022  Rp1.007',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulseDot(),
                          SizedBox(width: 7),
                          Text('Lightning aktif \u2014 siap terima instan',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _quickAction('\u2197', 'Kirim', true, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SendScreen(lspService: lspService),
                        ),
                      );
                    }),
                    const SizedBox(width: 10),
                    _quickAction('\u2199', 'Terima', true, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiveScreen(lspService: lspService),
                        ),
                      );
                    }),
                    const SizedBox(width: 10),
                    _quickAction('\uFF0B', 'Beli', false, () {}),
                    const SizedBox(width: 10),
                    _quickAction('\u21C4', 'Tukar', false, () {}),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Transactions header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aktivitas',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Lihat semua',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF34D399),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Transaction list
              _txRow('\u2193', 'Diterima', 'uQsen\u20260001', '\u26A1 JIT', true, '+0.05', '17.17'),
              _txRow('\u2191', 'Terkirim', 'uQRec\u20260002', '\u26A1', false, '\u22120.02', '13.17'),
              _txRow('\u2193', 'Diterima', 'uQsen\u20260003', '\u26A1 JIT', true, '+1.00', 'Kemarin'),
              _txRow('\u2191', 'Terkirim', 'uQRec\u20260004', '\u26D3 on-chain', false, '\u22120.50', '15 Okt'),
              const SizedBox(height: 80),
            ],
          ),
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

  Widget _quickAction(String icon, String label, bool enabled, VoidCallback onTap) {
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
                      child: Text(icon, style: const TextStyle(fontSize: 20))),
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

  Widget _txRow(String icon, String title, String addr, String tag, bool isIn,
      String amount, String time) {
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
        onTap: () => setState(() => _tabIndex = index),
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

class _PulseDot extends StatefulWidget {
  const _PulseDot();

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
