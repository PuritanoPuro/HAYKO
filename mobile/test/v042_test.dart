import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/main.dart';
import 'package:calcetto_mvp/features/competitions/competition_hub.dart';
import 'package:calcetto_mvp/features/competitions/competition_match_form.dart';

League sample({String kind = 'knockout'}) => League('l', 'Coppa',
    [for (var i = 0; i < 8; i++) Player('p$i', 'Giocatore $i')], [],
    type: 'competition',
    presets: [
      for (var i = 0; i < 4; i++)
        TeamPreset('t$i', 'Squadra $i', ['p${i * 2}', 'p${i * 2 + 1}'])
    ],
    competitions: [
      Competition('c', 'Coppa', kind, 2, ['t0', 't1', 't2', 't3'])
    ]);

void main() {
  testWidgets('configurazione torneo usa slot e filtro delle fasi',
      (tester) async {
    final l = sample();
    await tester.pumpWidget(MaterialApp(
        home: CalendarOrder(league: l, competition: l.competitions.single)));
    expect(find.text('Fase del torneo'), findsOneWidget);
    final phase = find.byKey(const ValueKey('calendar-round-select'));
    expect(
        tester
            .widget<DropdownButton<int>>(phase)
            .items!
            .map((item) => item.value),
        [1, 2]);
    expect(find.text('Incontro 1'), findsOneWidget);
    expect(find.text('Incontro 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-slot-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-slot-1-1')), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);
    await tester.tap(phase);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finale').last);
    await tester.pumpAndSettle();
    expect(find.text('Da definire dal turno precedente'), findsNWidgets(2));
  });
  testWidgets('selezionare una squadra scambia gli slot senza duplicati',
      (tester) async {
    final l = sample(kind: 'league');
    await tester.pumpWidget(MaterialApp(
        home: CalendarOrder(league: l, competition: l.competitions.single)));
    final first = find.byKey(const ValueKey('calendar-slot-0-0'));
    final original = tester.widget<DropdownButton<String>>(first).value;
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squadra 2').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<String>>(first).value, 't2');
    final values = find
        .byType(DropdownButton<String>)
        .evaluate()
        .map((element) => (element.widget as DropdownButton<String>).value)
        .whereType<String>()
        .toList();
    expect(values.toSet().length, values.length);
    expect(values, contains(original));
  });
  testWidgets('programmazione incontro scelto non ripete selezione squadre',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CompetitionMatchForm(
            league: sample(), initialTeams: const ['t0', 't1'])));
    expect(find.text('Partita della competizione'), findsOneWidget);
    expect(find.text('Squadra 0'), findsOneWidget);
    expect(find.text('Squadra 1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byKey(const ValueKey('event-venue')), findsOneWidget);
  });
  testWidgets('accesso diretto offre un menu di incontri del calendario',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CompetitionMatchForm(league: sample(kind: 'league'))));
    final menu = find.byKey(const ValueKey('calendar-fixture-select'));
    expect(menu, findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(tester.widget<DropdownButton<String>>(menu).items!.length, 6);
  });
  testWidgets('piu partita nella competizione apre calendario', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LeaguePage(league: sample(), save: () async {})));
    await tester.tap(find.text('+ Partita'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    expect(find.text('Genera calendario casuale'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('partita di campionato mostra giornata formato e data',
      (tester) async {
    final l = sample(kind: 'league');
    l.matches.add(Match(
        id: 'm',
        format: 2,
        names: const ['Squadra 0', 'Squadra 3'],
        teams: const [
          ['p0', 'p1'],
          ['p6', 'p7']
        ],
        presetIds: const ['t0', 't3'],
        teamColors: const [0xffff7a3d, 0xffe3f24a],
        competitionId: 'c',
        competitionRules: true,
        scheduledAt: DateTime(2026, 10, 16, 21).toUtc().toIso8601String()));
    await tester.pumpWidget(
        MaterialApp(home: LeaguePage(league: l, save: () async {})));
    expect(find.text('Partite programmate'), findsOneWidget);
    expect(find.textContaining('Giornata 1 · 2v2'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
  testWidgets('filtro fasi offre anche finale ancora da definire',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CompetitionStatistics(league: sample()))));
    final filter = find.byKey(const ValueKey('tournament-phase-filter'));
    expect(
        tester.widget<DropdownButton<int>>(filter).items!.map((i) => i.value),
        [1, 2]);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finale').last);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Le squadre di questa fase saranno definite al termine della fase precedente.'),
        findsOneWidget);
    expect(find.text('Squadra 0 – Squadra 1'), findsNothing);
  });
  testWidgets('statistiche competizione limitano anteprima e aprono classifica',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l = sample(kind: 'league')..myPlayer = 'p1';
    final m = Match(
        id: 'm',
        format: 2,
        names: const ['Squadra 0', 'Squadra 1'],
        teams: const [
          ['p0', 'p1'],
          ['p2', 'p3']
        ],
        presetIds: const ['t0', 't1'],
        competitionId: 'c',
        competitionRules: true)
      ..start();
    for (final goal in const [
      ['p0', 'p1', '0'],
      ['p1', 'p0', '0'],
      ['p2', 'p3', '1'],
      ['p3', 'p2', '1'],
    ]) {
      m.add(Goal(
          id: goal[0],
          team: int.parse(goal[2]),
          scorer: goal[0],
          assist: goal[1],
          time: DateTime.now().toUtc().toIso8601String()));
    }
    m.finish();
    l.matches.add(m);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompetitionStatistics(league: l))));
    expect(find.text('Classifica squadre'), findsOneWidget);
    expect(find.text('Vedi tutti i marcatori'), findsOneWidget);
    expect(find.text('Giocatore 1 · Tu'), findsNWidgets(2));
    await tester.tap(find.text('Vedi tutti i marcatori'));
    await tester.pumpAndSettle();
    expect(find.text('Marcatori'), findsOneWidget);
    expect(find.text('Giocatore 3'), findsOneWidget);
    expect(find.text('Giocatore 1 · Tu'), findsOneWidget);
  });
  testWidgets('finale conclusa mostra risultato e vincitrice', (tester) async {
    final l = sample();

    Match finished(String id, int round, List<String> teams, String winner) {
      final indexes = teams
          .map((team) => l.competitions.single.teamIds.indexOf(team))
          .toList();
      final match = Match(
          id: id,
          format: 2,
          names: teams.map((team) => 'Squadra ${team.substring(1)}').toList(),
          teams: indexes
              .map((index) => ['p${index * 2}', 'p${index * 2 + 1}'])
              .toList(),
          presetIds: teams,
          competitionId: 'c',
          competitionRules: true,
          knockoutRound: round)
        ..start();
      match.finish(winner: winner);
      return match;
    }

    l.matches.addAll([
      finished('s1', 1, ['t0', 't1'], 't0'),
      finished('s2', 1, ['t2', 't3'], 't2'),
      finished('f', 2, ['t0', 't2'], 't0'),
    ]);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompetitionStatistics(league: l))));

    final filter = tester.widget<DropdownButton<int>>(
        find.byKey(const ValueKey('tournament-phase-filter')));
    expect(filter.value, 2);
    expect(find.text('Finale · Passa Squadra 0'), findsOneWidget);
    expect(find.text('Squadra 0 · Vincitrice'), findsOneWidget);
  });
}
