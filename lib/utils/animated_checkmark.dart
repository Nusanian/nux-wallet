import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centang sukses yang digambar perlahan, seperti ditulis tangan.
///
/// Bukan ikon yang langsung muncul atau membesar (pop): lingkaran
/// digores dulu, lalu garis centangnya digores menyusul. Itulah
/// animasi "stroke drawing" / "path drawing" — garisnya tumbuh
/// dari ujung ke ujung mengikuti jalurnya, bukan sekadar fade/scale.
///
/// Dipakai di panel sukses layar Kirim dan layar Terima, menggantikan
/// emoji ✅ (Kirim) dan ikon check_circle (Terima) supaya keduanya
/// terasa sama. Tanpa package tambahan: hanya AnimationController
/// dan CustomPainter bawaan Flutter.
///
/// Animasi jalan sekali saat panel sukses muncul: lingkaran
/// ±350 ms, lalu centangnya ±505 ms (total ±0,86 detik), lalu
/// diam — tidak berulang, supaya tidak mengganggu dan tidak
/// menguras baterai.
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedCheckmark({
    super.key,
    this.size = 72,
    this.color = const Color(0xFF34D399),
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  // Durasi per fase dalam milidetik: lingkaran digores dulu,
  // centang menyusul tepat sesudahnya.
  static const _circleMs = 350;
  static const _checkMs = 505;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _circleMs + _checkMs),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Fase 1 (0–350 ms): lingkaran digores penuh satu putaran.
          // Fase 2 (350–855 ms): centang digores menyusul.
          const circleEnd = _circleMs / (_circleMs + _checkMs);
          final circleProgress = (_controller.value / circleEnd).clamp(
            0.0,
            1.0,
          );
          final checkProgress =
              ((_controller.value - circleEnd) / (1 - circleEnd)).clamp(
                0.0,
                1.0,
              );
          return CustomPaint(
            painter: _CheckmarkPainter(
              circleProgress: circleProgress,
              checkProgress: checkProgress,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color color;

  const _CheckmarkPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.08;
    final radius = size.width / 2 - strokeWidth / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        paint,
      );
    }

    if (checkProgress > 0) {
      final path = Path()
        ..moveTo(
          center.dx - radius * 0.45,
          center.dy + radius * 0.05,
        )
        ..lineTo(
          center.dx - radius * 0.12,
          center.dy + radius * 0.38,
        )
        ..lineTo(
          center.dx + radius * 0.48,
          center.dy - radius * 0.32,
        );
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkProgress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) {
    return old.circleProgress != circleProgress ||
        old.checkProgress != checkProgress ||
        old.color != color;
  }
}
