import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowService {
  const AppWindowService();

  static const _stateFileName = 'window_state.json';

  Future<void> initialize() async {
    if (!_supportsCustomWindowFrame) return;

    await windowManager.ensureInitialized();

    final saved = await _loadWindowState();

    final options = WindowOptions(
      size: saved?.size ?? const Size(1280, 820),
      minimumSize: const Size(980, 680),
      center: saved == null,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.transparent,
    );

    windowManager.waitUntilReadyToShow(options, () async {
      if (saved?.position != null) {
        await windowManager.setPosition(saved!.position);
      }
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(_WindowListener());
  }

  static Future<void> saveWindowState() async {
    if (!_supportsCustomWindowFrame) return;
    try {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final state = {
        'width': size.width,
        'height': size.height,
        'x': position.dx,
        'y': position.dy,
      };
      final path = await _filePath;
      final file = File(path);
      await file.writeAsString(json.encode(state));
    } catch (_) {}
  }

  static Future<_WindowState?> _loadWindowState() async {
    try {
      final path = await _filePath;
      final file = File(path);
      if (!await file.exists()) return null;
      final jsonMap = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _WindowState(
        size: Size(
          (jsonMap['width'] as num).toDouble(),
          (jsonMap['height'] as num).toDouble(),
        ),
        position: Offset(
          (jsonMap['x'] as num).toDouble(),
          (jsonMap['y'] as num).toDouble(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> get _filePath async {
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}${Platform.pathSeparator}$_stateFileName';
    } catch (_) {
      return '${Directory.systemTemp.path}${Platform.pathSeparator}$_stateFileName';
    }
  }
}

class _WindowState {
  const _WindowState({required this.size, required this.position});
  final Size size;
  final Offset position;
}

class _WindowListener extends WindowListener {
  @override
  void onWindowClose() {
    AppWindowService.saveWindowState();
  }

  @override
  void onWindowResized() {
    AppWindowService.saveWindowState();
  }

  @override
  void onWindowMoved() {
    AppWindowService.saveWindowState();
  }
}

bool get supportsCustomWindowFrame => _supportsCustomWindowFrame;

bool get _supportsCustomWindowFrame {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
