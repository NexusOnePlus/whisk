import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class AmbientGlowPainter extends CustomPainter {
  AmbientGlowPainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              kAccentBlue.withValues(alpha: 0.12),
              kAccentBlue.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * 0.3 + 50 * math.sin(animationValue * 2 * math.pi),
                size.height * 0.4 + 60 * math.cos(animationValue * 2 * math.pi),
              ),
              radius: size.width * 0.35,
            ),
          );

    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              kAccentAmber.withValues(alpha: 0.08),
              kAccentAmber.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * 0.7 + 60 * math.cos(animationValue * 2 * math.pi),
                size.height * 0.6 + 50 * math.sin(animationValue * 2 * math.pi),
              ),
              radius: size.width * 0.4,
            ),
          );

    final paint3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              kSuccessGreen.withValues(alpha: 0.06),
              kSuccessGreen.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * 0.5 +
                    80 * math.sin((animationValue + 0.5) * 2 * math.pi),
                size.height * 0.2 +
                    40 * math.cos((animationValue + 0.5) * 2 * math.pi),
              ),
              radius: size.width * 0.3,
            ),
          );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant AmbientGlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
