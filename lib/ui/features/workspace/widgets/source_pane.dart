import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/editor/models/editor_text_position.dart';

class SourcePane extends StatefulWidget {
  const SourcePane({
    super.key,
    required this.environment,
    required this.controller,
    required this.focusNode,
    required this.revealRevision,
    this.revealOffset,
    this.remotePeers = const [],
    required this.onChanged,
  });

  final EnvironmentKind environment;
  final WhiskEditorController controller;
  final FocusNode focusNode;
  final int revealRevision;
  final int? revealOffset;
  final List<CollaborationPeer> remotePeers;
  final ValueChanged<String> onChanged;

  @override
  State<SourcePane> createState() => _SourcePaneState();
}

class _SourcePaneState extends State<SourcePane> {
  late final ScrollController _verticalScrollController;
  late final ScrollController _horizontalScrollController;
  double _viewportHeight = 0;
  double _viewportWidth = 0;

  static const _style = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 14,
    height: 1.45,
    color: kTextPrimary,
  );
  static final _strutStyle = StrutStyle.fromTextStyle(
    _style,
    forceStrutHeight: true,
  );

  static double? _cachedCharWidth;
  static double get _charWidth {
    if (_cachedCharWidth != null) return _cachedCharWidth!;
    final tp = TextPainter(
      text: TextSpan(text: '-' * 100, style: _style),
      textDirection: TextDirection.ltr,
      strutStyle: _strutStyle,
    )..layout();
    _cachedCharWidth = tp.width / 100;
    return _cachedCharWidth!;
  }

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SourcePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealRevision != widget.revealRevision) {
      _revealOffset(widget.revealOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.setEnvironment(widget.environment.id);

    return Container(
      color: kAppBlack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutterWidth = _LineGutter.widthFor(
            widget.controller.buffer.lineCount,
          );
          final editorViewportWidth = (constraints.maxWidth - gutterWidth - 1)
              .clamp(240.0, double.infinity);
          final editorContentWidth = _contentWidthFor(
            widget.controller.text,
            editorViewportWidth,
          );
          _viewportHeight = constraints.maxHeight - 12;
          _viewportWidth = editorViewportWidth;

          return Listener(
            onPointerSignal: _handlePointerSignal,
            child: ScrollConfiguration(
              behavior: const _EditorScrollBehavior(),
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: _LineGutter(
                          controller: widget.controller,
                          scrollController: _verticalScrollController,
                          style: _style,
                          viewportHeight: _viewportHeight,
                        ),
                      ),
                      const SizedBox(
                        width: 1,
                        child: ColoredBox(color: kBorder),
                      ),
                      SizedBox(
                        width: editorViewportWidth,
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          interactive: true,
                          scrollbarOrientation: ScrollbarOrientation.bottom,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            physics: const ClampingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: _EditorStack(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              scrollController: _verticalScrollController,
                              style: _style,
                              contentWidth: editorContentWidth,
                              viewportHeight: _viewportHeight,
                              remotePeers: widget.remotePeers,
                              onChanged: widget.onChanged,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final delta = event.scrollDelta;
      final useHorizontal =
          delta.dx.abs() > delta.dy.abs() ||
          HardwareKeyboard.instance.isShiftPressed;
      final controller = useHorizontal
          ? _horizontalScrollController
          : _verticalScrollController;
      final rawDelta = useHorizontal
          ? (delta.dx.abs() > 0 ? delta.dx : delta.dy)
          : delta.dy;
      _scrollBy(controller, rawDelta);
    });
  }

  void _scrollBy(ScrollController controller, double delta) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;
    controller.jumpTo(target);
  }

  void _revealOffset(int? offset) {
    if (offset == null) return;
    if (_viewportHeight <= 0 || _viewportWidth <= 0) return;

    final location = widget.controller.buffer.positionForOffset(offset);
    final lineHeight = (_style.fontSize ?? 14) * (_style.height ?? 1.45);
    final targetY = location.line * lineHeight - (_viewportHeight * 0.35);
    final targetX = location.column * _charWidth - (_viewportWidth * 0.35);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToVisible(_verticalScrollController, targetY);
      _animateToVisible(_horizontalScrollController, targetX);
    });
  }

  void _animateToVisible(ScrollController controller, double target) {
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 24) return;
    controller.animateTo(
      clamped,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  static double _contentWidthFor(String text, double viewportWidth) {
    var longest = 1;
    var current = 0;
    for (var index = 0; index < text.length; index++) {
      if (text.codeUnitAt(index) == 10) {
        if (current > longest) longest = current;
        current = 0;
      } else {
        current++;
      }
    }
    if (current > longest) longest = current;
    return (longest * _charWidth + 56).clamp(viewportWidth, double.infinity);
  }
}

