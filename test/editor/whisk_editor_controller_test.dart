import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';

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
}
