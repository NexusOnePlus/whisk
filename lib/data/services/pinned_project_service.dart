import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PinnedProjectService extends ChangeNotifier {
  static const _fileName = 'pinned_projects.json';
  List<String> _pinnedPaths = [];

  List<String> get pinnedPaths => List.unmodifiable(_pinnedPaths);

  Future<String> get _filePath async {
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}${Platform.pathSeparator}$_fileName';
    } catch (_) {
      return '${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName';
    }
  }

  Future<void> load() async {
    final path = await _filePath;
    final file = File(path);
    if (!await file.exists()) {
      _pinnedPaths = [];
      notifyListeners();
      return;
    }
    try {
      final contents = await file.readAsString();
      final list = json.decode(contents) as List<dynamic>;
      _pinnedPaths = list.cast<String>();
    } catch (_) {
      _pinnedPaths = [];
    }
    notifyListeners();
  }

  bool isPinned(String path) => _pinnedPaths.contains(path);

  Future<void> toggle(String path) async {
    if (_pinnedPaths.contains(path)) {
      _pinnedPaths = [for (final p in _pinnedPaths) if (p != path) p];
    } else {
      _pinnedPaths = [..._pinnedPaths, path];
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final filePath = await _filePath;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(json.encode(_pinnedPaths));
  }
}
