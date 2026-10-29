import 'package:flutter/material.dart';

/// Titik status berdenyut (hijau mint default) — penanda koneksi
/// Lightning hidup. Dipakai di header Beranda dan di pil status
/// kartu saldo.
class PulseDot extends StatefulWidget {
  final bool active;
  final Color color;
  final double size;
  const PulseDot({
    super.key,
    this.active = true,
    this.color = const Color(0xFFA7F3D0),
    this.size = 8,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
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
                color: widget.color.withValues(alpha: 0.8), blurRadius: 10)
          ],
        ),
      ),
    );
  }
}

/// Pil status Lightning di kartu saldo ("⚡ Lightning aktif — siap
/// terima instan" / "Menghubungkan Lightning…").
///
/// Aman di semua ukuran layar dan skala teks: isi pil dibungkus
/// FittedBox scaleDown, jadi bila teksnya lebih lebar dari ruang
/// yang tersedia (layar sempit, bahasa Inggris yang lebih panjang,
/// atau skala font aksesibilitas besar), seluruh isi MENYUSUT
/// mengikuti lebar kartu — teks tidak pernah mendorong bingkai,
/// tidak meluap, dan tidak terpotong elipsis. Di layar normal
/// skalanya 1.0 sehingga tampilan persis seperti desain semula.
class LightningStatusPill extends StatelessWidget {
  final bool active;
  final String label;

  const LightningStatusPill({
    super.key,
    required this.active,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(100),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseDot(active: active),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
