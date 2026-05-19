class EditorTextOperation {
  const EditorTextOperation({
    required this.offset,
    required this.deletedText,
    required this.insertedText,
  });

  final int offset;
  final String deletedText;
  final String insertedText;

  EditorTextOperation get inverse {
    return EditorTextOperation(
      offset: offset,
      deletedText: insertedText,
      insertedText: deletedText,
    );
  }
}
