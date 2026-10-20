import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/main.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/features/leagues/league_settings.dart';

League base() => League('l', 'Lega', [
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) Player(id, id)
    ], [], presets: [
      TeamPreset('t1', 'Uno', ['a', 'b']),
      TeamPreset('t2', 'Due', ['c', 'd']),
      TeamPreset('t3', 'Tre', ['e', 'f']),
      TeamPreset('t4', 'Quattro', ['g', 'h']),
    ]);
Match fixture(League l, Competition c, int round, String left, String right) =>
    Match(
        id: newId(),
        format: 2,
        names: [left, right],
        teams: [
          List<String>.from(l.presets.firstWhere((p) => p.id == left).players),
          List<String>.from(l.presets.firstWhere((p) => p.id == right).players)
        ],
        presetIds: [left, right],
        competitionId: c.id,
        knockoutRound: c.kind == 'knockout' ? round : null);

void main() {
  test('migrazione dati precedenti conserva risultato senza inventare date',
      () {
    final m = Match(id: 'm', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ]);
    final l = base()..matches.add(m);
    final json = l.toJson()
      ..remove('primaryColor')
      ..remove('secondaryColor')
      ..remove('presets')
      ..remove('competitions');
    for (final p in json['players'] as List) {
      p.remove('color');
    }
    for (final row in json['matches'] as List) {
      for (final key in [
        'scheduledAt',
        'venue',
        'teamColors',
        'presetIds',
        'competitionId',
        'knockoutRound',
        'qualifiedTeamId'
      ]) {
        row.remove(key);
      }
    }
    final copy = League.fromJson(json);
    expect(copy.matches.single.scheduledAt, isNull);
    expect(copy.presets, isEmpty);
    expect(copy.players.first.color, 0xffbbf568);
  });
  test('dettagli modificabili prima dell’avvio e nessun avvio a orario', () {
    final m = Match(id: 'm', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ]);
    m.editDetails(DateTime.utc(2020), 'Campo passato');
    expect(m.status, 'scheduled');
    m.start();
    expect(() => m.editDetails(DateTime.utc(2026), 'Altro campo'),
        throwsStateError);
  });
  test('colore e preset persistono e il roster della partita è indipendente',
      () {
    final l = base();
    l.primaryColor = 0xffff8800;
    l.secondaryColor = 0xff112233;
    l.players.first.color = 0xffabcd00;
    final c = Competition('c', 'Campionato', 'league', 2, ['t1', 't2']);
    l.competitions.add(c);
    final m = fixture(l, c, 1, 't1', 't2');
    l.matches.add(m);
    m.teams[0][0] = 'e';
    expect(l.presets.first.players.first, 'a');
    final copy = League.fromJson(l.toJson());
    expect(copy.primaryColor, l.primaryColor);
    expect(copy.players.first.color, l.players.first.color);
    expect(copy.competitions.single.id, 'c');
  });
  test('campionato punti, GF e GS derivati dai gol validi', () {
    final l = base(), c = Competition('c', 'C', 'league', 2, ['t1', 't2']);
    l.competitions.add(c);
    final m = fixture(l, c, 1, 't1', 't2')..start();
    m.add(Goal(
        id: 'g',
        team: 0,
        scorer: 'a',
        keeper: 'c',
        time: DateTime.now().toUtc().toIso8601String()));
    m.finish();
    l.matches.add(m);
    final draw = fixture(l, c, 1, 't1', 't2')..start();
    draw.finish();
    l.matches.add(draw);
    final rows = teamStandings(l, c);
    expect(rows.first.team.id, 't1');
    expect(rows.first.points, 4);
    expect(rows.first.goals, 1);
    expect(rows.last.points, 1);
    expect(rows.last.conceded, 1);
  });
  test('torneo sblocca finale soltanto dopo entrambe le semifinali', () {
    final l = base(),
        c = Competition('c', 'Coppa', 'knockout', 2, ['t1', 't2', 't3', 't4']);
    l.competitions.add(c);
    final first = fixture(l, c, 1, 't1', 't2');
    validateCompetitionMatch(l, first);
    l.matches.add(first);
    first.start();
    first.finish(winner: 't1');
    expect(tournamentTies(l, c).length, 2);
    expect(() => validateCompetitionMatch(l, fixture(l, c, 2, 't1', 't3')),
        throwsStateError);
    final second = fixture(l, c, 1, 't3', 't4');
    l.matches.add(second);
    second.start();
    second.finish(winner: 't3');
    final ties = tournamentTies(l, c);
    expect(ties.last.round, 2);
    expect(ties.last.teams, ['t1', 't3']);
    final finalMatch = fixture(l, c, 2, 't1', 't3');
    validateCompetitionMatch(l, finalMatch);
    l.matches.add(finalMatch);
    finalMatch.start();
    finalMatch.finish(winner: 't1');
    expect(tournamentStatus(l, c, 't1'), 'Vincitrice');
    expect(tournamentStatus(l, c, 't3'), 'Eliminata');
  });
  test('pareggio a eliminazione richiede qualificata senza inventare gol', () {
    final l = base(), c = Competition('c', 'C', 'knockout', 2, ['t1', 't2']);
    final m = fixture(l, c, 1, 't1', 't2')..start();
    expect(() => m.finish(), throwsStateError);
    expect(() => m.finish(winner: 't4'), throwsStateError);
    m.finish(winner: 't2');
    expect(m.score(0), 0);
    expect(m.score(1), 0);
    expect(m.qualifiedTeamId, 't2');
  });
  testWidgets('dettagli modificabili visibili solo per partite programmate',
      (tester) async {
    final l = base();
    final m = Match(id: 'm', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ]);
    await tester.pumpWidget(
        MaterialApp(home: MatchPage(league: l, match: m, save: () async {})));
    expect(find.text('Modifica data, ora e luogo'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-score-panel')), findsOneWidget);
    expect(find.text('Tempo partita · 00:00'), findsOneWidget);
    expect(find.text('Registro gol'), findsNothing);
    m.start();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Modifica data, ora e luogo'), findsNothing);
    expect(find.byKey(const ValueKey('live-match')), findsOneWidget);
    expect(find.text('Registro gol'), findsOneWidget);
    expect(find.text('Nessun gol registrato.'), findsOneWidget);
    m.finish();
    await tester.pumpWidget(
        MaterialApp(home: MatchPage(league: l, match: m, save: () async {})));
    await tester.pump();
    expect(find.byKey(const ValueKey('finished-match')), findsOneWidget);
    expect(find.text('GOL'), findsNothing);
    expect(find.text('Termina partita'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('cancellazione lega richiede conferma', (tester) async {
    var removed = 0;
    final l = base();
    await tester.pumpWidget(MaterialApp(
        home: LeagueSettingsPage(
            league: l,
            save: () async {},
            delete: () async {
              removed++;
            })));
    expect(find.text('Colore lega'), findsOneWidget);
    expect(find.text('Colore secondario'), findsNothing);
    await Scrollable.ensureVisible(tester.element(find.text('Elimina lega')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina lega'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare questa lega?'), findsOneWidget);
    expect(find.text(l.name), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(removed, 0);
    await tester.tap(find.text('Elimina lega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina lega').last);
    await tester.pumpAndSettle();
    expect(removed, 1);
  });
  testWidgets('salva preset dal riepilogo della squadra', (tester) async {
    final l = League('l', 'L', [
      Player('a', 'Alfa'),
      Player('b', 'Beta'),
      Player('c', 'Gamma'),
      Player('d', 'Delta')
    ], []);
    await tester.pumpWidget(
        MaterialApp(home: NewMatchPage(league: l, save: () async {})));
    await Scrollable.ensureVisible(
        tester.element(find.byType(DropdownButton<int>)),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 contro 2').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('event-venue')));
    await tester.enterText(
        find.byKey(const ValueKey('event-venue')), 'Campo test');
    await Scrollable.ensureVisible(
        tester.element(find.text('Seleziona formazione')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona formazione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alfa'));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva come squadra'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(TextField)),
        'Squadra blu');
    await tester.tap(find.widgetWithText(FilledButton, 'Conferma').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(l.presets.single.name, 'Squadra blu');
    expect(l.presets.single.players, ['a', 'b']);
  });
}