class _EditorStack extends StatefulWidget {
  const _EditorStack({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.style,
    required this.contentWidth,
    required this.viewportHeight,
    required this.remotePeers,
    required this.onChanged,
  });

  final WhiskEditorController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final TextStyle style;
  final double contentWidth;
  final double viewportHeight;
  final List<CollaborationPeer> remotePeers;
  final ValueChanged<String> onChanged;

  @override
  State<_EditorStack> createState() => _EditorStackState();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _SelectAllIntent extends Intent {
  const _SelectAllIntent();
}

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent({
    required this.direction,
    this.expand = false,
    this.byWord = false,
  });

  final EditorMoveDirection direction;
  final bool expand;
  final bool byWord;
}

class _EditorStackState extends State<_EditorStack> {
  int? _dragAnchorOffset;
  bool _isMouseSelecting = false;
  bool _isAdditiveSelection = false;

  @override
  Widget build(BuildContext context) {
    final lineHeight =
        (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.45);
    final contentHeight = (widget.controller.buffer.lineCount * lineHeight + 40)
        .clamp(widget.viewportHeight, double.infinity);

    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            const _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true):
            const _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft):
            const _MoveSelectionIntent(direction: EditorMoveDirection.left),
        SingleActivator(LogicalKeyboardKey.arrowRight):
            const _MoveSelectionIntent(direction: EditorMoveDirection.right),
        SingleActivator(LogicalKeyboardKey.arrowUp): const _MoveSelectionIntent(
          direction: EditorMoveDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            const _MoveSelectionIntent(direction: EditorMoveDirection.down),
        SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.left,
          expand: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowRight,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.right,
          expand: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowUp,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.up,
          expand: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowDown,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.down,
          expand: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          control: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.left,
          byWord: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowRight,
          control: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.right,
          byWord: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          control: true,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.left,
          expand: true,
          byWord: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.arrowRight,
          control: true,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.right,
          byWord: true,
          expand: true,
        ),
        SingleActivator(LogicalKeyboardKey.home): const _MoveSelectionIntent(
          direction: EditorMoveDirection.home,
        ),
        SingleActivator(LogicalKeyboardKey.end): const _MoveSelectionIntent(
          direction: EditorMoveDirection.end,
        ),
        SingleActivator(
          LogicalKeyboardKey.home,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.home,
          expand: true,
        ),
        SingleActivator(
          LogicalKeyboardKey.end,
          shift: true,
        ): const _MoveSelectionIntent(
          direction: EditorMoveDirection.end,
          expand: true,
        ),
        SingleActivator(LogicalKeyboardKey.pageUp): const _MoveSelectionIntent(
          direction: EditorMoveDirection.pageUp,
        ),
        SingleActivator(LogicalKeyboardKey.pageDown):
            const _MoveSelectionIntent(direction: EditorMoveDirection.pageDown),
        SingleActivator(LogicalKeyboardKey.keyA, control: true):
            const _SelectAllIntent(),
      },
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) => widget.controller.undoEdit(),
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) => widget.controller.redoEdit(),
          ),
          _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
            onInvoke: (intent) => widget.controller.moveSelections(
              intent.direction,
              expand: intent.expand,
              byWord: intent.byWord,
            ),
          ),
          _SelectAllIntent: CallbackAction<_SelectAllIntent>(
            onInvoke: (_) => widget.controller.selectAll(),
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: _handleDoubleTapDown,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: (_) => _stopSelecting(),
              child: SizedBox(
                width: widget.contentWidth,
                height: contentHeight,
                child: Stack(
                  children: [
                    // Lightweight IME bridge: handles character input directly
                    // instead of using EditableText (which serialized the entire
                    // document as JSON to the platform on every keystroke).
                    Focus(
                      focusNode: widget.focusNode,
                      onKeyEvent: _handleKeyEvent,
                      child: const SizedBox.shrink(),
                    ),
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 24, 24),
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                widget.scrollController,
                                widget.controller,
                              ]),
                              builder: (context, _) {
                                final lineHeight =
                                    (widget.style.fontSize ?? 14) *
                                    (widget.style.height ?? 1.45);
                                final scrollOffset =
                                    widget.scrollController.hasClients
                                    ? widget.scrollController.offset
                                    : 0.0;
                                final firstLine = (scrollOffset / lineHeight)
                                    .floor()
                                    .clamp(
                                      0,
                                      widget.controller.buffer.lineCount - 1,
                                    );
                                final lastLine =
                                    ((scrollOffset + widget.viewportHeight) /
                                            lineHeight)
                                        .ceil()
                                        .clamp(
                                          0,
                                          widget.controller.buffer.lineCount -
                                              1,
                                        );

                                final lineWidgets = <Widget>[];
                                for (
                                  var line = firstLine;
                                  line <= lastLine;
                                  line++
                                ) {
                                  final lineText = widget.controller.buffer
                                      .lineText(line);
                                  final span = widget.controller.highlighter
                                      .highlight(
                                        text: lineText,
                                        environmentId:
                                            widget.controller.environmentId,
                                        baseStyle: widget.style,
                                      );
                                  lineWidgets.add(
                                    Positioned(
                                      top: line * lineHeight,
                                      left: 0,
                                      right: 0,
                                      height: lineHeight,
                                      child: RichText(
                                        text: span,
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ),
                                  );
                                }

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ...lineWidgets,
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _EditorOverlayPainter(
                                          controller: widget.controller,
                                          style: widget.style,
                                          remotePeers: widget.remotePeers,
                                          visibleRange: (
                                            firstLine: firstLine,
                                            lastLine: lastLine,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Let Shortcuts widget handle these (undo/redo, arrows, home/end, select all)
    final key = event.logicalKey;
    if (isCtrl && key == LogicalKeyboardKey.keyZ) {
      return KeyEventResult.ignored;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyY) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      return KeyEventResult.ignored;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyA) {
      return KeyEventResult.ignored;
    }

    // Copy
    if (isCtrl && key == LogicalKeyboardKey.keyC) {
      _handleCopy();
      return KeyEventResult.handled;
    }
    // Cut
    if (isCtrl && key == LogicalKeyboardKey.keyX) {
      _handleCut();
      return KeyEventResult.handled;
    }
    // Paste
    if (isCtrl && key == LogicalKeyboardKey.keyV) {
      _handlePaste();
      return KeyEventResult.handled;
    }

    // Enter
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _insertText('\n');
      return KeyEventResult.handled;
    }

    // Tab
    if (key == LogicalKeyboardKey.tab) {
      _insertText('  ');
      return KeyEventResult.handled;
    }

    // Backspace
    if (key == LogicalKeyboardKey.backspace) {
      _handleBackspace(byWord: isCtrl);
      return KeyEventResult.handled;
    }

    // Delete
    if (key == LogicalKeyboardKey.delete) {
      _handleDelete(byWord: isCtrl);
      return KeyEventResult.handled;
    }

    // Character input (allow AltGr = Ctrl+Alt on Latin American keyboards)
    final isAltGr = isCtrl && isAlt;
    if (event.character != null && ((!isCtrl && !isAlt) || isAltGr)) {
      final ch = event.character!;
      if (ch.isNotEmpty && ch.codeUnitAt(0) >= 32) {
        _insertText(ch);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _insertText(String text) {
    final controller = widget.controller;
    final sel = controller.selection;
    final start = sel.start.clamp(0, controller.text.length);
    final end = sel.end.clamp(0, controller.text.length);
    final oldText = controller.text;
    final newText = oldText.replaceRange(start, end, text);
    final newOffset = (start + text.length).clamp(0, newText.length);

    // Set value via the setter so multi-cursor logic in
    // WhiskEditorController._applyWithCursors is triggered.
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
    widget.onChanged(controller.text);
  }

  void _handleBackspace({required bool byWord}) {
    final controller = widget.controller;
    final sel = controller.selection;
    if (sel.start != sel.end) {
      _insertText('');
    } else if (sel.start > 0) {
      final deleteStart = byWord
          ? _previousWordBoundary(sel.start)
          : sel.start - 1;
      final oldText = controller.text;
      final newText = oldText.replaceRange(deleteStart, sel.start, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: deleteStart.clamp(0, newText.length),
        ),
        composing: TextRange.empty,
      );
      widget.onChanged(controller.text);
    }
  }

  void _handleDelete({required bool byWord}) {
    final controller = widget.controller;
    final sel = controller.selection;
    if (sel.start != sel.end) {
      _insertText('');
    } else if (sel.start < controller.text.length) {
      final deleteEnd = byWord ? _nextWordBoundary(sel.start) : sel.start + 1;
      final oldText = controller.text;
      final newText = oldText.replaceRange(sel.start, deleteEnd, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start.clamp(0, newText.length),
        ),
        composing: TextRange.empty,
      );
      widget.onChanged(controller.text);
    }
  }

  int _previousWordBoundary(int offset) {
    final text = widget.controller.text;
    var cursor = offset.clamp(0, text.length);
    while (cursor > 0 && _isSpace(text.codeUnitAt(cursor - 1))) {
      cursor--;
    }
    while (cursor > 0 && !_isSpace(text.codeUnitAt(cursor - 1))) {
      cursor--;
    }
    return cursor;
  }

  int _nextWordBoundary(int offset) {
    final text = widget.controller.text;
    var cursor = offset.clamp(0, text.length);
    while (cursor < text.length && !_isSpace(text.codeUnitAt(cursor))) {
      cursor++;
    }
    while (cursor < text.length && _isSpace(text.codeUnitAt(cursor))) {
      cursor++;
    }
    return cursor;
  }

  bool _isSpace(int codeUnit) {
    return codeUnit == 9 || codeUnit == 10 || codeUnit == 13 || codeUnit == 32;
  }

  void _handleCopy() {
    final sel = widget.controller.selection;
    if (sel.start == sel.end) return;
    final text = widget.controller.text;
    final selected = text.substring(
      sel.start.clamp(0, text.length),
      sel.end.clamp(0, text.length),
    );
    Clipboard.setData(ClipboardData(text: selected));
  }

  void _handleCut() {
    _handleCopy();
    final sel = widget.controller.selection;
    if (sel.start != sel.end) {
      _insertText('');
    }
  }

  void _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _insertText(data.text!);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final offset = _offsetForLocalPosition(event.localPosition);
    widget.focusNode.requestFocus();
    if (event.buttons == kPrimaryMouseButton) {
      _isMouseSelecting = true;
      _isAdditiveSelection = HardwareKeyboard.instance.isControlPressed;
      _dragAnchorOffset = offset;
      final text = widget.controller.text;
      final atBreak = offset < text.length && text.codeUnitAt(offset) == 10;
      final sel = TextSelection(
        baseOffset: offset,
        extentOffset: offset,
        affinity: atBreak ? TextAffinity.upstream : TextAffinity.downstream,
      );
      if (HardwareKeyboard.instance.isShiftPressed) {
        final current = widget.controller.selection;
        widget.controller.selection = TextSelection(
          baseOffset: current.baseOffset,
          extentOffset: offset,
          affinity: sel.affinity,
        );
      } else if (!_isAdditiveSelection) {
        widget.controller.clearActiveCursors();
        widget.controller.selection = sel;
      } else {
        widget.controller.selection = sel;
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isMouseSelecting ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final anchor =
        _dragAnchorOffset ?? _offsetForLocalPosition(event.localPosition);
    final extent = _offsetForLocalPosition(event.localPosition);
    widget.controller.selection = TextSelection(
      baseOffset: anchor,
      extentOffset: extent,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      if (_isAdditiveSelection) {
        final selection = widget.controller.selection;
        final range = EditorSelectionRange(
          baseOffset: selection.baseOffset,
          extentOffset: selection.extentOffset,
        );
        if (range.isCollapsed) {
          widget.controller.toggleActiveCursor(range.baseOffset);
        } else {
          widget.controller.setActiveSelections([
            ...widget.controller.activeCursors,
            range,
          ]);
        }
        widget.controller.selection = TextSelection.collapsed(
          offset: range.extentOffset,
        );
      }
      _stopSelecting();
    }
  }

  void _stopSelecting() {
    _isMouseSelecting = false;
    _isAdditiveSelection = false;
    _dragAnchorOffset = null;
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    final offset = _offsetForLocalPosition(details.localPosition);
    final range = _wordRangeAt(offset);
    _stopSelecting();
    widget.focusNode.requestFocus();
    widget.controller.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );
  }

  int _offsetForLocalPosition(Offset localPosition) {
    final lineHeight =
        (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.45);
    final x = (localPosition.dx - 18).clamp(0.0, double.infinity);
    final y = (localPosition.dy - 16).clamp(0.0, double.infinity);
    final line = (y / lineHeight).floor().clamp(
      0,
      widget.controller.buffer.lineCount - 1,
    );

    final lineText = widget.controller.buffer.lineText(line);
    final charWidth = _SourcePaneState._charWidth;
    final column = (x / charWidth).round().clamp(0, lineText.length);

    return widget.controller.buffer.offsetForPosition(
      EditorTextPosition(line: line, column: column),
    );
  }

  ({int start, int end}) _wordRangeAt(int offset) {
    final text = widget.controller.text;
    if (text.isEmpty) return (start: 0, end: 0);
    var start = offset.clamp(0, text.length);
    var end = start;
    if (start == text.length && start > 0) {
      start--;
      end = text.length;
    }

    while (start > 0 && _isWordCodeUnit(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length && _isWordCodeUnit(text.codeUnitAt(end))) {
      end++;
    }
    return (start: start, end: end);
  }

  bool _isWordCodeUnit(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 95 ||
        codeUnit == 92;
  }
}

class _EditorScrollBehavior extends MaterialScrollBehavior {
  const _EditorScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

class _LineGutter extends StatelessWidget {
  const _LineGutter({
    required this.controller,
    required this.scrollController,
    required this.style,
    required this.viewportHeight,
  });

  final WhiskEditorController controller;
  final ScrollController scrollController;
  final TextStyle style;
  final double viewportHeight;

  static double widthFor(int lineCount) {
    final width = (lineCount.toString().length * 9 + 28).toDouble();
    return width.clamp(48, 86).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, scrollController]),
      builder: (context, _) {
        final lineCount = controller.buffer.lineCount;
        final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.45);
        final scrollOffset = scrollController.hasClients
            ? scrollController.offset
            : 0.0;
        final visible = controller.buffer.visibleLineRange(
          scrollOffset: scrollOffset,
          viewportHeight: viewportHeight,
          lineHeight: lineHeight,
        );
        final topPadding = 16 + visible.firstLine * lineHeight;
        final bottomPadding =
            ((lineCount - visible.lastLine - 1).clamp(0, lineCount) *
                lineHeight) +
            24;

        return Container(
          width: widthFor(lineCount),
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
          color: kAppBlack,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(height: topPadding),
              for (
                var index = visible.firstLine;
                index <= visible.lastLine;
                index++
              )
                SizedBox(
                  height: lineHeight,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      height: 1.45,
                      color: kTextMuted,
                      fontFamily: 'Consolas',
                      fontSize: 14,
                    ),
                  ),
                ),
              SizedBox(height: bottomPadding),
            ],
          ),
        );
      },
    );
  }
}

