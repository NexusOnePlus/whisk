import 'package:flutter/material.dart';
import 'package:whisk/ui/features/editor/logic/syntax_highlighter.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_buffer.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class WhiskEditorController extends TextEditingController {
  WhiskEditorController({
    required String text,
    required this.environmentId,
    this.highlighter = const SyntaxHighlighter(),
  }) : buffer = WhiskEditorBuffer(text),
       super(text: text);

  final WhiskEditorBuffer buffer;
  final SyntaxHighlighter highlighter;
  String environmentId;
  List<EditorSelectionRange> secondarySelections = const [];

  final List<EditorTextOperation> _undoStack = [];
  final List<EditorTextOperation> _redoStack = [];

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    super.value = newValue;
    if (oldText != newValue.text) {
      buffer.setText(newValue.text);
    }
  }

  void setEnvironment(String id) {
    if (environmentId == id) return;
    environmentId = id;
    notifyListeners();
  }

  void setTextFromModel(String text) {
    if (this.text == text) return;
    value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    buffer.setText(text);
    _undoStack.clear();
    _redoStack.clear();
  }

  void replaceRange({
    required int start,
    required int end,
    required String replacement,
  }) {
    final operation = buffer.replace(start: start, end: end, text: replacement);
    _undoStack.add(operation);
    _redoStack.clear();
    value = value.copyWith(
      text: buffer.text,
      selection: TextSelection.collapsed(
        offset: operation.offset + replacement.length,
      ),
      composing: TextRange.empty,
    );
  }

  void setSecondarySelections(List<EditorSelectionRange> selections) {
    secondarySelections = List.unmodifiable(selections);
    notifyListeners();
  }

  bool undoEdit() {
    if (_undoStack.isEmpty) return false;
    final operation = _undoStack.removeLast();
    final inverse = operation.inverse;
    buffer.apply(inverse);
    _redoStack.add(operation);
    value = value.copyWith(
      text: buffer.text,
      selection: TextSelection.collapsed(
        offset: inverse.offset + inverse.insertedText.length,
      ),
      composing: TextRange.empty,
    );
    return true;
  }

  bool redoEdit() {
    if (_redoStack.isEmpty) return false;
    final operation = _redoStack.removeLast();
    buffer.apply(operation);
    _undoStack.add(operation);
    value = value.copyWith(
      text: buffer.text,
      selection: TextSelection.collapsed(
        offset: operation.offset + operation.insertedText.length,
      ),
      composing: TextRange.empty,
    );
    return true;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return highlighter.highlight(
      text: text,
      environmentId: environmentId,
      baseStyle: style ?? const TextStyle(),
    );
  }
}
