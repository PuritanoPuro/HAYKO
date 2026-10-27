import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/matches/match_page.dart';

void main() {
  testWidgets('partita terminata modifica autogol e permette eliminazione',
      (tester) async {
    final match = Match(id: 'm', format: 2, names: [
      'Verdi',
      'Blu'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ])
      ..start()
      ..add(Goal(
          id: 'g',
          team: 0,
          scorer: 'a',
          assist: 'b',
          keeper: 'c',
          time: '2026-10-27T12:00:00Z'))
      ..finish();
    final league = League('l', 'Lega', [
      for (final id in ['a', 'b', 'c', 'd']) Player(id, id)
    ], [
      match
    ]);
    var saves = 0;

    await tester.pumpWidget(MaterialApp(
        home: MatchPage(
            league: league,
            match: match,
            save: () async {
              saves += 1;
            })));

    expect(find.byTooltip('Modifica gol'), findsOneWidget);
    await tester.tap(find.byTooltip('Modifica gol'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica gol'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goal-own-goal-field')));
    await tester.pumpAndSettle();
    expect(find.text('Autore autogol'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-assist-field')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('goal-scorer-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('d').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salva modifiche'));
    await tester.tap(find.text('Salva modifiche'));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(match.goals.single.ownGoal, isTrue);
    expect(match.goals.single.scorer, 'd');
    expect(stats(league, null)['a']!.goals, 0);
    expect(stats(league, null)['b']!.assists, 0);
    expect(stats(league, null)['d']!.ownGoals, 1);

    await tester.tap(find.byTooltip('Modifica gol'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('delete-goal-button')));
    await tester.tap(find.byKey(const ValueKey('delete-goal-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina gol'));
    await tester.pumpAndSettle();

    expect(saves, 2);
    expect(match.score(0), 0);
    expect(find.text('Nessun gol registrato.'), findsOneWidget);
    expect(find.byTooltip('Modifica gol'), findsNothing);
  });
}
