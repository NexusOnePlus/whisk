import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/data/services/document_render_service.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({
    EnvironmentCatalog catalog = const EnvironmentCatalog(),
    this._renderService = const DocumentRenderService(),
    WhiskFile? initialFile,
    List<WhiskFile>? projectFiles,
  }) : _environments = catalog.listEnvironments() {
    _activeFile = initialFile ?? _fileForEnvironment(_environments.first);
    _projectFiles = projectFiles ?? [_activeFile];
    _openFiles = [_activeFile];
  }

  final DocumentRenderService _renderService;
  final List<EnvironmentKind> _environments;
  late WhiskFile _activeFile;
  late List<WhiskFile> _projectFiles;
  late List<WhiskFile> _openFiles;
  int _selectedEnvironmentIndex = 0;
  RenderResult _renderResult = const RenderResult.idle();
  var _disposed = false;

  List<EnvironmentKind> get environments => List.unmodifiable(_environments);
  List<WhiskFile> get projectFiles => List.unmodifiable(_projectFiles);
  List<WhiskFile> get openFiles => List.unmodifiable(_openFiles);
  int get selectedEnvironmentIndex => _selectedEnvironmentIndex;
  EnvironmentKind get selectedEnvironment =>
      _environments[_selectedEnvironmentIndex];
  WhiskFile get activeFile => _activeFile;
  RenderResult get renderResult => _renderResult;

  void selectEnvironment(int index) {
    if (_disposed) return;
    if (index == _selectedEnvironmentIndex) return;
    if (index < 0 || index >= _environments.length) return;

    _selectedEnvironmentIndex = index;
    _activeFile = _fileForEnvironment(_environments[index]);
    _projectFiles = [_activeFile];
    _openFiles = [_activeFile];
    _renderResult = const RenderResult.idle();
    notifyListeners();
  }

  void updateActiveContent(String content) {
    if (_disposed) return;
    if (content == _activeFile.content) return;
    _activeFile = _activeFile.copyWith(content: content, isDirty: true);
    _replaceFileInLists(_activeFile);
    notifyListeners();
  }

  Future<void> openFile(WhiskFile file) async {
    if (_disposed) return;
    await saveActiveFile();
    if (_disposed) return;

    var next = file;
    if (next.content.isEmpty && next.projectRoot != null) {
      final diskFile = File(next.path);
      if (await diskFile.exists()) {
        next = next.copyWith(content: await diskFile.readAsString());
      }
    }

    _activeFile = next;
    if (!_openFiles.any((file) => file.path == next.path)) {
      _openFiles = [..._openFiles, next];
    } else {
      _openFiles = _openFiles
          .map((file) => file.path == next.path ? next : file)
          .toList(growable: false);
    }
    _replaceFileInLists(next);
    _renderResult = const RenderResult.idle();
    notifyListeners();
  }

  Future<void> renderActiveFile() async {
    if (_disposed) return;
    if (_renderResult.isRendering) return;

    _renderResult = const RenderResult.rendering();
    notifyListeners();

    final activeFile = _activeFile;
    final environmentId = selectedEnvironment.id;
    final result = await _renderService.render(
      environmentId: selectedEnvironment.id,
      file: activeFile,
    );
    if (_disposed || _activeFile.path != activeFile.path) return;
    if (selectedEnvironment.id != environmentId) return;

    _renderResult = result;
    notifyListeners();
  }

  Future<void> saveActiveFile() async {
    if (_disposed) return;
    if (!_activeFile.isDirty) return;

    final file = File(_activeFile.path);
    await file.writeAsString(_activeFile.content);
    _activeFile = _activeFile.copyWith(isDirty: false);
    _replaceFileInLists(_activeFile);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _replaceFileInLists(WhiskFile replacement) {
    _projectFiles = _projectFiles
        .map((file) => file.path == replacement.path ? replacement : file)
        .toList(growable: false);
    _openFiles = _openFiles
        .map((file) => file.path == replacement.path ? replacement : file)
        .toList(growable: false);
  }

  WhiskFile _fileForEnvironment(EnvironmentKind environment) {
    return WhiskFile(
      path: 'sample/${environment.id}${environment.extension}',
      name: '${environment.id}${environment.extension}',
      extension: environment.extension,
      content: environment.sample,
    );
  }
}
