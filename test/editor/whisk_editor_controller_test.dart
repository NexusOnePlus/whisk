import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

void main() {
  test('applies text input to active cursors as one undoable transaction', () {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.toggleActiveCursor(5);

    controller.value = controller.value.copyWith(
      text: 'aXbc\ndef',
      selection: const TextSelection.collapsed(offset: 2),
      composing: TextRange.empty,
    );

    expect(controller.text, 'aXbc\ndXef');
    expect(controller.selection.extentOffset, 2);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [7]);

    controller.value = controller.value.copyWith(
      text: 'abc\ndXef',
      selection: const TextSelection.collapsed(offset: 1),
      composing: TextRange.empty,
    );

    expect(controller.text, 'abc\ndef');
    expect(controller.selection.extentOffset, 1);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [5]);

    expect(controller.undoEdit(), isTrue);
    expect(controller.text, 'aXbc\ndXef');
    expect(controller.selection.extentOffset, 2);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [7]);

    expect(controller.undoEdit(), isTrue);
    expect(controller.text, 'abc\ndef');
    expect(controller.selection.extentOffset, 1);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [5]);

    expect(controller.redoEdit(), isTrue);
    expect(controller.text, 'aXbc\ndXef');
    expect(controller.selection.extentOffset, 2);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [7]);
  });

  test('applies delete to every active cursor', () {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.toggleActiveCursor(5);

    controller.value = controller.value.copyWith(
      text: 'ac\ndef',
      selection: const TextSelection.collapsed(offset: 1),
      composing: TextRange.empty,
    );

    expect(controller.text, 'ac\ndf');
    expect(controller.selection.extentOffset, 1);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [4]);
  });

  test('pastes multiline text at every active cursor', () {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.toggleActiveCursor(5);

    controller.value = controller.value.copyWith(
      text: 'aX\nYbc\ndef',
      selection: const TextSelection.collapsed(offset: 4),
      composing: TextRange.empty,
    );

    expect(controller.text, 'aX\nYbc\ndX\nYef');
    expect(controller.selection.extentOffset, 4);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [11]);
  });

  test('replaces active selections with primary selection input', () {
    final controller = WhiskEditorController(
      text: 'one two\nred blue',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
    controller.setActiveSelections([
      const EditorSelectionRange(baseOffset: 8, extentOffset: 11),
    ]);

    controller.value = controller.value.copyWith(
      text: 'one X\nred blue',
      selection: const TextSelection.collapsed(offset: 5),
      composing: TextRange.empty,
    );

    expect(controller.text, 'one X\nX blue');
    expect(controller.selection.extentOffset, 5);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [7]);

    expect(controller.undoEdit(), isTrue);
    expect(controller.text, 'one two\nred blue');
    expect(controller.selection.extentOffset, 7);
    expect(controller.activeCursors.map((cursor) => cursor.start), [8]);
    expect(controller.activeCursors.map((cursor) => cursor.end), [11]);
  });

  test('does not replicate composing IME input to active cursors', () {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.toggleActiveCursor(5);

    controller.value = controller.value.copyWith(
      text: 'aXbc\ndef',
      selection: const TextSelection.collapsed(offset: 2),
      composing: const TextRange(start: 1, end: 2),
    );

    expect(controller.text, 'aXbc\ndef');
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [5]);
  });

  test('groups continuous single-cursor typing into one undo entry', () {
    final controller = WhiskEditorController(text: '', environmentId: 'latex');

    controller.value = controller.value.copyWith(
      text: 'a',
      selection: const TextSelection.collapsed(offset: 1),
      composing: TextRange.empty,
    );
    controller.value = controller.value.copyWith(
      text: 'ab',
      selection: const TextSelection.collapsed(offset: 2),
      composing: TextRange.empty,
    );
    controller.value = controller.value.copyWith(
      text: 'abc',
      selection: const TextSelection.collapsed(offset: 3),
      composing: TextRange.empty,
    );

    expect(controller.undoEdit(), isTrue);
    expect(controller.text, '');
    expect(controller.undoEdit(), isFalse);
  });

  test('moves primary and active cursors with arrow keys model', () {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.toggleActiveCursor(5);

    controller.moveSelections(
      EditorMoveDirection.right,
      expand: false,
      byWord: false,
    );

    expect(controller.selection.extentOffset, 2);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [6]);

    controller.moveSelections(
      EditorMoveDirection.left,
      expand: true,
      byWord: false,
    );

    expect(controller.selection.baseOffset, 2);
    expect(controller.selection.extentOffset, 1);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [6]);
    expect(controller.activeCursors.map((cursor) => cursor.extentOffset), [5]);
  });

  test('moves all cursors vertically by preserving columns', () {
    final controller = WhiskEditorController(
      text: 'abcd\nwxyz',
      environmentId: 'latex',
    );

    controller.selection = const TextSelection.collapsed(offset: 2);
    controller.toggleActiveCursor(7);

    controller.moveSelections(
      EditorMoveDirection.down,
      expand: false,
      byWord: false,
    );

    expect(controller.selection.extentOffset, 7);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [7]);

    controller.moveSelections(
      EditorMoveDirection.up,
      expand: false,
      byWord: false,
    );

    expect(controller.selection.extentOffset, 2);
    expect(controller.activeCursors.map((cursor) => cursor.baseOffset), [2]);
  });

  test('emits local operations for multi-cursor edits', () async {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );
    final emitted = <List<EditorTextOperation>>[];
    final sub = controller.textOperations.listen(emitted.add);

    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.toggleActiveCursor(5);
    controller.value = controller.value.copyWith(
      text: 'aXbc\ndef',
      selection: const TextSelection.collapsed(offset: 2),
      composing: TextRange.empty,
    );

    await Future<void>.delayed(Duration.zero);
    expect(emitted, hasLength(1));
    expect(emitted.single.map((op) => op.offset), [5, 1]);
    expect(emitted.single.map((op) => op.insertedText), ['X', 'X']);
    await sub.cancel();
    controller.dispose();
  });

  test('applies remote operations without emitting local operations', () async {
    final controller = WhiskEditorController(
      text: 'abc\ndef',
      environmentId: 'latex',
    );
    final emitted = <List<EditorTextOperation>>[];
    final sub = controller.textOperations.listen(emitted.add);

    controller.selection = const TextSelection.collapsed(offset: 5);
    controller.applyRemoteOperation(
      const EditorTextOperation(offset: 1, deletedText: '', insertedText: 'X'),
    );

    await Future<void>.delayed(Duration.zero);
    expect(controller.text, 'aXbc\ndef');
    expect(controller.selection.extentOffset, 6);
    expect(emitted, isEmpty);
    expect(controller.undoEdit(), isFalse);
    await sub.cancel();
    controller.dispose();
  });
}
