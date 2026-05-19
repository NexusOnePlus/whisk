import 'package:flutter/material.dart';
import 'package:whisk/data/services/app_window_service.dart';
import 'package:whisk/ui/core/window_title_bar.dart';

class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!supportsCustomWindowFrame) return child;

    return Stack(
      children: [
        Positioned.fill(child: child),
        const Positioned(top: 12, right: 12, child: WindowTitleBar()),
      ],
    );
  }
}
