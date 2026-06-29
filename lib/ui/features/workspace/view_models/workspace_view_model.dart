import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisk/ui/features/workspace/widgets/log_viewer_dialog.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/data/services/document_render_service.dart';
import 'package:whisk/data/services/file_watcher_service.dart';
import 'package:whisk/data/services/invite_codec.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/domain/models/collaboration_file_entry.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

// ignore_for_file: unawaited_futures

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({
    EnvironmentCatalog catalog = const EnvironmentCatalog(),
    this.collaborationService,
    this.renderService = const DocumentRenderService(),
    this._watcherService = const FileWatcherService(),
    this._openService = const ProjectOpenService(),
    WhiskFile? initialFile,
    List<WhiskFile>? projectFiles,
    int startEnvIndex = 0,
  }) : _environments = catalog.listEnvironments() {
    _selectedEnvironmentIndex = startEnvIndex.clamp(0, _environments.length - 1);
    if (initialFile != null) {
      _activeFile = initialFile;
      _projectFiles = projectFiles ?? [initialFile];
    } else {
      _draftRootPath = computeDraftRootPath(_environments[_selectedEnvironmentIndex]);
      _activeFile = _fileForEnvironment(_environments[_selectedEnvironmentIndex]);
      _projectFiles = [_activeFile];
    }
    _openFiles = [_activeFile];
    _initWatcher();
    _initCollaboration();
    _publishWorkspaceManifest();
    if (_isInlineEnv) {
      _renderResult = RenderResult.success(content: _activeFile.content);
    }
  }

  final CollaborationService? collaborationService;
  final DocumentRenderService renderService;
  final FileWatcherService _watcherService;
  final ProjectOpenService _openService;
  StreamSubscription? _watcherSubscription;
  StreamSubscription? _peersSubscription;
  StreamSubscription? _remoteFilesSubscription;
  Directory? _guestDraftRoot;
  final _guestDraftPaths = <String, String>{};
  String? _draftRootPath;
  List<CollaborationPeer> _collaborationPeers = const [];
  final List<EnvironmentKind> _environments;
  late WhiskFile _activeFile;
  late List<WhiskFile> _projectFiles;
  late List<WhiskFile> _openFiles;
  int _selectedEnvironmentIndex = 0;
  RenderResult _renderResult = const RenderResult.idle();
  final Map<String, RenderResult> _renderResultCache = {};
  String? _pinnedPreviewPath;
  var _disposed = false;

  List<EnvironmentKind> get environments => List.unmodifiable(_environments);
  List<WhiskFile> get projectFiles => List.unmodifiable(_projectFiles);
  List<WhiskFile> get openFiles => List.unmodifiable(_openFiles);
  int get selectedEnvironmentIndex => _selectedEnvironmentIndex;
  EnvironmentKind get selectedEnvironment =>
      _environments[_selectedEnvironmentIndex];
  WhiskFile get activeFile => _activeFile;
  RenderResult get renderResult {
    if (_pinnedPreviewPath != null) {
      return _renderResultCache[_pinnedPreviewPath] ??
          const RenderResult.idle();
    }
    return _renderResult;
  }

  bool get isPreviewPinned => _pinnedPreviewPath != null;
  String? get pinnedPreviewPath => _pinnedPreviewPath;

  void setPreviewPin(String? filePath) {
    _pinnedPreviewPath = filePath;
    notifyListeners();
  }

  bool get _isInlineEnv {
    final id = selectedEnvironment.id;
    return id == 'notes' || id == 'mermaid';
  }
  List<CollaborationPeer> get collaborationPeers =>
      List.unmodifiable(_collaborationPeers);
  Stream<CollaborationTextUpdate>? get remoteTextUpdates =>
      collaborationService?.remoteTextUpdates;

  void selectEnvironment(int index) {
    if (_disposed) return;
    if (index == _selectedEnvironmentIndex) return;
    if (index < 0 || index >= _environments.length) return;

    _renderResultCache[_activeFile.path] = _renderResult;

    _selectedEnvironmentIndex = index;
    _activeFile = _fileForEnvironment(_environments[index]);
    _projectFiles = [_activeFile];
    _openFiles = [_activeFile];
    if (_isInlineEnv) {
      _renderResult = RenderResult.success(content: _activeFile.content);
    } else {
      _renderResult = _renderResultCache[_activeFile.path] ??
          const RenderResult.idle();
    }
    notifyListeners();
  }

  void updateActiveContent(String content) {
    if (_disposed) return;
    if (content == _activeFile.content) return;
    _activeFile = _activeFile.copyWith(content: content, isDirty: true);
    _replaceFileInLists(_activeFile);
    _renderResultCache.remove(_activeFile.path);
    final envId = selectedEnvironment.id;
    if (envId == 'notes' || envId == 'mermaid') {
      _renderResult = RenderResult.success(content: content);
    }
    notifyListeners();
  }

  static int _envIndexForExtension(String ext) {
    return switch (ext) {
      '.tex' => 0,
      '.typ' => 1,
      '.mmd' => 2,
      '.md' => 3,
      _ => -1,
    };
  }

  Future<void> openFile(WhiskFile file) async {
    if (_disposed) return;
    await saveActiveFile();
    if (_disposed) return;

    LogBuffer.writeln(LogCategory.system,
        '[${DateTime.now().toString().substring(11, 19)}] Open file: ${file.name}');

    _renderResultCache[_activeFile.path] = _renderResult;

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

    final envIndex = _envIndexForExtension(next.extension);
    if (envIndex >= 0) {
      _selectedEnvironmentIndex = envIndex;
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
    if (_isInlineEnv) {
      _renderResult = RenderResult.success(content: next.content);
    } else {
      _renderResult = _renderResultCache[next.path] ??
          const RenderResult.idle();
    }
    _syncActiveFileSnapshot();
    notifyListeners();
  }

  Future<void> renderActiveFile() async {
    if (_disposed) return;
    if (_renderResult.isRendering) return;

    final envId = selectedEnvironment.id;
    if (envId == 'notes' || envId == 'mermaid') {
      _renderResult = RenderResult.success(content: _activeFile.content);
      notifyListeners();
      return;
    }

    final cached = _renderResultCache[_activeFile.path];
    if (cached != null && cached.state == RenderState.success && cached.pdfPath != null) {
      final pdfFile = File(cached.pdfPath!);
      final sourceFile = File(_activeFile.path);
      final pdfExists = await pdfFile.exists();
      final sourceExists = await sourceFile.exists();
      if (pdfExists && sourceExists) {
        final pdfMod = await pdfFile.lastModified();
        final srcMod = await sourceFile.lastModified();
        if (!pdfMod.isBefore(srcMod)) {
          _renderResult = cached;
          notifyListeners();
          return;
        }
      }
    }

    final existingPdf = await _findExistingPdf(_activeFile.path, envId);
    if (existingPdf != null) {
      final result = RenderResult.success(pdfPath: existingPdf, engine: envId, log: '');
      _renderResult = result;
      _renderResultCache[_activeFile.path] = result;
      notifyListeners();
      return;
    }

    LogBuffer.writeln(LogCategory.render,
        '[${DateTime.now().toString().substring(11, 19)}] Rendering ${_activeFile.name} ($envId)...');

    _renderResult = const RenderResult.rendering();
    notifyListeners();

    final activeFile = _activeFile;
    final renderFile = _canWriteLocalFiles
        ? activeFile
        : await _guestDraftFileFor(activeFile);
    final environmentId = selectedEnvironment.id;
    final result = await renderService.render(
      environmentId: selectedEnvironment.id,
      file: renderFile,
    );
    if (_disposed || _activeFile.path != activeFile.path) return;
    if (selectedEnvironment.id != environmentId) return;

    _renderResult = result;
    _renderResultCache[_activeFile.path] = result;
    notifyListeners();

    final status = result.state == RenderState.success
        ? 'OK'
        : result.state == RenderState.failed
            ? 'FAILED'
            : '?';
    LogBuffer.writeln(LogCategory.render,
        '[${DateTime.now().toString().substring(11, 19)}] Render result: $status (${result.engine ?? envId})');

    if (result.log.isNotEmpty) {
      final lines = result.log.trim().split('\n');
      final truncated = lines.length > 50
          ? [...lines.take(50), '... (${lines.length - 50} more lines)']
          : lines;
      for (final line in truncated) {
        LogBuffer.writeln(LogCategory.render, '  $line');
      }
    }
  }

  Future<void> saveActiveFile() async {
    if (_disposed) return;
    if (!_activeFile.isDirty) return;
    if (_activeFile.projectRoot == null) return;
    if (!_canWriteLocalFiles) {
      await _saveGuestDraftActiveFile();
      _activeFile = _activeFile.copyWith(isDirty: false);
      _replaceFileInLists(_activeFile);
      notifyListeners();
      return;
    }

    final file = File(_activeFile.path);
    await file.parent.create(recursive: true);
    await file.writeAsString(_activeFile.content);
    _activeFile = _activeFile.copyWith(isDirty: false);
    _replaceFileInLists(_activeFile);
    notifyListeners();
  }

  Future<String?> createCollaborationInvite() async {
    if (_disposed) return null;
    return collaborationService?.createInvite();
  }

  Future<bool> joinCollaborationInvite(String invite) async {
    if (_disposed) return false;
    final payload = InviteCodec.decode(invite);
    final ticket = payload?.ticket ?? invite;
    final joined =
        await (collaborationService?.joinInvite(ticket) ?? Future.value(false));
    if (joined) notifyListeners();
    return joined;
  }

  @override
  void dispose() {
    _disposed = true;
    _watcherSubscription?.cancel();
    _peersSubscription?.cancel();
    _remoteFilesSubscription?.cancel();
    final service = collaborationService;
    if (service != null) {
      service.disconnect();
    }
    final guestDraftRoot = _guestDraftRoot;
    if (guestDraftRoot != null) {
      unawaited(_deleteGuestDraftRoot(guestDraftRoot));
    }
    super.dispose();
  }

  void _initWatcher() {
    final root = _activeFile.projectRoot;
    if (root == null) return;

    if (_draftRootPath != null) {
      Directory(_draftRootPath!).createSync(recursive: true);
    }

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
    _remoteFilesSubscription = service.remoteFiles.listen((files) {
      if (_disposed) return;
      _applyRemoteFileManifest(files);
    });

    unawaited(_connectCollaboration(service));
  }

  Future<void> _connectCollaboration(CollaborationService service) async {
    final workspaceId = _activeFile.projectRoot ?? _activeFile.path;
    await service.connect(workspaceId);
    if (_disposed) return;
    _publishWorkspaceManifest();
    await _syncActiveFileSnapshot();
  }

  Future<void> _refreshProjectFiles() async {
    final root = _activeFile.projectRoot;
    if (root == null) return;

    final entries = await _openService.listDirectoryEntries(root);
    if (_disposed) return;

    final folders = <WhiskFile>[];
    for (final entity in entries) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (_isIgnoredFolder(name)) continue;
      if (entity is Directory) {
        folders.add(WhiskFile(
          path: entity.path,
          name: name,
          extension: '',
          content: '',
          projectRoot: root,
          isDirectory: true,
        ));
      }
    }

    final diskFiles = await _openService.listDirectoryFiles(root);
    if (_disposed) return;

    final files = diskFiles
        .map(
          (file) => WhiskFile(
            path: file.path,
            name: file.path.split(Platform.pathSeparator).last,
            extension: _openService.extensionOf(file.path),
            content: file.path == _activeFile.path ? _activeFile.content : '',
            projectRoot: root,
          ),
        )
        .toList(growable: false);

    _projectFiles = [...folders, ...files];
    _publishWorkspaceManifest();
    notifyListeners();
  }

  static bool _isIgnoredFolder(String name) {
    return name == '.git' || name == '.whisk' || name == 'build';
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

  Future<void> createFolder(String folderName) async {
    if (_disposed) return;
    final root = _activeFile.projectRoot;
    if (root == null) return;

    final path = '$root${Platform.pathSeparator}$folderName';
    final dir = Directory(path);
    if (await dir.exists()) return;

    await dir.create(recursive: true);
    await _refreshProjectFiles();
  }

  void closeFile(WhiskFile whiskFile) {
    if (_disposed) return;
    final wasActive = _activeFile.path == whiskFile.path;
    _openFiles = _openFiles.where((f) => f.path != whiskFile.path).toList();
    if (_openFiles.isEmpty) {
      _activeFile = WhiskFile.empty;
      _renderResult = const RenderResult.idle();
      notifyListeners();
      return;
    }
    if (wasActive) {
      unawaited(openFile(_openFiles.first));
    } else {
      notifyListeners();
    }
  }

  Future<void> deleteFile(WhiskFile whiskFile) async {
    if (_disposed) return;
    final file = File(whiskFile.path);
    if (await file.exists()) {
      await file.delete();
    }

    if (_pinnedPreviewPath == whiskFile.path) {
      _pinnedPreviewPath = null;
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
    _publishWorkspaceManifest();
  }

  void _publishWorkspaceManifest() {
    collaborationService?.updateWorkspaceFiles([
      for (final file in _projectFiles)
        CollaborationFileEntry(
          path: file.path,
          name: file.name,
          extension: file.extension,
        ),
    ]);
  }

  void _applyRemoteFileManifest(List<CollaborationFileEntry> files) {
    if (_canWriteLocalFiles || files.isEmpty) return;
    final previousFiles = {for (final file in _projectFiles) file.path: file};
    final nextFiles = [
      for (final file in files)
        WhiskFile(
          path: file.path,
          name: file.name,
          extension: file.extension,
          content: previousFiles[file.path]?.content ?? '',
        ),
    ];
    _projectFiles = nextFiles;
    _openFiles = [
      for (final file in _openFiles)
        if (nextFiles.any((candidate) => candidate.path == file.path)) file,
    ];
    if (_openFiles.isEmpty && nextFiles.isNotEmpty) {
      _openFiles = [nextFiles.first];
    }
    if (!nextFiles.any((file) => file.path == _activeFile.path)) {
      _activeFile = nextFiles.first;
      unawaited(_syncActiveFileSnapshot());
    }
    notifyListeners();
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
    _renderResultCache.remove(_activeFile.path);
    if (_isInlineEnv) {
      _renderResult = RenderResult.success(content: content);
    }
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

  bool get _canWriteLocalFiles =>
      collaborationService?.canWriteLocalFiles ?? true;

  Future<void> _saveGuestDraftActiveFile() async {
    final file = File(await _guestDraftPathFor(_activeFile));
    await file.parent.create(recursive: true);
    await file.writeAsString(_activeFile.content);
  }

  Future<WhiskFile> _guestDraftFileFor(WhiskFile file) async {
    final draftPath = await _guestDraftPathFor(file);
    return WhiskFile(
      path: draftPath,
      name: file.name,
      extension: file.extension,
      content: file.content,
      projectRoot: _guestDraftRoot!.path,
      isDirty: file.isDirty,
    );
  }

  Future<String> _guestDraftPathFor(WhiskFile file) async {
    final existing = _guestDraftPaths[file.path];
    if (existing != null) return existing;

    final root =
        _guestDraftRoot ??
        await Directory.systemTemp.createTemp('whisk-guest-');
    _guestDraftRoot = root;
    final encodedPath = base64Url.encode(utf8.encode(file.path));
    final boundedPath = encodedPath.length <= 96
        ? encodedPath
        : encodedPath.substring(encodedPath.length - 96);
    final draftPath =
        '${root.path}${Platform.pathSeparator}$boundedPath-${file.name}';
    _guestDraftPaths[file.path] = draftPath;
    return draftPath;
  }

  @visibleForTesting
  String? guestDraftPathForTesting(String filePath) =>
      _guestDraftPaths[filePath];

  Future<void> _deleteGuestDraftRoot(Directory root) async {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup for session-local guest drafts.
    }
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
    final root = _draftRootPath;
    if (root != null) {
      return WhiskFile(
        path: '$root${Platform.pathSeparator}main${environment.extension}',
        name: 'main${environment.extension}',
        extension: environment.extension,
        content: environment.sample,
        projectRoot: root,
      );
    }
    return WhiskFile(
      path: 'sample/${environment.id}${environment.extension}',
      name: '${environment.id}${environment.extension}',
      extension: environment.extension,
      content: environment.sample,
    );
  }

  static String computeDraftRootPath(EnvironmentKind env) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}.${_pad(now.minute)}.${_pad(now.second)}';
    return '${_documentsPath()}${Platform.pathSeparator}Whisk Docs'
        '${Platform.pathSeparator}${env.name} $timestamp';
  }

  Future<String?> _findExistingPdf(String sourcePath, String envId) async {
    final projectRoot = _activeFile.projectRoot;
    if (projectRoot == null) return null;

    final pdfName = sourcePath.split(Platform.pathSeparator).last.replaceAll(
      RegExp(r'\.(typ|tex)$', caseSensitive: false),
      '.pdf',
    );
    final pdfPath = '$projectRoot${Platform.pathSeparator}.whisk'
        '${Platform.pathSeparator}build${Platform.pathSeparator}$envId'
        '${Platform.pathSeparator}$pdfName';
    final pdfFile = File(pdfPath);
    if (await pdfFile.exists()) return pdfPath;
    return null;
  }

  static String _documentsPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) return '$userProfile\\Documents';
      final homeDrive = Platform.environment['HOMEDRIVE'] ?? 'C:';
      final homePath = Platform.environment['HOMEPATH'] ?? '\\Users\\Default';
      return '$homeDrive$homePath\\Documents';
    }
    final home = Platform.environment['HOME'];
    if (home != null) return '$home/Documents';
    return Directory.systemTemp.path;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
