import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class SyntaxHighlighter {
  SyntaxHighlighter();

  final Map<(String, String, TextStyle), TextSpan> _cache = {};

  TextSpan highlight({
    required String text,
    required String environmentId,
    required TextStyle baseStyle,
  }) {
    final key = (text, environmentId, baseStyle);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }

    final rules = switch (environmentId) {
      'latex' => _latexRules,
      'typst' => _typstRules,
      'mermaid' => _mermaidRules,
      _ => _markdownRules,
    };

    final result = TextSpan(style: baseStyle, children: _spansFor(text, rules));
    if (_cache.length > 5000) {
      _cache.clear();
    }
    _cache[key] = result;
    return result;
  }

  List<TextSpan> _spansFor(String text, List<_HighlightRule> rules) {
    final matches = <_HighlightMatch>[];
    for (final rule in rules) {
      for (final match in rule.pattern.allMatches(text)) {
        if (match.start == match.end) continue;
        matches.add(_HighlightMatch(match.start, match.end, rule.style));
      }
    }

    matches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return (b.end - b.start).compareTo(a.end - a.start);
    });

    final accepted = <_HighlightMatch>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) continue;
      accepted.add(match);
      cursor = match.end;
    }

    final spans = <TextSpan>[];
    cursor = 0;
    for (final match in accepted) {
      if (cursor < match.start) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: match.style,
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

const _commandStyle = TextStyle(color: Color(0xFF7DB7FF));
const _keywordStyle = TextStyle(color: Color(0xFFFFC46B));
const _commentStyle = TextStyle(
  color: Color(0xFF6F7A86),
  fontStyle: FontStyle.italic,
);
const _stringStyle = TextStyle(color: Color(0xFF74D6A0));
const _mathStyle = TextStyle(color: Color(0xFFFFA16C));
const _headingStyle = TextStyle(
  color: kTextPrimary,
  fontWeight: FontWeight.w800,
);

const _typstCommandStyle = TextStyle(color: Color(0xFF5FD9B2));
const _typstStringStyle = TextStyle(color: Color(0xFF7AE0B8));
const _typstMathStyle = TextStyle(color: Color(0xFFFFB347));

final _latexRules = [
  _HighlightRule(RegExp(r'%.*$', multiLine: true), _commentStyle),
  _HighlightRule(RegExp(r'\\[a-zA-Z@]+(\*?)'), _commandStyle),
  _HighlightRule(RegExp(r'\\(begin|end)\s*\{[^}]+\}'), _keywordStyle),
  _HighlightRule(RegExp(r'\$[^$\n]+\$'), _mathStyle),
  _HighlightRule(RegExp(r'\{[^{}\n]+\}'), _stringStyle),
];

final _typstRules = [
  _HighlightRule(RegExp(r'//.*$', multiLine: true), _commentStyle),
  _HighlightRule(RegExp(r'^=+ .+$', multiLine: true), _headingStyle),
  _HighlightRule(RegExp(r'#\w+'), _typstCommandStyle),
  _HighlightRule(RegExp(r'"[^"\n]*"'), _typstStringStyle),
  _HighlightRule(RegExp(r'\$[^$\n]+\$'), _typstMathStyle),
];

final _mermaidRules = [
  _HighlightRule(RegExp(r'%%.*$', multiLine: true), _commentStyle),
  _HighlightRule(
    RegExp(
      r'\b(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram-v2|erDiagram)\b',
    ),
    _keywordStyle,
  ),
  _HighlightRule(RegExp(r'(-->|---|-.->|==>|->>)'), _commandStyle),
  _HighlightRule(RegExp(r'"[^"\n]*"'), _stringStyle),
];

final _markdownRules = [
  _HighlightRule(RegExp(r'^#{1,6} .+$', multiLine: true), _headingStyle),
  _HighlightRule(RegExp(r'`[^`\n]+`'), _stringStyle),
  _HighlightRule(RegExp(r'\*\*[^*\n]+\*\*'), _keywordStyle),
  _HighlightRule(RegExp(r'<!--[\s\S]*?-->'), _commentStyle),
];

class _HighlightRule {
  const _HighlightRule(this.pattern, this.style);

  final RegExp pattern;
  final TextStyle style;
}

class _HighlightMatch {
  const _HighlightMatch(this.start, this.end, this.style);

  final int start;
  final int end;
  final TextStyle style;
}
