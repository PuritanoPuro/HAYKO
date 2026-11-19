import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_scheduled_page.dart';

void main() {
  testWidgets('mostra il calendario salvato e avvia il turno una sola volta',
      (tester) async {
    final players = [
      Player('a', 'Andrea'),
      Player('b', 'Bianca'),
      Player('c', 'Carlo'),
      Player('d', 'Daria'),
    ];
    final competition = Competition(
        'competition', 'Americano del sabato', 'americano', 2, const [],
        americanoPlayerCount: 4,
        americanoCourts: 1,
        americanoRounds: 3,
        americanoPlayerIds: ['a', 'b', 'c', 'd'],
        americanoSchedule: [
          [
            ['a', 'b', 'c', 'd']
          ],
          [
            ['a', 'c', 'b', 'd']
          ],
          [
            ['a', 'd', 'b', 'c']
          ],
        ]);
    final league = League('league', 'Lega', players, const [],
        sport: LeagueSport.padel,
        type: 'competition',
        competitions: [competition]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: PadelAmericanoScheduledPage(
        league: league,
        competition: competition,
        save: () async => saves++,
      ),
    ));

    expect(find.text('Turno 1 di 3 · Programmato'), findsOneWidget);
    expect(find.text('Andrea / Bianca'), findsOneWidget);
    expect(find.text('Carlo / Daria'), findsOneWidget);
    expect(find.byKey(const ValueKey('americano-scheduled-court-1')),
        findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('americano-start-round')));
    await tester.tap(find.byKey(const ValueKey('americano-start-round')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(competition.americanoTurnStatus, 'live');
    expect(find.text('Turno 1 di 3 · In corso'), findsOneWidget);
    expect(find.byKey(const ValueKey('americano-start-round')), findsNothing);
    expect(
        League.fromJson(league.toJson())
            .competitions
            .single
            .americanoTurnStatus,
        'live');
    await tester.tap(find.byKey(const ValueKey('americano-cancel-start')));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(competition.americanoTurnStatus, 'scheduled');
  });
}
