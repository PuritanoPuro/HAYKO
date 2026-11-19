import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/americano_flow.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_live_page.dart';

void main() {
  final players = [
    for (var index = 0; index < 8; index++)
      Player('p$index', 'Giocatore$index'),
  ];
  Competition competition() => Competition(
      'c', 'Americano', 'americano', 2, const [],
      americanoPlayerCount: 8,
      americanoCourts: 2,
      americanoRounds: 3,
      americanoTargetPoints: 8,
      americanoTurnStatus: 'live',
      americanoPlayerIds: [for (var index = 0; index < 8; index++) 'p$index'],
      americanoSchedule: [
        for (var round = 0; round < 3; round++)
          [
            ['p0', 'p1', 'p2', 'p3'],
            ['p4', 'p5', 'p6', 'p7'],
          ],
      ]);

  testWidgets('i due campi hanno risultati indipendenti e si aprono',
      (tester) async {
    final current = competition();
    ensureAmericanoResults(current);
    current.americanoResults[0][0].addPoint(0, 8);
    current.americanoResults[0][0].addPoint(1, 8);
    final league = League('l', 'Lega', players, const [],
        type: 'competition', sport: LeagueSport.padel, competitions: [current]);
    await tester.pumpWidget(MaterialApp(
      home: PadelAmericanoLivePage(
          league: league, competition: current, save: () async {}),
    ));
    expect(find.text('1 – 1'), findsOneWidget);
    expect(find.text('0 – 0'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('americano-live-court-2')));
    await tester.tap(find.byKey(const ValueKey('americano-live-court-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('americano-score')), findsOneWidget);
    expect(find.text('Campo 2 · Turno 1'), findsOneWidget);
  });

  testWidgets('termina il turno soltanto dopo due incontri completi',
      (tester) async {
    final current = competition();
    ensureAmericanoResults(current);
    final league = League('l', 'Lega', players, const [],
        type: 'competition', sport: LeagueSport.padel, competitions: [current]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: PadelAmericanoLivePage(
          league: league, competition: current, save: () async => saves++),
    ));
    await tester.drag(
        find.byKey(const ValueKey('americano-live')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AccountButton>(
                find.byKey(const ValueKey('americano-finish-round')))
            .onPressed,
        isNull);
    for (final result in current.americanoResults[0]) {
      for (var index = 0; index < 8; index++) {
        result.addPoint(index.isEven ? 0 : 1, 8);
      }
      result.finish(8);
    }
    await tester
        .ensureVisible(find.byKey(const ValueKey('americano-live-court-1')));
    await tester.tap(find.byKey(const ValueKey('americano-live-court-1')));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('americano-finish-round')));
    await tester.tap(find.byKey(const ValueKey('americano-finish-round')));
    await tester.pumpAndSettle();
    expect(current.americanoTurnStatus, 'completed');
    expect(saves, 1);
    expect(
        find.byKey(const ValueKey('americano-round-complete')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('americano-round-complete')),
        const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('americano-next-round')));
    await tester.tap(find.byKey(const ValueKey('americano-next-round')));
    await tester.pumpAndSettle();
    expect(current.americanoCurrentRound, 1);
    expect(current.americanoTurnStatus, 'scheduled');
    expect(saves, 2);
  });
}
