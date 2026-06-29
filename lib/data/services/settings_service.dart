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
  bool _renderOnSaveOnly = false;
  bool _loaded = false;
  final Map<String, List<String>> _projectTags = {};
  final Map<String, String> _projectAliases = {};

  String get profileName => _profileName;
  bool get renderOnSaveOnly => _renderOnSaveOnly;
  bool get loaded => _loaded;
  Map<String, List<String>> get projectTags => Map.unmodifiable(_projectTags);
  Map<String, String> get projectAliases => Map.unmodifiable(_projectAliases);

  List<String> get allTags {
    final tags = <String>{};
    for (final tagsList in _projectTags.values) {
      tags.addAll(tagsList);
    }
    return tags.toList()..sort();
  }

  List<String> tagsForProject(String path) =>
      List.unmodifiable(_projectTags[path] ?? []);

  String displayNameFor(String path) {
    final alias = _projectAliases[path];
    if (alias != null && alias.isNotEmpty) return alias;
    return path.split(RegExp(r'[\\/]')).last;
  }

  Future<void> setProjectAlias(String path, String alias) async {
    if (alias.isEmpty) {
      _projectAliases.remove(path);
    } else {
      _projectAliases[path] = alias;
    }
    notifyListeners();
    await _save();
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final dir = await _appSettingsDir();
      final file = File('${dir.path}${Platform.pathSeparator}settings.json');
      if (await file.exists()) {
        final data =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _profileName = data['profileName'] as String? ?? '';
        _renderOnSaveOnly = data['renderOnSaveOnly'] as bool? ?? false;
        final tags = data['projectTags'] as Map<String, dynamic>?;
        if (tags != null) {
          for (final entry in tags.entries) {
            _projectTags[entry.key] = List<String>.from(entry.value as List);
          }
        }
        final aliases = data['projectAliases'] as Map<String, dynamic>?;
        if (aliases != null) {
          for (final entry in aliases.entries) {
            _projectAliases[entry.key] = entry.value as String;
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

  Future<void> setRenderOnSaveOnly(bool value) async {
    _renderOnSaveOnly = value;
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
      await file.writeAsString(
        jsonEncode({
          'profileName': _profileName,
          'renderOnSaveOnly': _renderOnSaveOnly,
          'projectTags': _projectTags,
          'projectAliases': _projectAliases,
        }),
      );
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
