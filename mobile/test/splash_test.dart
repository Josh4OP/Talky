import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky/core/api_exception.dart';
import 'package:talky/screens/splash_to_home.dart';
import 'package:talky/widgets/sky/sky_background.dart';

/// Casos de `harness/prompts/tasks/Animacion-splash.md`.
Widget host(Future<void> Function() loadApp, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(390, 844), disableAnimations: still),
    child: SplashToHome(
      loadApp: loadApp,
      home: const Scaffold(body: Text('INICIO')),
    ),
  ),
);

void main() {
  testWidgets('home does not appear before the minimum duration', (tester) async {
    await tester.pumpWidget(host(() => Future<void>.delayed(const Duration(milliseconds: 200))));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('INICIO'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('after loading and the reveal only home remains', (tester) async {
    await tester.pumpWidget(host(() async {}));
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('INICIO'), findsOneWidget);
    expect(find.byType(SkyBackground), findsNothing);
  });

  testWidgets('a failed load shows Reintentar and retrying calls loadApp again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(() async {
        calls++;
        throw ApiException.connection();
      }),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('INICIO'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with reduced motion no ticker runs while loading', (tester) async {
    final never = Completer<void>();
    await tester.pumpWidget(host(() => never.future, still: true));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unmounting during the reveal leaves nothing pending', (tester) async {
    await tester.pumpWidget(host(() async {}));
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
