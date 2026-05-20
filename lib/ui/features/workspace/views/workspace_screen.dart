import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';
import 'package:whisk/ui/features/workspace/widgets/preview_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/sidebar.dart';
import 'package:whisk/ui/features/workspace/widgets/source_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/image_file_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/top_bar.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.viewModel,
    required this.onCloseWorkspace,
  });

  final WorkspaceViewModel viewModel;
  final VoidCallback onCloseWorkspace;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final WhiskEditorController _controller;
  late final FocusNode _editorFocusNode;
  late final TextEditingController _findController;
  late final FocusNode _findFocusNode;
  bool _findOpen = false;
  int _findCursor = 0;
  List<int> _findMatches = const [];
  int _revealRevision = 0;
  int? _revealOffset;
  Timer? _contentSyncTimer;
  Timer? _presenceSyncTimer;
  String? _pendingContent;
  StreamSubscription? _operationSubscription;
  StreamSubscription? _remoteTextSubscription;

  WorkspaceViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _controller = WhiskEditorController(
      text: viewModel.activeFile.content,
      environmentId: viewModel.selectedEnvironment.id,
    );
    _editorFocusNode = FocusNode();
    _findController = TextEditingController();
    _findFocusNode = FocusNode();
    _operationSubscription = _controller.textOperations.listen(
      viewModel.publishLocalTextOperations,
    );
    _remoteTextSubscription = viewModel.remoteTextUpdates?.listen(
      _handleRemoteTextUpdate,
    );
    _controller.addListener(_schedulePresenceSync);
    viewModel.addListener(_syncControllerFromModel);
  }

  @override
  void dispose() {
    _flushPendingContent();
    _contentSyncTimer?.cancel();
    _presenceSyncTimer?.cancel();
    _operationSubscription?.cancel();
    _remoteTextSubscription?.cancel();
    viewModel.removeListener(_syncControllerFromModel);
    _controller.removeListener(_schedulePresenceSync);
    _controller.dispose();
    _editorFocusNode.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  void _syncControllerFromModel() {
    if (_pendingContent != null) return;
    final content = viewModel.activeFile.content;
    _controller.setEnvironment(viewModel.selectedEnvironment.id);
    if (_controller.text == content) return;
    _controller.setTextFromModel(content);
  }

  void _handleEditorChanged(String content) {
    _pendingContent = content;
    _contentSyncTimer?.cancel();
    _contentSyncTimer = Timer(const Duration(milliseconds: 250), () {
      _flushPendingContent();
    });
  }

  void _handleRemoteTextUpdate(CollaborationTextUpdate update) {
    if (update.filePath == viewModel.activeFile.path) {
      _controller.applyRemoteOperation(update.operation);
      viewModel.updateActiveContentFromRemote(_controller.text);
      return;
    }
    viewModel.applyRemoteTextUpdate(update);
  }

  void _schedulePresenceSync() {
    _presenceSyncTimer?.cancel();
    _presenceSyncTimer = Timer(const Duration(milliseconds: 16), () {
      final selection = _controller.selection;
      if (!selection.isValid) return;
      viewModel.publishLocalCursor(
        offset: selection.extentOffset.clamp(0, _controller.text.length),
        selectionStart: selection.start == selection.end
            ? null
            : selection.start.clamp(0, _controller.text.length),
        selectionEnd: selection.start == selection.end
            ? null
            : selection.end.clamp(0, _controller.text.length),
      );
    });
  }

  void _flushPendingContent() {
    final content = _pendingContent;
    if (content == null) return;
    _pendingContent = null;
    if (!mounted && viewModel.activeFile.content == content) return;
    viewModel.updateActiveContent(content);
  }

  void _toggleFind() {
    final nextOpen = !_findOpen;
    setState(() {
      _findOpen = nextOpen;
      if (_findOpen) {
        _refreshFindMatches();
      } else {
        _controller.setSecondarySelections(const []);
      }
    });
    if (_findOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findFocusNode.requestFocus();
        _findController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _findController.text.length,
        );
      });
    }
  }

  void _refreshFindMatches() {
    final query = _findController.text;
    if (query.isEmpty) {
      _findMatches = const [];
      _findCursor = 0;
      _controller.setSecondarySelections(const []);
      return;
    }

    final content = _controller.text.toLowerCase();
    final needle = query.toLowerCase();
    final matches = <int>[];
    var start = 0;
    while (start <= content.length) {
      final index = content.indexOf(needle, start);
      if (index < 0) break;
      matches.add(index);
      start = index + needle.length;
    }
    _findMatches = matches;
    if (_findCursor >= _findMatches.length) _findCursor = 0;
    _selectCurrentFindMatch();
  }

  void _moveFind(int delta) {
    if (_findMatches.isEmpty) return;
    setState(() {
      _findCursor = (_findCursor + delta) % _findMatches.length;
      if (_findCursor < 0) _findCursor += _findMatches.length;
    });
    _selectCurrentFindMatch();
  }

  void _selectCurrentFindMatch() {
    if (_findMatches.isEmpty || _findController.text.isEmpty) return;
    final start = _findMatches[_findCursor];
    final end = start + _findController.text.length;
    _controller.selection = TextSelection(baseOffset: start, extentOffset: end);
    _controller.setSecondarySelections([
      EditorSelectionRange(baseOffset: start, extentOffset: end),
    ]);
    setState(() {
      _revealOffset = start;
      _revealRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
        ): () async {
          _flushPendingContent();
          await viewModel.saveActiveFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _toggleFind,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undoEdit,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _controller.redoEdit,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return Scaffold(
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 860;

                    if (isCompact) {
                      return Column(
                        children: [
                          TopBar(
                            file: viewModel.activeFile,
                            openFiles: viewModel.openFiles,
                            environment: viewModel.selectedEnvironment,
                            onSelectFile: viewModel.openFile,
                            onCloseWorkspace: widget.onCloseWorkspace,
                          ),
                          if (_findOpen)
                            _FindBar(
                              controller: _findController,
                              focusNode: _findFocusNode,
                              matchCount: _findMatches.length,
                              currentMatch: _findMatches.isEmpty
                                  ? 0
                                  : _findCursor + 1,
                              onChanged: (_) => setState(_refreshFindMatches),
                              onPrevious: () => _moveFind(-1),
                              onNext: () => _moveFind(1),
                              onClose: _toggleFind,
                            ),
                          Expanded(
                            child: _WorkspaceBody(
                              viewModel: viewModel,
                              controller: _controller,
                              editorFocusNode: _editorFocusNode,
                              onEditorChanged: _handleEditorChanged,
                              revealRevision: _revealRevision,
                              revealOffset: _revealOffset,
                              compact: true,
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const WorkspaceRail(),
                        Sidebar(
                          file: viewModel.activeFile,
                          files: viewModel.projectFiles,
                          environment: viewModel.selectedEnvironment,
                          onOpenFile: viewModel.openFile,
                          onNewFile: viewModel.createFile,
                          onDeleteFile: viewModel.deleteFile,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              TopBar(
                                file: viewModel.activeFile,
                                openFiles: viewModel.openFiles,
                                environment: viewModel.selectedEnvironment,
                                onSelectFile: viewModel.openFile,
                                onCloseWorkspace: widget.onCloseWorkspace,
                              ),
                              if (_findOpen)
                                _FindBar(
                                  controller: _findController,
                                  focusNode: _findFocusNode,
                                  matchCount: _findMatches.length,
                                  currentMatch: _findMatches.isEmpty
                                      ? 0
                                      : _findCursor + 1,
                                  onChanged: (_) =>
                                      setState(_refreshFindMatches),
                                  onPrevious: () => _moveFind(-1),
                                  onNext: () => _moveFind(1),
                                  onClose: _toggleFind,
                                ),
                              Expanded(
                                child: _WorkspaceBody(
                                  viewModel: viewModel,
                                  controller: _controller,
                                  editorFocusNode: _editorFocusNode,
                                  onEditorChanged: _handleEditorChanged,
                                  revealRevision: _revealRevision,
                                  revealOffset: _revealOffset,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FindBar extends StatelessWidget {
  const _FindBar({
    required this.controller,
    required this.focusNode,
    required this.matchCount,
    required this.currentMatch,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int matchCount;
  final int currentMatch;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 0,
      opacity: 0.8,
      blur: 32,
      child: Container(
        height: 42,
        padding: const EdgeInsets.fromLTRB(14, 4, 156, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: (_) => onNext(),
                style: const TextStyle(color: kTextPrimary, fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 28,
                  ),
                  hintText: 'Find in file',
                  hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
                  filled: true,
                  fillColor: kGlassBase.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: kAccentBlue),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$currentMatch / $matchCount',
              style: const TextStyle(color: kTextMuted, fontSize: 12),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Previous match',
              onPressed: onPrevious,
              icon: const Icon(Icons.keyboard_arrow_up),
              color: kTextSecondary,
              iconSize: 18,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              tooltip: 'Next match',
              onPressed: onNext,
              icon: const Icon(Icons.keyboard_arrow_down),
              color: kTextSecondary,
              iconSize: 18,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Close find',
              onPressed: onClose,
              icon: const Icon(Icons.close),
              color: kTextSecondary,
              iconSize: 17,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.viewModel,
    required this.controller,
    required this.editorFocusNode,
    required this.onEditorChanged,
    required this.revealRevision,
    this.revealOffset,
    this.compact = false,
  });

  final WorkspaceViewModel viewModel;
  final WhiskEditorController controller;
  final FocusNode editorFocusNode;
  final ValueChanged<String> onEditorChanged;
  final int revealRevision;
  final int? revealOffset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = viewModel.activeFile;
    final Widget editor;
    if (active.isImage) {
      editor = ImageFilePane(file: active);
    } else if (active.isPdf) {
      editor = Container(
        color: kAppBlack,
        child: PdfViewer.file(active.path, key: ValueKey(active.path)),
      );
    } else {
      final remotePeers = viewModel.collaborationPeers
          .where((peer) => peer.filePath == active.path)
          .toList(growable: false);
      editor = SourcePane(
        environment: viewModel.selectedEnvironment,
        controller: controller,
        focusNode: editorFocusNode,
        remotePeers: remotePeers,
        revealRevision: revealRevision,
        revealOffset: revealOffset,
        onChanged: onEditorChanged,
      );
    }
    final preview = PreviewPane(
      environment: viewModel.selectedEnvironment,
      result: viewModel.renderResult,
      onRender: viewModel.renderActiveFile,
    );

    final showPreview = !active.isImage && !active.isPdf;

    if (!showPreview) {
      return editor;
    }

    if (compact) {
      return Column(
        children: [
          Expanded(child: editor),
          const Divider(height: 1, color: kBorder),
          Expanded(child: preview),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: editor),
        const VerticalDivider(width: 1, color: kBorder),
        Expanded(child: preview),
      ],
    );
  }
}
