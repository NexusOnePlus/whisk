import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';

class EnvironmentCatalog {
  const EnvironmentCatalog();

  List<EnvironmentKind> listEnvironments() => const [
    EnvironmentKind(
      id: 'latex',
      name: 'LaTeX',
      description: 'Documents, papers and math-heavy writing.',
      extension: '.tex',
      icon: Icons.functions,
      sample: r'''\documentclass{article}
\begin{document}
\section{Whisk}
Write structured documents without leaving your workspace.
\end{document}''',
    ),
    EnvironmentKind(
      id: 'typst',
      name: 'Typst',
      description: 'Fast technical documents with modern syntax.',
      extension: '.typ',
      icon: Icons.description_outlined,
      sample: '''= Whisk

Build documents, diagrams and notes from focused environments.''',
    ),
    EnvironmentKind(
      id: 'mermaid',
      name: 'Mermaid',
      description: 'Flowcharts, sequence diagrams and architecture maps.',
      extension: '.mmd',
      icon: Icons.account_tree_outlined,
      sample: '''flowchart LR
  Idea --> Environment
  Environment --> Preview
  Preview --> Export''',
    ),
    EnvironmentKind(
      id: 'notes',
      name: 'Notes',
      description: 'Plain writing for planning, drafts and context.',
      extension: '.md',
      icon: Icons.notes_outlined,
      sample: '''# Research notes

- Capture ideas
- Link them to an environment
- Render only when needed''',
    ),
  ];
}
