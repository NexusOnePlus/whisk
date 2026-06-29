import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:developer' as dev;

class ProjectTagsService extends ChangeNotifier {
  ProjectTagsService._();
  static ProjectTagsService? _instance;
  static ProjectTagsService get instance => _instance ??= ProjectTagsService._();

  final Map<String, List<String>> _tags = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  List<String> get allTags {
    final tags = <String>{};
    for (final tagsList in _tags.values) {
      tags.addAll(tagsList);
    }
    return tags.toList()..sort();
  }

  List<String> tagsFor(String path) => List.unmodifiable(_tags[path] ?? []);

  Map<String, List<String>> get all => Map.unmodifiable(_tags);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final dir = await _dir();
      final file = File('${dir.path}${Platform.pathSeparator}project_tags.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _tags[entry.key] = List<String>.from(entry.value as List);
        }
      }
    } catch (e) {
      dev.log('Failed to load project tags: $e', name: 'ProjectTagsService');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addTag(String path, String tag) async {
    _tags.putIfAbsent(path, () => []);
    if (!_tags[path]!.contains(tag)) {
      _tags[path]!.add(tag);
      notifyListeners();
      await _save();
    }
  }

  Future<void> removeTag(String path, String tag) async {
    _tags[path]?.remove(tag);
    if (_tags[path]?.isEmpty ?? false) {
      _tags.remove(path);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}${Platform.pathSeparator}project_tags.json');
      await file.writeAsString(jsonEncode(_tags));
    } catch (e) {
      dev.log('Failed to save project tags: $e', name: 'ProjectTagsService');
    }
  }

  static Future<Directory> _dir() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final dir = Directory('$appData${Platform.pathSeparator}whisk');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}settings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
