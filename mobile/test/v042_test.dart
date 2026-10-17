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
  testWidgets('configurazione torneo distingue i due incontri', (tester) async {
    final l = sample();
    await tester.pumpWidget(MaterialApp(
        home: CalendarOrder(league: l, competition: l.competitions.single)));
    expect(find.text('Incontro 1'), findsOneWidget);
    expect(find.text('Incontro 2'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Squadra 1')).dy,
        lessThan(tester.getTopLeft(find.text('Incontro 2')).dy));
  });
  testWidgets('programmazione incontro scelto non ripete selezione squadre',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CompetitionMatchForm(
            league: sample(), initialTeams: const ['t0', 't1'])));
    expect(find.text('Squadra 0 – Squadra 1'), findsOneWidget);
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
    await tester.tap(find.text('Partita'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    expect(find.text('Genera calendario casuale'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('filtro fasi offre anche finale ancora da definire',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CompetitionStatistics(league: sample()))));
    final filter = find.byKey(const ValueKey('tournament-phase-filter'));
    expect(
        tester.widget<DropdownButton<int>>(filter).items!.map((i) => i.value),
        [0, 1, 2]);
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
}
