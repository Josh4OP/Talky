import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky/widgets/mascot/talky_mascot.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Center(child: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every state points to a bundled image', () async {
    for (final state in MascotState.values) {
      final data = await rootBundle.load(mascotAsset(state));
      expect(data.lengthInBytes, greaterThan(0), reason: state.name);
    }
  });

  test('talking bounces during the cycle', () {
    final lifts = [for (var t = 0.0; t < 1; t += 0.01) MascotMotion.at(MascotState.talking, t).dy];
    expect(lifts.reduce((a, b) => a < b ? a : b), lessThan(-0.015));
    expect(lifts.reduce((a, b) => a > b ? a : b), closeTo(0, 0.001));
  });

  test('only thinking makes the bulb glow', () {
    for (final state in MascotState.values) {
      final glows = [for (var t = 0.0; t < 1; t += 0.05) MascotMotion.at(state, t).glow];
      expect(glows.any((g) => g > 0), state == MascotState.thinking, reason: state.name);
    }
  });

  for (final state in MascotState.values) {
    testWidgets('$state builds and animates without errors', (tester) async {
      await tester.pumpWidget(host(TalkyMascot(state: state)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });
  }

  testWidgets('with reduced motion no ticker keeps running', (tester) async {
    await tester.pumpWidget(host(const TalkyMascot(state: MascotState.thinking), still: true));
    await tester.pump();
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });
}
