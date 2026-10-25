import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky/widgets/mascot/parrot_geometry.dart';
import 'package:talky/widgets/mascot/svg_path.dart';
import 'package:talky/widgets/mascot/talky_mascot.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Center(child: child),
  ),
);

void main() {
  test('every layer path parses', () {
    for (final layer in parrotLayers) {
      expect(parseSvgPath(layer.path).getBounds().isEmpty, isFalse, reason: layer.name);
    }
  });

  test('each state shows its own accessories', () {
    Set<String> names(MascotState s) => visibleLayers(s).map((l) => l.name).toSet();
    expect(names(MascotState.thinking), containsAll(['fx_bulb', 'eye_open']));
    expect(names(MascotState.talking), containsAll(['fx_wave_a', 'fx_wave_b']));
    expect(names(MascotState.sad), contains('eye_sad'));
    expect(names(MascotState.silhouette), isNot(contains('shadow')));
    expect(names(MascotState.normal), isNot(contains('fx_bulb')));
  });

  test('talking opens and closes the beak during the cycle', () {
    final angles = [for (var t = 0.0; t < 1; t += 0.01) MascotPose.at(MascotState.talking, t).rotation['beak_lower']!];
    expect(angles.reduce((a, b) => a < b ? a : b), lessThan(2));
    expect(angles.reduce((a, b) => a > b ? a : b), greaterThan(20));
  });

  for (final state in MascotState.values) {
    testWidgets('$state builds and animates without errors', (tester) async {
      await tester.pumpWidget(host(TalkyMascot(state: state)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(TalkyMascot), findsOneWidget);
    });
  }

  testWidgets('with reduced motion no ticker keeps running', (tester) async {
    await tester.pumpWidget(host(const TalkyMascot(state: MascotState.thinking), still: true));
    await tester.pump();
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });
}
