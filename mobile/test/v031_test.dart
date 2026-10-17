import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';

League sample(int count) => League('l', 'L', [
      for (var i = 0; i < count * 2; i++) Player('p$i', 'Giocatore $i'),
    ], [], presets: [
      for (var i = 0; i < count; i++)
        TeamPreset('t$i', 'Squadra $i', ['p${i * 2}', 'p${i * 2 + 1}'])
    ]);

void main() {
  test(
      'girone pari: ogni coppia una volta e nessuna squadra gioca due volte nella giornata',
      () {
    final l = sample(6),
        c = Competition(
            'c', 'C', 'league', 2, l.presets.map((p) => p.id).toList());
    final fixtures = leagueFixtures(l, c);
    expect(fixtures.length, 15);
    expect(fixtures.map((f) => ([...f.teams]..sort()).join('|')).toSet().length,
        15);
    for (var round = 1; round <= 5; round++) {
      final teams = fixtures
          .where((f) => f.round == round)
          .expand((f) => f.teams)
          .toList();
      expect(teams.length, 6);
      expect(teams.toSet().length, 6);
    }
  });
  test('girone dispari: ogni squadra riposa una volta', () {
    final l = sample(5),
        c = Competition(
            'c', 'C', 'league', 2, l.presets.map((p) => p.id).toList());
    final fixtures = leagueFixtures(l, c);
    expect(fixtures.length, 10);
    for (final id in c.teamIds) {
      expect(fixtures.where((f) => f.teams.contains(id)).length, 4);
    }
    for (var round = 1; round <= 5; round++) {
      expect(
          fixtures
              .where((f) => f.round == round)
              .expand((f) => f.teams)
              .toSet()
              .length,
          4);
    }
  });
  test('statistiche isolate alla competizione e giornata visibile', () {
    final l = sample(2),
        c = Competition('c', 'Coppa', 'league', 2, ['t0', 't1']);
    l.competitions.add(c);
    final m = Match(
        id: 'm',
        format: 2,
        names: ['A', 'B'],
        teams: [
          ['p0', 'p1'],
          ['p2', 'p3']
        ],
        presetIds: ['t0', 't1'],
        competitionId: 'c');
    l.matches.add(m);
    m.start();
    m.finish();
    final other = Match(id: 'other', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['p0', 'p1'],
      ['p2', 'p3']
    ]);
    l.matches.add(other);
    other.start();
    other.finish();
    expect(competitionLabel(l, m), 'Coppa · Giornata 1');
    expect(stats(competitionPlayers(l, c), null)['p0']!.played, 1);
    expect(stats(l, null)['p0']!.played, 2);
  });
  test('sorteggio persistente definisce gli accoppiamenti del torneo', () {
    final l = sample(4),
        c = Competition('c', 'Coppa', 'knockout', 2, ['t2', 't0', 't3', 't1']);
    l.competitions.add(c);
    final copy = League.fromJson(l.toJson());
    expect(tournamentTies(copy, copy.competitions.single).first.teams,
        ['t2', 't0']);
  });
  testWidgets(
      'creazione partita competizione mostra menu delle squadre iscritte',
      (tester) async {
    final l = sample(3);
    l.competitions.add(Competition('c', 'C', 'league', 2, ['t0', 't1']));
    await tester.pumpWidget(
        MaterialApp(home: NewMatchPage(league: l, initialCompetition: 'c')));
    final a = find.byKey(const ValueKey('competition-team-0'));
    final b = find.byKey(const ValueKey('competition-team-1'));
    expect(a, findsOneWidget);
    expect(b, findsOneWidget);
    expect(tester.widget<DropdownButton<String>>(a).items!.map((i) => i.value),
        ['t0', 't1']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione squadra permette aggiunta giocatori e salva roster',
      (tester) async {
    final l = sample(1);
    await tester.pumpWidget(MaterialApp(
        home: TeamEditor(league: l, save: () async {}, initialFormat: 2)));
    await tester.enterText(find.byType(TextFormField), 'Nuova squadra');
    await tester.tap(find.text('Giocatore 0'));
    await tester.tap(find.text('Giocatore 1'));
    await tester.pump();
    expect(find.text('+ Giocatore'), findsOneWidget);
    await tester.tap(find.text('Salva squadra'));
    await tester.pumpAndSettle();
    expect(l.presets.last.name, 'Nuova squadra');
    expect(l.presets.last.players, ['p0', 'p1']);
  });
  testWidgets(
      'aggiunta giocatore durante creazione squadra persiste nella lega',
      (tester) async {
    final l = sample(1);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: TeamEditor(
            league: l,
            save: () async {
              saves++;
            },
            initialFormat: 2)));
    await tester.tap(find.text('+ Giocatore'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        'Nuovo');
    await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.pumpAndSettle();
    expect(l.players.last.name, 'Nuovo');
    expect(saves, 1);
    expect(find.text('Nuovo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
