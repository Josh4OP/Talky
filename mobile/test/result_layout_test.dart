import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky/data/demo_data.dart';
import 'package:talky/screens/result_screen.dart';
import 'package:talky/theme/app_theme.dart';
import 'package:talky/widgets/cards.dart';

/// Regresión: las métricas clave quedaron con un Expanded doble y en release salían angostas y partidas.
void main() {
  testWidgets('key metric tiles share the row width at phone size', (tester) async {
    // Alto de sobra: la fuente de pruebas alarga los textos y la fila quedaría fuera de la vista.
    tester.view.physicalSize = const Size(393 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ResultScreen(analysis: DemoData.analysis()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final widths = [
      for (final e in find.byType(MetricTile).evaluate().take(3)) (e.renderObject! as RenderBox).size.width,
    ];
    expect(widths, hasLength(3));
    expect(widths.every((w) => w > 100), isTrue, reason: '$widths');
  });
}
