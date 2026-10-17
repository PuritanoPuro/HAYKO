import 'dart:async';

import 'package:calcetto_mvp/app.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/design_system/hayko_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash mostra i due vettoriali Figma durante l’avvio',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(CalcettoApp(
      initialization: initialization.future,
      minimumSplashDuration: const Duration(milliseconds: 100),
      destinationBuilder: (_) => const Scaffold(body: Text('Destinazione')),
    ));

    expect(find.byType(HaykoSplash), findsOneWidget);
    expect(find.text('Destinazione'), findsNothing);
    final assets =
        tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
    expect(assets, hasLength(2));
    expect(assets[0].width, 210);
    expect(assets[0].height, closeTo(94.756, 0.001));
    expect(assets[1].width, closeTo(232.375, 0.001));
    expect(assets[1].height, closeTo(45.161, 0.001));
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, isNull);
    expect(
        Theme.of(tester.element(find.byType(HaykoSplash)))
            .scaffoldBackgroundColor,
        HaykoColors.fieldBackground);

    initialization.complete();
    await tester.pump(const Duration(milliseconds: 99));
    expect(find.byType(HaykoSplash), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Destinazione'), findsOneWidget);
  });

  testWidgets('un errore di inizializzazione non lascia la splash bloccata',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(CalcettoApp(
      initialization: initialization.future,
      minimumSplashDuration: Duration.zero,
      destinationBuilder: (_) => const Scaffold(body: Text('Accesso')),
    ));

    initialization.completeError(StateError('servizio non disponibile'));
    await tester.pumpAndSettle();
    expect(find.text('Accesso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
