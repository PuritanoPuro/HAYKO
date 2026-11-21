import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/core/domain/padel_scoring.dart';
import 'package:calcetto_mvp/features/matches/match_page.dart';
import 'package:calcetto_mvp/features/padel/padel_couple_edit_page.dart';
import 'package:calcetto_mvp/features/padel/padel_league_page.dart';
import 'package:calcetto_mvp/features/padel/padel_live_match_page.dart';
import 'package:calcetto_mvp/features/padel/padel_match_creation_page.dart';
import 'package:calcetto_mvp/features/padel/padel_match_stats_page.dart';
import 'package:calcetto_mvp/features/padel/padel_statistics_section.dart';

League league() => League(
      'padel',
      'Padel del giovedì',
      [
        Player('a', 'Andrea Rossi', color: 0xffe3f24a),
        Player('f', 'Filippo Fuschini', color: 0xffff7a3d),
        Player('l', 'Luca Bianchi', color: 0xff63c7f2),
        Player('m', 'Marco Verdi', color: 0xff38d9a9),
      ],
      [],
      sport: LeagueSport.padel,
    );

void main() {
  testWidgets('creazione coppia usa il segno meno rosso', (tester) async {
    final value = league();
    final couple = TeamPreset('c', 'I Falchi', ['a', 'f']);
    value.presets.add(couple);
    await tester.pumpWidget(MaterialApp(
        home: PadelCoupleEditPage(
            league: value, couple: couple, save: () async {})));

    expect(find.byIcon(Icons.remove), findsNWidgets(2));
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('dot in corso compare soltanto con una partita live',
      (tester) async {
    final value = league();
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: value, save: () async {})));
    expect(find.byKey(const ValueKey('padel-live-dot')), findsNothing);

    value.matches.add(Match(
        id: 'live',
        format: 2,
        names: const ['Coppia A', 'Coppia B'],
        teams: const [
          ['a', 'f'],
          ['l', 'm']
        ],
        status: 'live',
        keepers: [KeeperPlan.none(), KeeperPlan.none()]));
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: value, save: () async {})));
    expect(find.byKey(const ValueKey('padel-live-dot')), findsOneWidget);
  });

  testWidgets('schermata 21 mostra statistiche giocatori Padel',
      (tester) async {
    final value = league()..myPlayer = 'f';
    value.matches.add(Match(
      id: 'finished-stats',
      format: 2,
      names: const ['Coppia A', 'Coppia B'],
      teams: const [
        ['a', 'f'],
        ['l', 'm']
      ],
      status: 'finished',
      startedAt: '2026-11-12T18:00:00Z',
      finishedAt: '2026-11-12T19:00:00Z',
      keepers: [KeeperPlan.none(), KeeperPlan.none()],
      padelSetScores: const [
        [6, 3],
        [6, 4]
      ],
    ));

    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: value, save: () async {})));
    await tester.tap(find.text('Statistiche'));
    await tester.pump();

    expect(
        find.byKey(const ValueKey('padel-player-statistics')), findsOneWidget);
    expect(find.text('Statistiche giocatori'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('padel-statistics-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('padel-statistics-current-player')),
        findsOneWidget);
    expect(find.text('SP'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('padel-current-player-summary')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('padel-format-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meglio di 5 set').last);
    await tester.pumpAndSettle();
    expect(find.text('Nessuna partita terminata.'), findsOneWidget);
  });

  testWidgets('schermata 22 mostra statistiche e testa a testa delle coppie',
      (tester) async {
    final value = league()..myPlayer = 'f';
    value.matches.add(Match(
      id: 'finished-couple-stats',
      format: 2,
      names: const ['Coppia A', 'Coppia B'],
      teams: const [
        ['a', 'f'],
        ['l', 'm']
      ],
      status: 'finished',
      startedAt: '2026-11-12T18:00:00Z',
      finishedAt: '2026-11-12T19:00:00Z',
      keepers: [KeeperPlan.none(), KeeperPlan.none()],
      padelSetScores: const [
        [6, 3],
        [6, 4]
      ],
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PadelStatisticsSection(
          league: value,
          initialCouplesMode: true,
        ),
      ),
    ));

    expect(find.text('Statistiche coppie'), findsOneWidget);
    expect(find.byKey(const ValueKey('padel-couple-head-to-head')),
        findsOneWidget);
    expect(find.textContaining('Testa a testa'), findsOneWidget);

    final detail = find.byKey(const ValueKey('padel-head-to-head-l|m'));
    tester.widget<InkWell>(detail).onTap!();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('padel-head-to-head-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('padel-head-to-head-balance')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('padel-head-to-head-latest')),
        findsOneWidget);
  });

  testWidgets('flusso 13-16 seleziona due coppie e mostra il riepilogo',
      (tester) async {
    final value = league()..myPlayer = 'f';
    await tester.pumpWidget(MaterialApp(
        home: PadelMatchCreationPage(league: value, save: () async {})));

    expect(find.text('Formula partita'), findsOneWidget);
    expect(find.text('Punteggio game'), findsOneWidget);
    expect(find.text('Set decisivo'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona coppie'));
    await tester.pumpAndSettle();

    expect(find.text('Coppia A · Blu'), findsOneWidget);
    expect(find.text('Carica una coppia salvata'), findsOneWidget);
    await tester.tap(find.text('Andrea Rossi'));
    await tester.pump();
    await tester.tap(find.text('Filippo Fuschini · Tu'));
    await tester.pump();
    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();

    expect(find.text('Coppia B · Arancio'), findsOneWidget);
    expect(find.text('Già nella coppia A'), findsNWidgets(2));
    final rows = tester.widgetList<ListView>(find.byType(ListView));
    expect(rows, isNotEmpty);
    await tester.tap(find.text('Luca Bianchi'));
    await tester.pump();
    await tester.tap(find.text('Marco Verdi'));
    await tester.pump();
    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();

    expect(find.text('Riepilogo partita'), findsOneWidget);
    expect(find.text('Prima battuta'), findsOneWidget);
    expect(find.text('Andrea Rossi · Filippo Fuschini'), findsOneWidget);
    expect(find.text('Luca Bianchi · Marco Verdi'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Programma partita'), findsOneWidget);
  });

  test('regole Padel persistono nel JSON della partita', () {
    final match = Match(
        id: 'm',
        format: 2,
        names: const ['Coppia A', 'Coppia B'],
        teams: const [
          ['a', 'f'],
          ['l', 'm']
        ],
        keepers: [KeeperPlan.none(), KeeperPlan.none()],
        padelBestOf: 5,
        padelGameRule: 'advantages',
        padelDecidingSet: 'full_set',
        padelFirstServerId: 'f');

    final restored = Match.fromJson(match.toJson());
    expect(restored.padelBestOf, 5);
    expect(restored.padelGameRule, 'advantages');
    expect(restored.padelDecidingSet, 'full_set');
    expect(restored.padelFirstServerId, 'f');
  });

  test('servizio Padel alterna giocatori e segue il tie-break', () {
    final match = Match(
      id: 'service',
      format: 2,
      names: const ['Coppia A', 'Coppia B'],
      teams: const [
        ['a', 'f'],
        ['l', 'm']
      ],
      status: 'live',
      keepers: [KeeperPlan.none(), KeeperPlan.none()],
      padelFirstServerId: 'f',
      padelSetScores: [
        [0, 0]
      ],
    );
    expect(PadelScoring.servingPlayerId(match), 'f');
    match.padelSetScores[0][0] = 1;
    expect(PadelScoring.servingPlayerId(match), 'l');
    match.padelSetScores[0][1] = 1;
    expect(PadelScoring.servingPlayerId(match), 'a');
    match.padelSetScores[0] = [6, 6];
    expect(PadelScoring.servingPlayerId(match), 'f');
    match.padelPoints[0] = '1';
    expect(PadelScoring.servingPlayerId(match), 'l');
    match.padelPoints[0] = '2';
    expect(PadelScoring.servingPlayerId(match), 'l');
    match.padelPoints[0] = '3';
    expect(PadelScoring.servingPlayerId(match), 'a');
  });

  test('un set interrotto non assegna la vittoria del set', () {
    final match = Match(
      id: 'early',
      format: 2,
      names: const ['Coppia A', 'Coppia B'],
      teams: const [
        ['a', 'f'],
        ['l', 'm']
      ],
      status: 'finished',
      keepers: [KeeperPlan.none(), KeeperPlan.none()],
      padelSetScores: [
        [6, 4],
        [3, 1]
      ],
    );
    expect(PadelScoring.setWinner(match, 0), 0);
    expect(PadelScoring.setWinner(match, 1), isNull);
    expect(PadelScoring.wonSets(match, 0), 1);
  });

  testWidgets('card partita usa colonne set dinamiche e punti solo live',
      (tester) async {
    final value = league();
    value.matches.add(Match(
        id: 'm',
        format: 2,
        names: const ['Coppia A', 'Coppia B'],
        teams: const [
          ['a', 'f'],
          ['l', 'm']
        ],
        status: 'scheduled',
        keepers: [KeeperPlan.none(), KeeperPlan.none()],
        padelBestOf: 5));
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: value, save: () async {})));

    for (var set = 1; set <= 5; set++) {
      expect(find.byKey(ValueKey('padel-set-header-$set')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('padel-points-header')), findsNothing);
    expect(find.text('Andrea / Filippo'), findsOneWidget);
    expect(find.text('Luca / Marco'), findsOneWidget);

    final match = value.matches.single;
    match.status = 'live';
    match.padelSetScores.addAll(const [
      [6, 3],
      [4, 6]
    ]);
    match.padelPoints
      ..clear()
      ..addAll(const ['30', '15']);
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: value, save: () async {})));
    await tester.tap(find.byKey(const ValueKey('padel-match-tab-live')));
    await tester.pump();
    expect(find.byKey(const ValueKey('padel-points-header')), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets(
      'partita live Padel assegna e annulla un punto senza registro gol',
      (tester) async {
    final value = league();
    final match = Match(
        id: 'live-padel',
        format: 2,
        names: const ['Coppia A', 'Coppia B'],
        teams: const [
          ['a', 'f'],
          ['l', 'm']
        ],
        status: 'live',
        startedAt: DateTime.now().toUtc().toIso8601String(),
        keepers: [KeeperPlan.none(), KeeperPlan.none()]);
    value.matches.add(match);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: PadelLiveMatchPage(
            league: value, match: match, save: () async => saves++)));

    expect(find.byKey(const ValueKey('padel-live-match')), findsOneWidget);
    expect(find.text('Registro gol'), findsNothing);
    expect(find.text('GOL'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('padel-point-0')));
    await tester.pumpAndSettle();
    expect(match.padelPoints, const ['15', '0']);
    expect(saves, 1);

    await tester.tap(find.byKey(const ValueKey('padel-undo-point')));
    await tester.pumpAndSettle();
    expect(match.padelPoints, const ['0', '0']);
    expect(saves, 2);
  });

  testWidgets('avvio partita Padel sostituisce la schermata calcio',
      (tester) async {
    final value = league();
    final match = Match(id: 'scheduled-padel', format: 2, names: const [
      'Coppia A',
      'Coppia B'
    ], teams: const [
      ['a', 'f'],
      ['l', 'm']
    ], keepers: [
      KeeperPlan.none(),
      KeeperPlan.none()
    ]);
    value.matches.add(match);
    final saved = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home:
            MatchPage(league: value, match: match, save: () => saved.future)));

    await tester.tap(find.text('Inizia partita'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Registro gol'), findsNothing);
    saved.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('padel-live-match')), findsOneWidget);
    expect(find.byKey(const ValueKey('padel-point-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('padel-point-1')), findsOneWidget);
    expect(find.text('Registro gol'), findsNothing);
    expect(find.text('GOL'), findsNothing);
  });

  Match scoringMatch({
    int bestOf = 3,
    String decidingSet = 'super_tiebreak_10',
    required List<List<int>> sets,
    required List<String> points,
  }) =>
      Match(
          id: newId(),
          format: 2,
          names: const ['A', 'B'],
          teams: const [
            ['a', 'f'],
            ['l', 'm']
          ],
          status: 'live',
          keepers: [KeeperPlan.none(), KeeperPlan.none()],
          padelBestOf: bestOf,
          padelDecidingSet: decidingSet,
          padelSetScores: sets,
          padelPoints: points);

  test('meglio di 5 termina al terzo set vinto', () {
    final match = scoringMatch(bestOf: 5, sets: [
      [6, 2],
      [4, 6],
      [6, 3],
      [5, 0]
    ], points: [
      '40',
      '0'
    ]);
    PadelScoring.awardPoint(match, 0);
    expect(match.padelSetScores.last, [6, 0]);
    expect(match.status, 'finished');
  });

  test('tie-break termina a sette soltanto con due punti di scarto', () {
    final match = scoringMatch(sets: [
      [6, 6]
    ], points: [
      '6',
      '6'
    ]);
    PadelScoring.awardPoint(match, 0);
    expect(match.padelPoints, ['7', '6']);
    PadelScoring.awardPoint(match, 0);
    expect(match.padelSetScores.first, [7, 6]);
    expect(match.padelSetScores.length, 2);
  });

  test('super tie-break decisivo termina a dieci con due punti di scarto', () {
    final match = scoringMatch(sets: [
      [6, 3],
      [4, 6],
      [0, 0]
    ], points: [
      '9',
      '8'
    ]);
    PadelScoring.awardPoint(match, 0);
    expect(match.padelSetScores.last, [10, 8]);
    expect(match.status, 'finished');
  });

  test('set decisivo completo termina solo con due game di scarto', () {
    final match = scoringMatch(decidingSet: 'full_set', sets: [
      [6, 3],
      [4, 6],
      [15, 14]
    ], points: [
      '40',
      '0'
    ]);
    PadelScoring.awardPoint(match, 0);
    expect(match.padelSetScores.last, [16, 14]);
    expect(match.status, 'finished');
  });

  testWidgets('partita Padel terminata non mostra il registro gol',
      (tester) async {
    final value = league();
    final match = Match(
        id: 'finished-padel',
        format: 2,
        names: const ['A', 'B'],
        teams: const [
          ['a', 'f'],
          ['l', 'm']
        ],
        status: 'finished',
        finishedAt: DateTime.now().toUtc().toIso8601String(),
        keepers: [KeeperPlan.none(), KeeperPlan.none()],
        padelSetScores: [
          [6, 3],
          [6, 4]
        ]);
    await tester.pumpWidget(MaterialApp(
        home: MatchPage(league: value, match: match, save: () async {})));

    expect(find.text('Registro gol'), findsNothing);
    expect(find.text('Nessun gol registrato.'), findsNothing);
  });

  testWidgets('partita Padel terminata apre le statistiche Figma 20',
      (tester) async {
    final value = league();
    value.matches.add(Match(
        id: 'finished-card',
        format: 2,
        names: const ['A', 'B'],
        teams: const [
          ['a', 'f'],
          ['l', 'm']
        ],
        status: 'finished',
        finishedAt: DateTime.now().toUtc().toIso8601String(),
        keepers: [KeeperPlan.none(), KeeperPlan.none()],
        padelSetScores: [
          [6, 3],
          [6, 4]
        ]));
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: value, save: () async {})));
    await tester.tap(find.byKey(const ValueKey('padel-match-tab-finished')));
    await tester.pump();

    await tester.tap(find.text('Andrea / Filippo'));
    await tester.pumpAndSettle();

    expect(find.byType(PadelMatchStatsPage), findsOneWidget);
    expect(find.byKey(const ValueKey('padel-match-stats')), findsOneWidget);
    expect(find.text('Confronto coppie'), findsOneWidget);
    expect(find.text('Dettaglio set'), findsOneWidget);
    expect(find.text('Registro gol'), findsNothing);
  });
}
