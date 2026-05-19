import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/editor/models/editor_text_position.dart';

class SourcePane extends StatefulWidget {
  const SourcePane({
    super.key,
    required this.environment,
    required this.controller,
    required this.focusNode,
    required this.revealRevision,
    this.revealOffset,
    required this.onChanged,
  });

  final EnvironmentKind environment;
  final WhiskEditorController controller;
  final FocusNode focusNode;
  final int revealRevision;
  final int? revealOffset;
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

  static double? _cachedCharWidth;
  static double get _charWidth {
    if (_cachedCharWidth != null) return _cachedCharWidth!;
    final tp = TextPainter(
      text: TextSpan(text: '-' * 100, style: _style),
      textDirection: TextDirection.ltr,
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
          final totalContentWidth = gutterWidth + 1 + editorContentWidth;
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
                    child: SizedBox(
                      width: totalContentWidth,
                      height: constraints.maxHeight,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LineGutter(
                              controller: widget.controller,
                              style: _style,
                            ),
                            const SizedBox(
                              width: 1,
                              child: ColoredBox(color: kBorder),
                            ),
                            _EditorStack(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              style: _style,
                              contentWidth: editorContentWidth,
                              viewportHeight: _viewportHeight,
                              onChanged: widget.onChanged,
                            ),
                          ],
                        ),
                      ),
                    ),
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
    required this.style,
    required this.contentWidth,
    required this.viewportHeight,
    required this.onChanged,
  });

  final WhiskEditorController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final double contentWidth;
  final double viewportHeight;
  final ValueChanged<String> onChanged;

  @override
  State<_EditorStack> createState() => _EditorStackState();
}

class _EditorStackState extends State<_EditorStack> {
  int? _dragAnchorOffset;
  bool _isMouseSelecting = false;

  @override
  Widget build(BuildContext context) {
    final lineHeight =
        (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.45);
    final contentHeight = (widget.controller.buffer.lineCount * lineHeight + 40)
        .clamp(widget.viewportHeight, double.infinity);

    return GestureDetector(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 24, 24),
                child: IgnorePointer(
                  child: EditableText(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    style: widget.style,
                    cursorColor: Colors.transparent,
                    backgroundCursorColor: kTextMuted,
                    selectionColor: Colors.transparent,
                    selectionControls: materialTextSelectionControls,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    maxLines: null,
                    minLines: null,
                    autocorrect: false,
                    enableSuggestions: false,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 24, 24),
                    child: CustomPaint(
                      painter: _EditorOverlayPainter(
                        controller: widget.controller,
                        style: widget.style,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      _dragAnchorOffset = offset;
      widget.controller.selection = TextSelection.collapsed(offset: offset);
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
      _stopSelecting();
    }
  }

  void _stopSelecting() {
    _isMouseSelecting = false;
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
    final line = (y / lineHeight).floor();

    final text = widget.controller.text;
    if (text.isEmpty) return 0;

    final buffer = widget.controller.buffer;
    if (line >= buffer.lineCount) return text.length;

    final lineText = buffer.lineText(line);
    final lineStartOffset = buffer.offsetForPosition(
      EditorTextPosition(line: line, column: 0),
    );

    final tp = TextPainter(
      text: TextSpan(text: lineText, style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final pos = tp.getPositionForOffset(Offset(x, 0.0));
    final column = pos.offset.clamp(0, lineText.length);

    return lineStartOffset + column;
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
  const _LineGutter({required this.controller, required this.style});

  final WhiskEditorController controller;
  final TextStyle style;

  static double widthFor(int lineCount) {
    final width = (lineCount.toString().length * 9 + 28).toDouble();
    return width.clamp(48, 86).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lineCount = controller.buffer.lineCount;
        final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.45);

        return Container(
          width: widthFor(lineCount),
          padding: const EdgeInsets.fromLTRB(10, 16, 8, 24),
          color: kAppBlack,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < lineCount; index++)
                SizedBox(
                  height: lineHeight,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: kTextMuted,
                      fontFamily: 'Consolas',
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EditorOverlayPainter extends CustomPainter {
  _EditorOverlayPainter({required this.controller, required this.style})
    : super(repaint: controller);

  final WhiskEditorController controller;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final text = controller.text;

    final textPainter = TextPainter(
      text: controller.highlighter.highlight(
        text: text,
        environmentId: controller.environmentId,
        baseStyle: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

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

    final selection = controller.selection;
    if (selection.isValid) {
      final base = selection.baseOffset.clamp(0, text.length);
      final extent = selection.extentOffset.clamp(0, text.length);
      if (base == extent) {
        _paintCaret(
          canvas,
          textPainter,
          offset: extent,
          height: lineHeight,
          paint: primaryCaretPaint,
        );
      } else {
        _paintSelection(
          canvas,
          textPainter,
          selection: TextSelection(baseOffset: base, extentOffset: extent),
          paint: primarySelectionPaint,
        );
      }
    }

    for (final selection in controller.secondarySelections) {
      if (selection.isCollapsed) {
        _paintCaret(
          canvas,
          textPainter,
          offset: selection.start.clamp(0, text.length),
          height: lineHeight,
          paint: secondaryCaretPaint,
        );
        continue;
      }

      _paintSelection(
        canvas,
        textPainter,
        selection: TextSelection(
          baseOffset: selection.start.clamp(0, text.length),
          extentOffset: selection.end.clamp(0, text.length),
        ),
        paint: secondarySelectionPaint,
      );
    }
  }

  void _paintSelection(
    Canvas canvas,
    TextPainter textPainter, {
    required TextSelection selection,
    required Paint paint,
  }) {
    final boxes = textPainter.getBoxesForSelection(selection);
    for (final box in boxes) {
      canvas.drawRect(box.toRect(), paint);
    }
  }

  void _paintCaret(
    Canvas canvas,
    TextPainter textPainter, {
    required int offset,
    required double height,
    required Paint paint,
  }) {
    final caret = textPainter.getOffsetForCaret(
      TextPosition(offset: offset),
      Rect.zero,
    );
    canvas.drawLine(caret, caret.translate(0, height), paint);
  }

  @override
  bool shouldRepaint(covariant _EditorOverlayPainter oldDelegate) {
    return oldDelegate.controller != controller || oldDelegate.style != style;
  }
}
