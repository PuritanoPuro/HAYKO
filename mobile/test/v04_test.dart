import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/main.dart';
import 'package:calcetto_mvp/features/leagues/league_creation.dart';
import 'package:calcetto_mvp/features/competitions/competition_hub.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';

League league({bool doubleLeg = false}) {
  final l = League('l', 'Coppa',
      [for (var i = 0; i < 8; i++) Player('p$i', 'Giocatore $i')], [],
      type: 'competition',
      presets: [
        for (var i = 0; i < 4; i++)
          TeamPreset('t$i', 'Squadra $i', ['p${i * 2}', 'p${i * 2 + 1}'],
              numbers: {'p${i * 2}': 1, 'p${i * 2 + 1}': 2}),
      ]);
  l.competitions.add(Competition(
      'c', 'Coppa', 'league', 2, ['t0', 't1', 't2', 't3'],
      doubleLeg: doubleLeg));
  return l;
}

void main() {
  test('migrazione distingue leghe con competizioni senza eliminare dati', () {
    final l = league();
    final json = l.toJson()..remove('type');
    final copy = League.fromJson(json);
    expect(copy.type, 'competition');
    expect(copy.presets.length, 4);
    json['competitions'] = [];
    expect(League.fromJson(json).type, 'amateur');
  });
  test('competizione appena creata conserva la configurazione senza squadre',
      () {
    final l = League('l', 'Nuova', [], [],
        type: 'competition',
        competitions: [
          Competition('c', 'Nuova', 'knockout', 5, [], allowDraft: true)
        ]);
    final copy = League.fromJson(l.toJson());
    expect(copy.competitions.single.ready, false);
    expect(tournamentTies(copy, copy.competitions.single), isEmpty);
  });
  test('numeri di maglia persistono per squadra', () {
    final copy = League.fromJson(league().toJson());
    expect(copy.presets.first.numbers, {'p0': 1, 'p1': 2});
  });
  test('andata ritorno genera coppie invertite in giornate distinte', () {
    final l = league(doubleLeg: true), c = l.competitions.single;
    final fixtures = leagueFixtures(l, c);
    expect(fixtures.length, 12);
    expect(fixtures.map((t) => t.round).toSet().length, 6);
    final first = fixtures.first;
    final back = fixtures.singleWhere(
        (t) => t.teams[0] == first.teams[1] && t.teams[1] == first.teams[0]);
    expect(back.round, first.round + 3);
    final m = Match(
        id: 'm',
        format: 2,
        names: ['A', 'B'],
        teams: [
          ['p0', 'p1'],
          ['p6', 'p7']
        ],
        presetIds: [...first.teams],
        competitionId: 'c');
    validateCompetitionMatch(l, m);
    l.matches.add(m);
    expect(
        leagueFixtures(l, c)
            .singleWhere(
                (t) => t.round == first.round && t.teams[0] == first.teams[0])
            .match,
        m);
    expect(
        leagueFixtures(l, c)
            .singleWhere(
                (t) => t.round == back.round && t.teams[0] == back.teams[0])
            .match,
        isNull);
    expect(
        () => validateCompetitionMatch(
            l,
            Match(
                id: 'dup',
                format: 2,
                names: ['A', 'B'],
                teams: m.teams,
                presetIds: m.presetIds,
                competitionId: 'c')),
        throwsStateError);
  });
  testWidgets('footer amatoriale contiene solo tre sezioni', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LeaguePage(
            league: League('l', 'Amici', [], []), save: () async {})));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 3);
    expect(find.text('Giocatori'), findsOneWidget);
    expect(find.text('Calendario'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('footer competizione mostra squadre e calendario',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LeaguePage(league: league(), save: () async {})));
    expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        4);
    expect(find.text('Squadre'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    await tester.tap(find.text('Squadre'));
    await tester.pumpAndSettle();
    expect(find.text('Squadre partecipanti'), findsOneWidget);
    expect(find.text('+ Squadra'), findsOneWidget);
    expect(
        find.text('Aggiungi almeno due squadre per completare il campionato.'),
        findsOneWidget);
    expect(find.text('2 giocatori'), findsAtLeastNWidgets(3));
    expect(find.text('›'), findsAtLeastNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione lega chiede amatoriale o competizione',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeagueCreation()));
    expect(find.text('Amatoriale'), findsOneWidget);
    await tester.tap(find.text('Competizione'));
    await tester.pumpAndSettle();
    expect(find.text('Campionato'), findsOneWidget);
    expect(find.text('Andata e ritorno'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('dettaglio squadra mostra nomi e numeri', (tester) async {
    final l = league();
    await tester.pumpWidget(MaterialApp(
        home: TeamDetails(
            league: l,
            team: l.presets.first,
            competition: l.competitions.single,
            save: () async {})));
    expect(find.text('Giocatore 0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Giocatore 1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione squadra iscrive partecipante con numeri automatici',
      (tester) async {
    final l = League(
        'l', 'Nuova', [Player('a', 'Alfa'), Player('b', 'Beta')], [],
        type: 'competition',
        competitions: [
          Competition('c', 'C', 'league', 2, [], allowDraft: true)
        ]);
    await tester.pumpWidget(MaterialApp(
        home: TeamEditor(
            league: l,
            save: () async {},
            initialFormat: 2,
            competition: l.competitions.single)));
    await tester.enterText(find.byType(TextFormField), 'Uno');
    for (final name in ['Alfa', 'Beta']) {
      await tester.tap(find.text('Giocatore'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('roster-player-name')), name);
      await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Salva squadra'));
    await tester.pumpAndSettle();
    expect(l.competitions.single.teamIds, [l.presets.single.id]);
    expect(l.presets.single.numbers.values, [1, 2]);
    expect(l.presets.single.players.length, 2);
  });
}