class _EditorOverlayPainter extends CustomPainter {
  _EditorOverlayPainter({
    required this.controller,
    required this.style,
    required this.remotePeers,
    required this.visibleRange,
  }) : super(repaint: controller);

  final WhiskEditorController controller;
  final TextStyle style;
  final List<CollaborationPeer> remotePeers;
  final ({int firstLine, int lastLine}) visibleRange;

  @override
  void paint(Canvas canvas, Size size) {
    final text = controller.text;
    final primarySelectionPaint = Paint()
      ..color = kAccentBlue.withValues(alpha: 0.24);
    final primaryCaretPaint = Paint()
      ..color = kAccentBlue
      ..strokeWidth = 1.6;
    final secondarySelectionPaint = Paint()
      ..color = kAccentAmber.withValues(alpha: 0.22);
    final secondaryCaretPaint = Paint()
      ..color = kAccentAmber
      ..strokeWidth = 2;
    final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.45);
    final charWidth = _SourcePaneState._charWidth;

    final selection = controller.selection;
    if (selection.isValid) {
      final base = selection.baseOffset.clamp(0, text.length);
      final extent = selection.extentOffset.clamp(0, text.length);
      if (base == extent) {
        final pos = controller.buffer.positionForOffset(extent);
        if (pos.line >= visibleRange.firstLine &&
            pos.line <= visibleRange.lastLine) {
          _paintCaret(
            canvas,
            offset: extent,
            affinity: selection.affinity,
            lineHeight: lineHeight,
            charWidth: charWidth,
            height: lineHeight,
            paint: primaryCaretPaint,
          );
        }
      } else {
        final startPos = controller.buffer.positionForOffset(base);
        final endPos = controller.buffer.positionForOffset(extent);
        if (endPos.line >= visibleRange.firstLine &&
            startPos.line <= visibleRange.lastLine) {
          _paintSelection(
            canvas,
            selection: TextSelection(baseOffset: base, extentOffset: extent),
            lineHeight: lineHeight,
            charWidth: charWidth,
            paint: primarySelectionPaint,
          );
        }
      }
    }

