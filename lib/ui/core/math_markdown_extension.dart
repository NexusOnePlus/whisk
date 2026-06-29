import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class MathBlockElement extends md.Element {
  MathBlockElement(this.tex) : super('math_block', [md.Text(tex)]);
  final String tex;
}

class MathInlineElement extends md.Element {
  MathInlineElement(this.tex) : super('math_inline', [md.Text(tex)]);
  final String tex;
}

class BlockMathSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final buffer = StringBuffer();
    final content = parser.current.content.trimLeft();
    if (content.startsWith(r'$$') &&
        content.endsWith(r'$$') &&
        content.length > 4) {
      buffer.write(content.substring(2, content.length - 2));
      parser.advance();
      return MathBlockElement(buffer.toString().trim());
    }

    parser.advance();
    while (!parser.isDone) {
      final line = parser.current;
      if (line.content.trimRight().endsWith(r'$$')) {
        final before =
            line.content.trimRight().substring(0, line.content.trimRight().length - 2);
        if (before.isNotEmpty) buffer.writeln(before);
        parser.advance();
        return MathBlockElement(buffer.toString().trim());
      }
      buffer.writeln(line.content);
      parser.advance();
    }

    return MathBlockElement(buffer.toString().trim());
  }
}

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1);
    if (tex == null || tex.trim().isEmpty) return false;
    parser.addNode(MathInlineElement(tex.trim()));
    return true;
  }
}

class MathBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element is MathBlockElement) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Center(
            child: Math.tex(
              element.tex,
              textStyle: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      );
    }
    return null;
  }
}

class MathInlineBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element is MathInlineElement) {
      return Math.tex(
        element.tex,
        textStyle: TextStyle(
          fontSize: preferredStyle?.fontSize ?? 14,
          color: Colors.white,
        ),
      );
    }
    return null;
  }
}
