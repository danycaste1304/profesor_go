import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/widgets/retro_dialogue.dart';

void main() {
  testWidgets('reveals dialogue progressively and exposes its full semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RetroDialogue(text: '¡Hola, profe!')),
      ),
    );
    expect(find.text('¡Hola, profe!'), findsNothing);
    expect(find.bySemanticsLabel('¡Hola, profe!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¡Hola, profe!'), findsOneWidget);
  });

  testWidgets('can show the whole message immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RetroDialogue(text: 'Listo para jugar', animate: false),
        ),
      ),
    );
    expect(find.text('Listo para jugar'), findsOneWidget);
  });
}
