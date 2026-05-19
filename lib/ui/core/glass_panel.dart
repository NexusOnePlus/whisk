import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.opacity = 0.7,
    this.blur = 24,
    this.borderGradient,
    this.padding,
    this.margin,
  });

  final Widget child;
  final double borderRadius;
  final double opacity;
  final double blur;
  final Gradient? borderGradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderGradient = borderGradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kGlassHighlight, kGlassShadow],
          stops: [0.0, 1.0],
        );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            painter: _GlassBorderPainter(
              radius: borderRadius,
              gradient: effectiveBorderGradient,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: kGlassBase.withOpacity(opacity),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBorderPainter extends CustomPainter {
  _GlassBorderPainter({required this.radius, required this.gradient});

  final double radius;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.gradient != gradient;
}