    for (final cursor in controller.activeCursors) {
      if (cursor.isCollapsed) {
        final offset = cursor.start.clamp(0, text.length);
        final pos = controller.buffer.positionForOffset(offset);
        if (pos.line < visibleRange.firstLine ||
            pos.line > visibleRange.lastLine) {
          continue;
        }

        final atBreak = offset < text.length && text.codeUnitAt(offset) == 10;
        _paintCaret(
          canvas,
          offset: offset,
          affinity: atBreak ? TextAffinity.upstream : TextAffinity.downstream,
          lineHeight: lineHeight,
          charWidth: charWidth,
          height: lineHeight,
          paint: primaryCaretPaint,
        );
      } else {
        final start = cursor.start.clamp(0, text.length);
        final end = cursor.end.clamp(0, text.length);
        final startPos = controller.buffer.positionForOffset(start);
        final endPos = controller.buffer.positionForOffset(end);
        if (endPos.line < visibleRange.firstLine ||
            startPos.line > visibleRange.lastLine) {
          continue;
        }

        _paintSelection(
          canvas,
          selection: TextSelection(baseOffset: start, extentOffset: end),
          lineHeight: lineHeight,
          charWidth: charWidth,
          paint: primarySelectionPaint,
        );
      }
    }

    for (final selection in controller.secondarySelections) {
      if (selection.isCollapsed) {
        final offset = selection.start.clamp(0, text.length);
        final pos = controller.buffer.positionForOffset(offset);
        if (pos.line < visibleRange.firstLine ||
            pos.line > visibleRange.lastLine) {
          continue;
        }

        final atBreak = offset < text.length && text.codeUnitAt(offset) == 10;
        _paintCaret(
          canvas,
          offset: offset,
          affinity: atBreak ? TextAffinity.upstream : TextAffinity.downstream,
          lineHeight: lineHeight,
          charWidth: charWidth,
          height: lineHeight,
          paint: secondaryCaretPaint,
        );
        continue;
      }

      final start = selection.start.clamp(0, text.length);
      final end = selection.end.clamp(0, text.length);
      final startPos = controller.buffer.positionForOffset(start);
      final endPos = controller.buffer.positionForOffset(end);
      if (endPos.line < visibleRange.firstLine ||
          startPos.line > visibleRange.lastLine) {
        continue;
      }

      _paintSelection(
        canvas,
        selection: TextSelection(baseOffset: start, extentOffset: end),
        lineHeight: lineHeight,
        charWidth: charWidth,
        paint: secondarySelectionPaint,
      );
    }

