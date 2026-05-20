import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/data/services/document_render_service.dart';
import 'package:whisk/data/services/file_watcher_service.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({
    EnvironmentCatalog catalog = const EnvironmentCatalog(),
    this.collaborationService,
    this._renderService = const DocumentRenderService(),
    this._watcherService = const FileWatcherService(),
    this._openService = const ProjectOpenService(),
    WhiskFile? initialFile,
    List<WhiskFile>? projectFiles,
  }) : _environments = catalog.listEnvironments() {
    _activeFile = initialFile ?? _fileForEnvironment(_environments.first);
    _projectFiles = projectFiles ?? [_activeFile];
    _openFiles = [_activeFile];
    _initWatcher();
    _initCollaboration();
  }

  final CollaborationService? collaborationService;
  final DocumentRenderService _renderService;
  final FileWatcherService _watcherService;
  final ProjectOpenService _openService;
  StreamSubscription? _watcherSubscription;
  StreamSubscription? _peersSubscription;
  List<CollaborationPeer> _collaborationPeers = const [];
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
  List<CollaborationPeer> get collaborationPeers =>
      List.unmodifiable(_collaborationPeers);
  Stream<CollaborationTextUpdate>? get remoteTextUpdates =>
      collaborationService?.remoteTextUpdates;

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
    if (next.content.isEmpty &&
        next.projectRoot != null &&
        !next.isImage &&
        !next.isPdf) {
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
    _syncActiveFileSnapshot();
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
    if (_activeFile.projectRoot == null) return;

    final file = File(_activeFile.path);
    await file.parent.create(recursive: true);
    await file.writeAsString(_activeFile.content);
    _activeFile = _activeFile.copyWith(isDirty: false);
    _replaceFileInLists(_activeFile);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watcherSubscription?.cancel();
    _peersSubscription?.cancel();
    super.dispose();
  }

  void _initWatcher() {
    final root = _activeFile.projectRoot;
    if (root == null) return;

    _watcherSubscription = _watcherService.watchDirectory(root).listen((event) {
      if (_disposed) return;
      _refreshProjectFiles();
    });
  }

  void _initCollaboration() {
    final service = collaborationService;
    if (service == null) return;

    _peersSubscription = service.peers.listen((peers) {
      if (_disposed) return;
      _collaborationPeers = peers;
      notifyListeners();
    });

    unawaited(_connectCollaboration(service));
  }

  Future<void> _connectCollaboration(CollaborationService service) async {
    final workspaceId = _activeFile.projectRoot ?? _activeFile.path;
    await service.connect(workspaceId);
    if (_disposed) return;
    await _syncActiveFileSnapshot();
  }

  Future<void> _refreshProjectFiles() async {
    final root = _activeFile.projectRoot;
    if (root == null) return;

    final files = await _openService.listDirectoryFiles(root);
    if (_disposed) return;

    _projectFiles = files
        .map(
          (file) => WhiskFile(
            path: file.path,
            name: file.uri.pathSegments.last,
            extension: _openService.extensionOf(file.path),
            content: file.path == _activeFile.path ? _activeFile.content : '',
            projectRoot: root,
          ),
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> createFile(String fileName) async {
    if (_disposed) return;
    final root = _activeFile.projectRoot;
    if (root == null) return;

    final path = '$root${Platform.pathSeparator}$fileName';
    final file = File(path);
    if (await file.exists()) return;

    await file.create(recursive: true);
    await _refreshProjectFiles();
  }

  Future<void> deleteFile(WhiskFile whiskFile) async {
    if (_disposed) return;
    final file = File(whiskFile.path);
    if (await file.exists()) {
      await file.delete();
    }

    _openFiles = _openFiles.where((f) => f.path != whiskFile.path).toList();

    if (_activeFile.path == whiskFile.path) {
      if (_openFiles.isNotEmpty) {
        _activeFile = _openFiles.first;
      } else {
        await _refreshProjectFiles();
        if (_projectFiles.isNotEmpty) {
          final firstRemaining = _projectFiles.firstWhere(
            (f) => f.path != whiskFile.path,
            orElse: () => _projectFiles.first,
          );
          _activeFile = firstRemaining;
        }
      }
    }

    await _refreshProjectFiles();
  }

  void _replaceFileInLists(WhiskFile replacement) {
    _projectFiles = _projectFiles
        .map((file) => file.path == replacement.path ? replacement : file)
        .toList(growable: false);
    _openFiles = _openFiles
        .map((file) => file.path == replacement.path ? replacement : file)
        .toList(growable: false);
  }

  void publishLocalTextOperations(List<EditorTextOperation> operations) {
    final service = collaborationService;
    if (service == null || operations.isEmpty) return;
    for (final operation in operations) {
      service.broadcastTextChange(
        CollaborationTextUpdate(
          peerId: service.peerId,
          filePath: _activeFile.path,
          operation: operation,
        ),
      );
    }
  }

  void publishLocalCursor({
    required int offset,
    int? selectionStart,
    int? selectionEnd,
  }) {
    collaborationService?.updateLocalCursor(
      _activeFile.path,
      offset,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
    );
  }

  void applyRemoteTextUpdate(CollaborationTextUpdate update) {
    if (update.filePath == _activeFile.path) return;
    WhiskFile applyTo(WhiskFile file) {
      if (file.path != update.filePath) return file;
      return file.copyWith(
        content: _applyOperation(file.content, update.operation),
        isDirty: true,
      );
    }

    _projectFiles = _projectFiles.map(applyTo).toList(growable: false);
    _openFiles = _openFiles.map(applyTo).toList(growable: false);
    notifyListeners();
  }

  void updateActiveContentFromRemote(String content) {
    if (_disposed) return;
    if (content == _activeFile.content) return;
    _activeFile = _activeFile.copyWith(content: content, isDirty: true);
    _replaceFileInLists(_activeFile);
    notifyListeners();
  }

  Future<void> _syncActiveFileSnapshot() async {
    final service = collaborationService;
    if (service == null) return;
    final activePath = _activeFile.path;
    final snapshot = await service.loadFileSnapshot(
      activePath,
      _activeFile.content,
    );
    if (_disposed || _activeFile.path != activePath) return;
    if (snapshot == _activeFile.content) return;
    _activeFile = _activeFile.copyWith(content: snapshot, isDirty: true);
    _replaceFileInLists(_activeFile);
    notifyListeners();
  }

  String _applyOperation(String text, EditorTextOperation operation) {
    final start = operation.offset.clamp(0, text.length);
    final end = (start + operation.deletedText.length).clamp(
      start,
      text.length,
    );
    return text.replaceRange(start, end, operation.insertedText);
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
