import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';

class SourcePane extends StatefulWidget {
  const SourcePane({
    super.key,
    required this.environment,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final EnvironmentKind environment;
  final WhiskEditorController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<SourcePane> createState() => _SourcePaneState();
}

class _SourcePaneState extends State<SourcePane> {
  late final ScrollController _verticalScrollController;
  late final ScrollController _horizontalScrollController;
  double _viewportHeight = 0;
  double _viewportWidth = 0;
  int? _lastSelectionExtent;

  static const _style = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 14,
    height: 1.45,
    color: kTextPrimary,
  );

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
    widget.controller.addListener(_revealSelection);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revealSelection);
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SourcePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_revealSelection);
    widget.controller.addListener(_revealSelection);
    _lastSelectionExtent = null;
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
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                physics: const ClampingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalContentWidth,
                  height: constraints.maxHeight,
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    interactive: true,
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
      _smoothScrollBy(controller, rawDelta * 1.65);
    });
  }

  void _smoothScrollBy(ScrollController controller, double delta) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealSelection() {
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    if (_lastSelectionExtent == selection.extentOffset) return;
    _lastSelectionExtent = selection.extentOffset;
    if (_viewportHeight <= 0 || _viewportWidth <= 0) return;

    final location = _lineAndColumnForOffset(
      widget.controller.text,
      selection.extentOffset,
    );
    final lineHeight = (_style.fontSize ?? 14) * (_style.height ?? 1.45);
    final targetY = location.line * lineHeight - (_viewportHeight * 0.35);
    final targetX = location.column * 8.4 - (_viewportWidth * 0.35);

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
    return (longest * 8.4 + 56).clamp(viewportWidth, double.infinity);
  }

  static ({int line, int column}) _lineAndColumnForOffset(
    String text,
    int offset,
  ) {
    final safeOffset = offset.clamp(0, text.length);
    var line = 0;
    var column = 0;
    for (var index = 0; index < safeOffset; index++) {
      if (text.codeUnitAt(index) == 10) {
        line++;
        column = 0;
      } else {
        column++;
      }
    }
    return (line: line, column: column);
  }
}

class _EditorStack extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.45);
    final contentHeight = (controller.buffer.lineCount * lineHeight + 40).clamp(
      viewportHeight,
      double.infinity,
    );

    return SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 24, 24),
            child: EditableText(
              controller: controller,
              focusNode: focusNode,
              style: style,
              cursorColor: kAccentBlue,
              backgroundCursorColor: kTextMuted,
              selectionColor: kAccentBlue.withValues(alpha: 0.28),
              selectionControls: materialTextSelectionControls,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: null,
              minLines: null,
              autocorrect: false,
              enableSuggestions: false,
              scrollPhysics: const NeverScrollableScrollPhysics(),
              onChanged: onChanged,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 24, 24),
                child: CustomPaint(
                  painter: _EditorOverlayPainter(
                    controller: controller,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    if (controller.secondarySelections.isEmpty) return;

    final textPainter = TextPainter(
      text: controller.highlighter.highlight(
        text: controller.text,
        environmentId: controller.environmentId,
        baseStyle: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final selectionPaint = Paint()
      ..color = kAccentAmber.withValues(alpha: 0.22);
    final caretPaint = Paint()
      ..color = kAccentAmber
      ..strokeWidth = 2;

    for (final selection in controller.secondarySelections) {
      if (selection.isCollapsed) {
        final caret = textPainter.getOffsetForCaret(
          TextPosition(offset: selection.start),
          Rect.zero,
        );
        canvas.drawLine(
          caret,
          caret.translate(0, (style.fontSize ?? 14) * (style.height ?? 1.45)),
          caretPaint,
        );
        continue;
      }

      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: selection.start, extentOffset: selection.end),
      );
      for (final box in boxes) {
        canvas.drawRect(box.toRect(), selectionPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorOverlayPainter oldDelegate) {
    return oldDelegate.controller != controller || oldDelegate.style != style;
  }
}
