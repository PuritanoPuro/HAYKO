import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/americano_result.dart';
import 'package:calcetto_mvp/core/domain/americano_standings.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_standings_page.dart';
import 'package:calcetto_mvp/features/padel/padel_statistics_section.dart';

void main() {
  final players = [
    Player('p0', 'Luca', color: 0xff63c7f2),
    Player('p1', 'Filippo'),
    Player('p2', 'Elena'),
    Player('p3', 'Marco'),
  ];

  Competition competition({String status = 'completed'}) => Competition(
        'c',
        'Americano',
        'americano',
        2,
        const [],
        americanoPlayerCount: 4,
        americanoCourts: 1,
        americanoRounds: 2,
        americanoTargetPoints: 8,
        americanoPlayerIds: const ['p0', 'p1', 'p2', 'p3'],
        americanoSchedule: const [
          [
            ['p0', 'p1', 'p2', 'p3']
          ],
          [
            ['p0', 'p2', 'p1', 'p3']
          ],
        ],
        americanoResults: [
          [
            AmericanoCourtResult(
                points: [0, 0, 0, 0, 0, 1, 1, 1], finished: true)
          ],
          [
            AmericanoCourtResult(
                points: [1, 1, 1, 1, 1, 1, 0, 0],
                finished: status == 'finished')
          ],
        ],
        americanoCurrentRound: status == 'finished' ? 1 : 0,
        americanoTurnStatus: status,
      );

  test('classifica progressiva ricalcola anche un risultato corretto', () {
    final current = competition();
    final first = americanoStandings(current, throughRound: 0);
    expect(first.map((row) => row.playerId).toList(), ['p0', 'p1', 'p2', 'p3']);
    expect(first.map((row) => row.rank).toList(), [1, 1, 3, 3]);
    expect(first.first.points, 5);
    expect(first.first.wins, 1);
    expect(first.first.difference, 2);
    current.americanoResults[0][0].points
      ..clear()
      ..addAll([1, 1, 1, 1, 1, 0, 0, 0]);
    final corrected = americanoStandings(current, throughRound: 0);
    expect(corrected.first.playerId, 'p2');
    expect(corrected.first.points, 5);
    expect(corrected.last.points, 3);
  });

  testWidgets('schermata 31 mostra classifica e avanza al turno seguente',
      (tester) async {
    final current = competition();
    final league = League('l', 'Lega', players, const [],
        type: 'competition', sport: LeagueSport.padel, competitions: [current])
      ..myPlayer = 'p0';
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: PadelAmericanoStandingsPage(
            league: league, competition: current, save: () async => saves++)));
    expect(find.text('Classifica Americano'), findsOneWidget);
    expect(find.text('Turno 1 di 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('americano-current-player-indicator')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('americano-standing-p0')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('americano-round-standings')),
        const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('americano-standings-next')));
    await tester.pumpAndSettle();
    expect(current.americanoCurrentRound, 1);
    expect(current.americanoTurnStatus, 'scheduled');
    expect(saves, 1);
    expect(find.byKey(const ValueKey('americano-scheduled')), findsOneWidget);
  });

  testWidgets('schermata 32 mostra podio e condivisione', (tester) async {
    final current = competition(status: 'finished');
    final league = League('l', 'Lega', players, const [],
        type: 'competition', sport: LeagueSport.padel, competitions: [current])
      ..myPlayer = 'p0';
    await tester.pumpWidget(MaterialApp(
        home: PadelAmericanoStandingsPage(
            league: league, competition: current, save: () async {})));
    expect(find.text('Americano terminato'), findsOneWidget);
    expect(find.byKey(const ValueKey('americano-podium-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('americano-podium-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('americano-podium-3')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('americano-final-standings')),
        const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('americano-share-standings')),
        findsOneWidget);
  });

  testWidgets('ultimo turno apre direttamente la classifica finale',
      (tester) async {
    final current = competition(status: 'finished');
    current.americanoTurnStatus = 'completed';
    final league = League('l', 'Lega', players, const [],
        type: 'competition', sport: LeagueSport.padel, competitions: [current]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: PadelAmericanoStandingsPage(
            league: league, competition: current, save: () async => saves++)));
    expect(find.text('Turno 2 di 2'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('americano-round-standings')),
        const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('americano-standings-next')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(current.americanoTurnStatus, 'finished');
    expect(find.byKey(const ValueKey('americano-final-standings')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('americano-podium-2')), findsOneWidget);
  });

  testWidgets('le statistiche della lega aprono la classifica Americano',
      (tester) async {
    final current = competition();
    final league = League('l', 'Lega', players, const [],
        type: 'competition', sport: LeagueSport.padel, competitions: [current]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PadelStatisticsSection(league: league, save: () async {}))));
    await tester.tap(find.byKey(const ValueKey('americano-standings-open-c')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('americano-round-standings')),
        findsOneWidget);
  });
}