    for (final peer in remotePeers) {
      final cursorOffset = peer.cursorOffset;
      if (cursorOffset == null) continue;
      final color = peer.color;
      final selectionStart = peer.selectionStart;
      final selectionEnd = peer.selectionEnd;
      if (selectionStart != null &&
          selectionEnd != null &&
          selectionStart != selectionEnd) {
        final start = selectionStart.clamp(0, text.length);
        final end = selectionEnd.clamp(0, text.length);
        final startPos = controller.buffer.positionForOffset(start);
        final endPos = controller.buffer.positionForOffset(end);
        if (endPos.line >= visibleRange.firstLine &&
            startPos.line <= visibleRange.lastLine) {
          _paintSelection(
            canvas,
            selection: TextSelection(baseOffset: start, extentOffset: end),
            lineHeight: lineHeight,
            charWidth: charWidth,
            paint: Paint()..color = color.withValues(alpha: 0.22),
          );
        }
      }

      final offset = cursorOffset.clamp(0, text.length);
      final position = controller.buffer.positionForOffset(offset);
      if (position.line < visibleRange.firstLine ||
          position.line > visibleRange.lastLine) {
        continue;
      }
      _paintCaret(
        canvas,
        offset: offset,
        affinity: TextAffinity.downstream,
        lineHeight: lineHeight,
        charWidth: charWidth,
        height: lineHeight,
        paint: Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      _paintPeerLabel(
        canvas,
        peer: peer,
        lineHeight: lineHeight,
        charWidth: charWidth,
        color: color,
      );
    }
  }

