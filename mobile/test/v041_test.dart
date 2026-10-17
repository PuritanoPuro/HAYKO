import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/competitions/competition_hub.dart';
import 'package:calcetto_mvp/features/competitions/competition_match_form.dart';
import 'package:calcetto_mvp/features/competitions/competition_roster_editor.dart';
import 'package:calcetto_mvp/features/matches/goal_page.dart';

League sample() => League(
    'l',
    'Coppa',
    [
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) Player(id, id)
    ],
    [],
    type: 'competition',
    presets: [
      TeamPreset('t0', 'Rossi', ['a', 'b', 'c'],
          color: 0xffff0000, numbers: {'a': 1, 'b': 2, 'c': 3}),
      TeamPreset('t1', 'Blu', ['d', 'e', 'f'],
          numbers: {'d': 1, 'e': 2, 'f': 3})
    ],
    competitions: [
      Competition('c', 'Coppa', 'league', 2, ['t0', 't1'])
    ]);
Match fixture(League l) => Match(
    id: 'm',
    format: 2,
    names: ['Rossi', 'Blu'],
    teams: [
      ['a', 'b', 'c'],
      ['d', 'e', 'f']
    ],
    presetIds: ['t0', 't1'],
    competitionId: 'c',
    competitionRules: true,
    keepers: [KeeperPlan.none(), KeeperPlan.none()]);
void main() {
  test('tutta la rosa incluse riserve puo segnare e assistere', () {
    final l = sample(), m = fixture(l)..start();
    m.add(Goal(
        id: 'g',
        team: 0,
        scorer: 'c',
        assist: 'b',
        time: DateTime.now().toUtc().toIso8601String()));
    expect(m.score(0), 1);
    expect(m.goals.single.keeper, isNull);
    expect(Match.fromJson(m.toJson()).teams[0].length, 3);
  });
  test('flow competizione salta portiere anche per autogol', () {
    final m = fixture(sample());
    expect(goalSteps(m, 0, false), ['team', 'scorer', 'assist', 'review']);
    expect(goalSteps(m, 0, true), ['team', 'scorer', 'review']);
  });
  test('luogo facoltativo modificabile prima dell avvio', () {
    final m = fixture(sample());
    m.editDetails(DateTime.utc(2026), '');
    expect(m.venue, '');
    m.start();
    expect(() => m.editDetails(DateTime.utc(2026), ''), throwsStateError);
  });
  test('turni classici del torneo', () {
    final c = Competition(
        'c', 'C', 'knockout', 2, [for (var i = 0; i < 16; i++) 't$i']);
    expect(tournamentRoundName(c, 1), 'Ottavi di finale');
    expect(tournamentRoundName(c, 2), 'Quarti di finale');
    expect(tournamentRoundName(c, 3), 'Semifinali');
    expect(tournamentRoundName(c, 4), 'Finale');
  });
  test('vincitrice campionato solo dopo tutti gli incontri terminati', () {
    final l = sample(), c = l.competitions.single, m = fixture(l);
    l.matches.add(m);
    expect(competitionWinners(l, c), isEmpty);
    m.start();
    m.add(Goal(
        id: 'g',
        team: 0,
        scorer: 'c',
        time: DateTime.now().toUtc().toIso8601String()));
    m.finish();
    expect(competitionWinners(l, c), ['t0']);
  });
  test('vincitrice torneo dopo finale e pareggio con qualificata', () {
    final l = sample();
    l.competitions.clear();
    final c = Competition('c', 'C', 'knockout', 2, ['t0', 't1']);
    l.competitions.add(c);
    final m = Match(
        id: 'm',
        format: 2,
        names: ['Rossi', 'Blu'],
        teams: [
          ['a', 'b', 'c'],
          ['d', 'e', 'f']
        ],
        presetIds: ['t0', 't1'],
        competitionId: 'c',
        competitionRules: true,
        knockoutRound: 1);
    l.matches.add(m);
    m.start();
    expect(competitionWinners(l, c), isEmpty);
    m.finish(winner: 't1');
    expect(competitionWinners(l, c), ['t1']);
  });
  testWidgets(
      'editor rosa mostra solo la squadra ed elimina senza cancellare storico',
      (tester) async {
    final l = sample(), m = fixture(sample())..start();
    l.matches.add(m);
    await tester.pumpWidget(MaterialApp(
        home: CompetitionRosterEditor(
            league: l,
            save: () async {},
            team: l.presets.first,
            competition: l.competitions.single)));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('d'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(find.byTooltip('Rimuovi giocatore').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva squadra'));
    await tester.pumpAndSettle();
    expect(l.presets.first.players, ['b', 'c']);
    expect(l.players.any((p) => p.id == 'a'), true);
    expect(m.teams[0], ['a', 'b', 'c']);
  });
  testWidgets(
      'partita competizione sceglie solo squadre e permette luogo vuoto',
      (tester) async {
    final l = sample();
    await tester.pumpWidget(MaterialApp(
        home:
            CompetitionMatchForm(league: l, initialTeams: const ['t0', 't1'])));
    expect(find.text('Seleziona formazione'), findsNothing);
    expect(find.text('Portieri'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Crea partita'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('statistiche competizione DR senza filtri e tabella giocatori',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CompetitionStatistics(league: sample()))));
    expect(find.text('DR'), findsOneWidget);
    expect(find.text('DG'), findsNothing);
    expect(find.text('Giocatore'), findsNothing);
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byType(DataTable), findsOneWidget);
  });
  testWidgets('goal riserva passa da assist a riepilogo senza portiere',
      (tester) async {
    final l = sample(), m = fixture(l)..start();
    await tester.pumpWidget(MaterialApp(home: GoalPage(league: l, match: m)));
    await tester.tap(find.text('Rossi'));
    await tester.pumpAndSettle();
    expect(find.text('#3 · c'), findsOneWidget);
    await tester.tap(find.text('#3 · c'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nessun assist'));
    await tester.pumpAndSettle();
    expect(find.text('Conferma gol'), findsNWidgets(2));
    expect(find.text('Chi era in porta?'), findsNothing);
    expect(find.textContaining('Portiere:'), findsNothing);
  });
}
