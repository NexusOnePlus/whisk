import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  String _profileName = '';
  bool _loaded = false;

  String get profileName => _profileName;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final dir = await _appSettingsDir();
      final file = File('${dir.path}${Platform.pathSeparator}settings.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _profileName = data['profileName'] as String? ?? '';
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> setProfileName(String name) async {
    _profileName = name;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final dir = await _appSettingsDir();
      final file = File('${dir.path}${Platform.pathSeparator}settings.json');
      await file.writeAsString(jsonEncode({
        'profileName': _profileName,
      }));
    } catch (_) {}
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