  void _paintSelection(
    Canvas canvas, {
    required TextSelection selection,
    required double lineHeight,
    required double charWidth,
    required Paint paint,
  }) {
    final start = selection.start;
    final end = selection.end;
    if (start == end) return;
    final startPosition = controller.buffer.positionForOffset(start);
    final endPosition = controller.buffer.positionForOffset(end);

    for (var line = startPosition.line; line <= endPosition.line; line++) {
      final lineStart = controller.buffer.lineStarts[line];
      final lineText = controller.buffer.lineText(line);
      final lineEnd = lineStart + lineText.length;
      final startColumn = line == startPosition.line ? startPosition.column : 0;
      final endColumn = line == endPosition.line
          ? endPosition.column
          : lineEnd - lineStart;
      if (endColumn <= startColumn) continue;

      final left = startColumn * charWidth;
      final width = (endColumn - startColumn) * charWidth;

      canvas.drawRect(
        Rect.fromLTWH(left, line * lineHeight, width, lineHeight),
        paint,
      );
    }
  }

  void _paintCaret(
    Canvas canvas, {
    required int offset,
    required TextAffinity affinity,
    required double lineHeight,
    required double charWidth,
    required double height,
    required Paint paint,
  }) {
    var position = controller.buffer.positionForOffset(offset);
    if (affinity == TextAffinity.upstream &&
        offset < controller.text.length &&
        controller.text.codeUnitAt(offset) == 10) {
      position = EditorTextPosition(
        line: position.line,
        column: controller.buffer.lineText(position.line).length,
      );
    }

    final caretX = position.column * charWidth;
    final caret = Offset(caretX, position.line * lineHeight);
    canvas.drawLine(caret, caret.translate(0, height), paint);
  }

  void _paintPeerLabel(
    Canvas canvas, {
    required CollaborationPeer peer,
    required double lineHeight,
    required double charWidth,
    required Color color,
  }) {
    final offset = peer.cursorOffset?.clamp(0, controller.text.length);
    if (offset == null) return;
    final position = controller.buffer.positionForOffset(offset);
    final label = peer.name.trim().isEmpty ? 'Peer' : peer.name.trim();
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: kAppBlack,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final caretX = position.column * charWidth;
    final top = (position.line * lineHeight - 14).clamp(0.0, double.infinity);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(caretX, top, textPainter.width + 8, 14),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    textPainter.paint(canvas, Offset(caretX + 4, top + 2));
  }

  @override
  bool shouldRepaint(covariant _EditorOverlayPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.style != style ||
        oldDelegate.remotePeers != remotePeers ||
        oldDelegate.visibleRange != visibleRange;
  }
}
