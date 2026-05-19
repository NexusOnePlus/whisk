import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowService {
  const AppWindowService();

  Future<void> initialize() async {
    if (!_supportsCustomWindowFrame) return;

    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(980, 680),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.transparent,
    );

    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

bool get supportsCustomWindowFrame => _supportsCustomWindowFrame;

bool get _supportsCustomWindowFrame {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
