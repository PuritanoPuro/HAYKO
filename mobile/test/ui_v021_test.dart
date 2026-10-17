import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/main.dart';

void main() {
  Match match(String id, List<List<String>> teams,
          {String status = 'finished'}) =>
      Match(
          id: id,
          format: 2,
          names: ['${id}A', '${id}B'],
          teams: teams,
          status: status);
  test('cronometro supera un’ora e si congela alla fine', () {
    final m = match(
        'm',
        [
          ['a', 'b'],
          ['c', 'd']
        ],
        status: 'live');
    final start = DateTime.utc(2026, 10, 12, 14);
    m.startedAt = start.toIso8601String();
    expect(clockText(matchElapsed(m, start.add(const Duration(minutes: 5)))),
        '05:00');
    m.finishedAt = start
        .add(const Duration(hours: 1, minutes: 2, seconds: 7))
        .toIso8601String();
    m.status = 'finished';
    expect(clockText(matchElapsed(m, start.add(const Duration(days: 2)))),
        '01:02:07');
    expect(matchElapsed(m, start.subtract(const Duration(seconds: 1))),
        const Duration(hours: 1, minutes: 2, seconds: 7));
  });
  test('tabella ordinata per presenze, con nome come spareggio', () {
    final l = League('l', 'L', [
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) Player(id, id)
    ], [
      match('one', [
        ['a', 'b'],
        ['c', 'd']
      ]),
      match('two', [
        ['a', 'e'],
        ['b', 'f']
      ]),
    ]);
    expect(playersByAppearances(l, null).map((p) => p.id).take(2), ['a', 'b']);
    l.players.first.name = 'Zeta';
    expect(playersByAppearances(l, null).map((p) => p.id).take(2), ['b', 'a']);
    expect(playersByAppearances(l, 5).first.id, 'b');
  });
  testWidgets('conteggio e conferma rimangono fissi scorrendo il roster',
      (tester) async {
    final l = League('l', 'L', [
      for (var i = 0; i < 40; i++)
        Player('$i', 'Giocatore ${i.toString().padLeft(2, '0')}')
    ], []);
    await tester.pumpWidget(MaterialApp(home: NewMatchPage(league: l)));
    await tester.ensureVisible(find.byKey(const ValueKey('event-venue')));
    await tester.enterText(
        find.byKey(const ValueKey('event-venue')), 'Campo test');
    await Scrollable.ensureVisible(
        tester.element(find.text('Seleziona formazione')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
        tester.element(find.text('Seleziona formazione')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona formazione'));
    await tester.pumpAndSettle();
    final counter = find.byKey(const ValueKey('selection-counter'));
    final button = find.byKey(const ValueKey('selection-confirm'));
    final counterBefore = tester.getRect(counter),
        buttonBefore = tester.getRect(button);
    await tester.drag(
        find.byKey(const ValueKey('team-roster-0')), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.getRect(counter), counterBefore);
    expect(tester.getRect(button), buttonBefore);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });
  testWidgets('portieri riordinabili trascinando un contenitore',
      (tester) async {
    final l = League('l', 'L', [
      Player('a', 'Alfa'),
      Player('b', 'Beta'),
      Player('c', 'Delta'),
      Player('d', 'Gamma')
    ], []);
    await tester.pumpWidget(MaterialApp(home: NewMatchPage(league: l)));
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
    Future<void> pickTeam(List<String> names) async {
      for (final name in names) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('selection-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma').last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    await pickTeam(['Alfa', 'Beta']);
    await pickTeam(['Delta', 'Gamma']);
    final a = find.byKey(const ValueKey('keeper-0-a')),
        b = find.byKey(const ValueKey('keeper-0-b'));
    final aFirst = tester.getTopLeft(a).dy < tester.getTopLeft(b).dy;
    final first = aFirst ? a : b, second = aFirst ? b : a;
    final before = tester.getTopLeft(first).dy;
    final origin = tester.getCenter(first);
    final destination = tester.getCenter(second) + const Offset(0, 12);
    // Parte dal centro del contenitore, anche quando lì non c'è testo.
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    for (var step = 1; step <= 16; step++) {
      await gesture.moveTo(origin + (destination - origin) * (step / 16));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dy, greaterThan(before));
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
  });
  testWidgets('partite separate per stato e dot presente se una è live',
      (tester) async {
    final teams = [
      ['a', 'b'],
      ['c', 'd']
    ];
    final l = League('l', 'L', [
      for (final id in ['a', 'b', 'c', 'd']) Player(id, id)
    ], [
      match('next', teams, status: 'scheduled'),
      match('live', teams, status: 'live'),
      match('end', teams),
    ]);
    await tester.pumpWidget(
        MaterialApp(home: LeaguePage(league: l, save: () async {})));
    expect(find.byKey(const ValueKey('live-match-dot')), findsOneWidget);
    expect(find.text('liveA 0 – 0 liveB'), findsOneWidget);
    expect(find.text('endA 0 – 0 endB'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('match-tab-finished')));
    await tester.pumpAndSettle();
    expect(find.text('Partite terminate'), findsOneWidget);
    expect(find.text('endA 0 – 0 endB'), findsOneWidget);
    expect(find.text('liveA 0 – 0 liveB'), findsNothing);
  });
}
