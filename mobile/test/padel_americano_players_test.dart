import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_players_page.dart';
import 'package:calcetto_mvp/features/account/components.dart';

void main() {
  testWidgets('seleziona il numero esatto di partecipanti e salva gli ID',
      (tester) async {
    final players = List.generate(
      5,
      (index) => Player('player-$index', 'Giocatore $index'),
    );
    final competition = Competition(
        'competition', 'Americano', 'americano', 2, [],
        americanoPlayerCount: 4, americanoCourts: 1, allowDraft: true);
    final league = League('league', 'Americano', players, [],
        type: 'competition',
        sport: LeagueSport.padel,
        competitions: [competition]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: PadelAmericanoPlayersPage(
        league: league,
        competition: competition,
        save: () async => saves++,
      ),
    ));

    expect(find.text('0 / 4 selezionati'), findsOneWidget);
    expect(
        tester
            .widget<AccountButton>(
                find.byKey(const ValueKey('americano-generate-rounds')))
            .onPressed,
        isNull);
    for (var index = 0; index < 4; index++) {
      await tester.ensureVisible(
          find.byKey(ValueKey('americano-player-player-$index')));
      await tester.tap(find.byKey(ValueKey('americano-player-player-$index')));
      await tester.pump();
    }
    expect(find.text('4 / 4 selezionati'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('americano-generate-rounds')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('americano-calendar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('americano-confirm-calendar')));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(competition.americanoPlayerIds,
        ['player-0', 'player-1', 'player-2', 'player-3']);
    expect(
        League.fromJson(league.toJson()).competitions.single.americanoPlayerIds,
        competition.americanoPlayerIds);
    expect(competition.americanoSchedule.length, competition.americanoRounds);
  });

  testWidgets('la ricerca filtra senza cancellare la selezione',
      (tester) async {
    final players = [Player('a', 'Andrea'), Player('b', 'Bianca')];
    final competition = Competition('c', 'Americano', 'americano', 2, [],
        americanoPlayerCount: 4, americanoCourts: 1, allowDraft: true);
    final league = League('l', 'Americano', players, [],
        sport: LeagueSport.padel, competitions: [competition]);
    await tester.pumpWidget(MaterialApp(
      home: PadelAmericanoPlayersPage(
          league: league, competition: competition, save: () async {}),
    ));
    await tester.tap(find.byKey(const ValueKey('americano-player-a')));
    await tester.enterText(
        find.byKey(const ValueKey('americano-search')), 'Bianca');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('americano-player-a')), findsNothing);
    expect(find.byKey(const ValueKey('americano-player-b')), findsOneWidget);
    expect(find.text('1 / 4 selezionati'), findsOneWidget);
  });
}
