import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Collection {
  Collection({required this.name, List<String>? projects})
      : projects = projects ?? [];

  final String name;
  final List<String> projects;

  Map<String, dynamic> toJson() => {'name': name, 'projects': projects};

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        name: json['name'] as String,
        projects: (json['projects'] as List<dynamic>?)
                ?.cast<String>() ??
            [],
      );
}

class CollectionService extends ChangeNotifier {
  static const _fileName = 'collections.json';
  static CollectionService? _instance;
  static CollectionService get instance => _instance ??= CollectionService._();
  CollectionService._();

  List<Collection> _collections = [];

  List<Collection> get collections => List.unmodifiable(_collections);

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
      _collections = [];
      notifyListeners();
      return;
    }
    try {
      final contents = await file.readAsString();
      final list = json.decode(contents) as List<dynamic>;
      _collections = list
          .map((e) => Collection.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      _collections = [];
    }
    notifyListeners();
  }

  String? collectionForProject(String projectPath) {
    for (final c in _collections) {
      if (c.projects.contains(projectPath)) return c.name;
    }
    return null;
  }

  List<String> projectsIn(String collectionName) {
    final c = _collections.where((c) => c.name == collectionName);
    return c.isEmpty ? [] : c.first.projects;
  }

  Future<void> addCollection(String name) async {
    if (_collections.any((c) => c.name == name)) return;
    _collections = [..._collections, Collection(name: name)];
    await _persist();
    notifyListeners();
  }

  Future<void> removeCollection(String name) async {
    _collections = [for (final c in _collections) if (c.name != name) c];
    await _persist();
    notifyListeners();
  }

  Future<void> renameCollection(String oldName, String newName) async {
    _collections = [
      for (final c in _collections)
        if (c.name == oldName)
          Collection(name: newName, projects: c.projects)
        else
          c,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> addToCollection(String collectionName, String projectPath) async {
    // Remove from any other collection first
    _collections = [
      for (final c in _collections)
        if (c.name == collectionName)
          Collection(
            name: c.name,
            projects: [...c.projects, projectPath],
          )
        else
          Collection(
            name: c.name,
            projects: [for (final p in c.projects) if (p != projectPath) p],
          ),
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> removeFromCollection(String collectionName, String projectPath) async {
    _collections = [
      for (final c in _collections)
        if (c.name == collectionName)
          Collection(
            name: c.name,
            projects: [for (final p in c.projects) if (p != projectPath) p],
          )
        else
          c,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final filePath = await _filePath;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final contents = json.encode([for (final c in _collections) c.toJson()]);
    await file.writeAsString(contents);
  }
}
