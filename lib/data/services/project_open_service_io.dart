import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/domain/models/whisk_project.dart';

class ProjectOpenService {
  const ProjectOpenService();

  Future<WhiskProject?> pickProject() async {
    final rootPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Open project',
    );
    if (rootPath == null) return null;

    final root = Directory(rootPath);
    final files = await _listProjectFiles(root);
    if (files.isEmpty) return null;

    final entry = _findEntryFile(root, files);
    final content = entry != null ? await entry.readAsString() : '';

    final entryFile = WhiskFile(
      path: entry?.path ?? files.first.path,
      name: entry != null
          ? entry.uri.pathSegments.last
          : files.first.uri.pathSegments.last,
      extension: extensionOf(entry?.path ?? files.first.path),
      content: content,
      projectRoot: root.path,
    );

    return WhiskProject(
      rootPath: root.path,
      files: files
          .map(
            (file) => WhiskFile(
              path: file.path,
              name: file.uri.pathSegments.last,
              extension: extensionOf(file.path),
              content: file.path == entry?.path ? content : '',
              projectRoot: root.path,
            ),
          )
          .toList(growable: false),
      entryFile: entryFile,
    );
  }

  File? _findEntryFile(Directory root, List<File> files) {
    const priority = ['.tex', '.typ', '.mmd', '.md'];
    for (final ext in priority) {
      final main = File('${root.path}${Platform.pathSeparator}main$ext');
      if (files.any((f) => f.path == main.path)) return main;
      final found = files.where((f) => f.path.endsWith(ext)).firstOrNull;
      if (found != null) return found;
    }
    return files.firstOrNull;
  }

  Future<WhiskProject?> pickProjectFromPath(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return null;

    final files = await _listProjectFiles(root);
    if (files.isEmpty) return null;

    final entry = _findEntryFile(root, files);
    final content = entry != null ? await entry.readAsString() : '';

    final entryFile = WhiskFile(
      path: entry?.path ?? files.first.path,
      name: entry != null
          ? entry.uri.pathSegments.last
          : files.first.uri.pathSegments.last,
      extension: extensionOf(entry?.path ?? files.first.path),
      content: content,
      projectRoot: root.path,
    );

    final allFiles = <WhiskFile>[];
    for (final file in files) {
      final ext = extensionOf(file.path);
      final isText = const {
        '.tex', '.bib', '.sty', '.cls', '.typ', '.md', '.mmd',
      }.contains(ext);
      final fileContent = file.path == entry?.path
          ? content
          : isText ? await file.readAsString() : '';
      allFiles.add(WhiskFile(
        path: file.path,
        name: file.uri.pathSegments.last,
        extension: ext,
        content: fileContent,
        projectRoot: root.path,
      ));
    }

    return WhiskProject(
      rootPath: root.path,
      files: allFiles,
      entryFile: entryFile,
    );
  }

  Future<List<File>> listDirectoryFiles(String path) =>
      _listProjectFiles(Directory(path));

  Future<List<File>> _listProjectFiles(Directory root) async {
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (_isIgnoredPath(root.path, entity.path)) continue;
      if (!_isRenderableProjectFile(entity.path)) continue;
      files.add(entity);
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<List<FileSystemEntity>> listDirectoryEntries(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return const [];
    final entries = <FileSystemEntity>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (_isIgnoredPath(path, entity.path)) continue;
      entries.add(entity);
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  bool _isIgnoredPath(String rootPath, String path) {
    final relative = path.substring(rootPath.length);
    return relative.contains(
          '${Platform.pathSeparator}.git${Platform.pathSeparator}',
        ) ||
        relative.contains(
          '${Platform.pathSeparator}.whisk${Platform.pathSeparator}',
        ) ||
        relative.contains(
          '${Platform.pathSeparator}build${Platform.pathSeparator}',
        );
  }

  bool _isRenderableProjectFile(String path) {
    final extension = extensionOf(path);
    return const {
      '.tex',
      '.bib',
      '.sty',
      '.cls',
      '.typ',
      '.md',
      '.mmd',
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.bmp',
      '.webp',
      '.pdf',
    }.contains(extension);
  }

  String extensionOf(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final index = name.lastIndexOf('.');
    if (index < 0) return '';
    return name.substring(index).toLowerCase();
  }
}
