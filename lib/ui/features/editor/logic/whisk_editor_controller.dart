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
  var _applyingHistory = false;
  var _syncingFromModel = false;

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    if (!_applyingHistory && !_syncingFromModel && oldText != newValue.text) {
      final operation = _operationFromDiff(oldText, newValue.text);
      if (operation != null) {
        _undoStack.add(operation);
        _redoStack.clear();
      }
    }
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
    _syncingFromModel = true;
    try {
      value = value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
      buffer.setText(text);
      _undoStack.clear();
      _redoStack.clear();
    } finally {
      _syncingFromModel = false;
    }
  }

  void replaceRange({
    required int start,
    required int end,
    required String replacement,
  }) {
    final operation = buffer.replace(start: start, end: end, text: replacement);
    _undoStack.add(operation);
    _redoStack.clear();
    _setValueFromBuffer(selectionOffset: operation.offset + replacement.length);
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
    _setValueFromBuffer(
      selectionOffset: inverse.offset + inverse.insertedText.length,
    );
    return true;
  }

  bool redoEdit() {
    if (_redoStack.isEmpty) return false;
    final operation = _redoStack.removeLast();
    buffer.apply(operation);
    _undoStack.add(operation);
    _setValueFromBuffer(
      selectionOffset: operation.offset + operation.insertedText.length,
    );
    return true;
  }

  void _setValueFromBuffer({required int selectionOffset}) {
    _applyingHistory = true;
    try {
      value = value.copyWith(
        text: buffer.text,
        selection: TextSelection.collapsed(
          offset: selectionOffset.clamp(0, buffer.length),
        ),
        composing: TextRange.empty,
      );
    } finally {
      _applyingHistory = false;
    }
  }

  EditorTextOperation? _operationFromDiff(String oldText, String newText) {
    if (oldText == newText) return null;

    var prefix = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLength &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    return EditorTextOperation(
      offset: prefix,
      deletedText: oldText.substring(prefix, oldSuffix),
      insertedText: newText.substring(prefix, newSuffix),
    );
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
