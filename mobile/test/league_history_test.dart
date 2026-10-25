import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/leagues/league_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  League historyLeague() {
    final players = [
      for (final id in ['a', 'b', 'c', 'd']) Player(id, id),
    ];
    final matches = <Match>[];
    for (var index = 0; index < 15; index++) {
      final year = index < 3 ? 2025 : 2026;
      matches.add(Match(
        id: 'm$index',
        format: 2,
        names: ['A$index', 'B$index'],
        teams: const [
          ['a', 'b'],
          ['c', 'd'],
        ],
        status: 'finished',
        startedAt: DateTime.utc(year, 1, index + 1).toIso8601String(),
        finishedAt: DateTime.utc(year, 1, index + 1, 1).toIso8601String(),
      ));
    }
    return League('l', 'Lega', players, matches);
  }

  testWidgets('storico mostra dieci partite, filtra per anno e carica altre',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LeaguePage(league: historyLeague(), save: () async {}),
    ));

    await tester.tap(find.byKey(const ValueKey('match-tab-finished')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Mostra altre (5)'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Mostra altre (5)'), findsOneWidget);

    await tester.tap(find.text('Mostra altre (5)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mostra altre'), findsNothing);

    final filter = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('finished-period-filter')));
    filter.onChanged!('2025');
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('finished-period-filter')))
            .value,
        '2025');
    expect(find.textContaining('Mostra altre'), findsNothing);
    expect(find.text('A14'), findsNothing);
  });
}
