import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UpdateService {
  UpdateService({
    http.Client? httpClient,
    this.repoOwner = 'YOUR_USERNAME',
    this.repoName = 'whisk',
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String repoOwner;
  final String repoName;

  String get _apiUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await _http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'whisk',
        },
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final version = tagName.replaceFirst(RegExp(r'^v'), '');
      if (version.isEmpty || version == currentVersion) return null;

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String? ?? '';
          if (name.contains('setup') || name.endsWith('.exe')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      return UpdateInfo(
        version: version,
        downloadUrl: downloadUrl,
        releaseUrl: data['html_url'] as String?,
        body: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseUrl,
    this.body,
  });

  final String version;
  final String? downloadUrl;
  final String? releaseUrl;
  final String? body;
}
