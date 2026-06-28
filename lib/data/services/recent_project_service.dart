import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisk/domain/models/recent_project.dart';

class RecentProjectService extends ChangeNotifier {
  static const _maxEntries = 5;
  static const _fileName = 'recent_projects.json';
  List<RecentProject> _projects = [];

  List<RecentProject> get projects => List.unmodifiable(_projects);

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
      _projects = [];
      return;
    }
    try {
      final contents = await file.readAsString();
      final list = json.decode(contents) as List<dynamic>;
      _projects = list
          .map((e) => RecentProject.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      _projects = [];
    }
  }

  Future<void> save(RecentProject project) async {
    _projects = [
      project,
      for (final p in _projects)
        if (p.path != project.path) p,
    ];
    if (_projects.length > _maxEntries) {
      _projects = _projects.sublist(0, _maxEntries);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String path) async {
    _projects = [for (final p in _projects) if (p.path != path) p];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final filePath = await _filePath;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final contents = json.encode(
      [for (final p in _projects) p.toJson()],
    );
    await file.writeAsString(contents);
  }
}
