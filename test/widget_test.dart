import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisk/main.dart';

void main() {
  testWidgets('shows the project dashboard', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('LaTeX'), findsOneWidget);
    expect(find.text('Typst'), findsOneWidget);
    expect(find.text('Mermaid'), findsOneWidget);
    expect(find.text('Open Folder'), findsOneWidget);
  });

  testWidgets('shows collaboration entry points', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.text('Colaboración'), findsOneWidget);
    expect(find.text('Unirse'), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
  });

  testWidgets('shows search bar', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows recent projects section', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('No hay proyectos recientes'), findsOneWidget);
  });
}
