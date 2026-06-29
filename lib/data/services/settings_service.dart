import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:developer' as dev;

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  String _profileName = '';
  bool _loaded = false;
  final Map<String, List<String>> _projectTags = {};

  String get profileName => _profileName;
  bool get loaded => _loaded;
  Map<String, List<String>> get projectTags => Map.unmodifiable(_projectTags);

  List<String> get allTags {
    final tags = <String>{};
    for (final tagsList in _projectTags.values) {
      tags.addAll(tagsList);
    }
    return tags.toList()..sort();
  }

  List<String> tagsForProject(String path) =>
      List.unmodifiable(_projectTags[path] ?? []);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final dir = await _appSettingsDir();
      final file = File('${dir.path}${Platform.pathSeparator}settings.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _profileName = data['profileName'] as String? ?? '';
        final tags = data['projectTags'] as Map<String, dynamic>?;
        if (tags != null) {
          for (final entry in tags.entries) {
            _projectTags[entry.key] = List<String>.from(entry.value as List);
          }
        }
      }
    } catch (e) {
      dev.log('Failed to load settings: $e', name: 'SettingsService');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setProfileName(String name) async {
    _profileName = name;
    notifyListeners();
    await _save();
  }

  Future<void> addTagToProject(String path, String tag) async {
    _projectTags.putIfAbsent(path, () => []);
    if (!_projectTags[path]!.contains(tag)) {
      _projectTags[path]!.add(tag);
      notifyListeners();
      await _save();
    }
  }

  Future<void> removeTagFromProject(String path, String tag) async {
    _projectTags[path]?.remove(tag);
    if (_projectTags[path]?.isEmpty ?? false) {
      _projectTags.remove(path);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final dir = await _appSettingsDir();
      final file = File('${dir.path}${Platform.pathSeparator}settings.json');
      await file.writeAsString(jsonEncode({
        'profileName': _profileName,
        'projectTags': _projectTags,
      }));
    } catch (e) {
      dev.log('Failed to save settings: $e', name: 'SettingsService');
    }
  }

  static Future<Directory> _appSettingsDir() async {
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
