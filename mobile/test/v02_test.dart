import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/matches/goal_page.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/features/home/home_page.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 12, 14);
  Match match({List<KeeperPlan>? keepers, String id = 'm'}) => Match(
      id: id,
      format: 2,
      names: ['A', 'B'],
      teams: [
        ['a', 'b'],
        ['c', 'd']
      ],
      keepers: keepers);
  League league(Match m) => League('l', 'L', [
        for (final id in ['a', 'b', 'c', 'd']) Player(id, id)
      ], [
        m
      ]);
  Goal goal({String id = 'g', bool own = false, String? keeper = 'c'}) => Goal(
      id: id,
      team: 0,
      scorer: own ? 'd' : 'a',
      assist: own ? null : 'b',
      keeper: keeper,
      ownGoal: own,
      time: epoch.toIso8601String());

  test('migrazione vecchi dati conserva gol e aggiunge modalità manuale', () {
    final m = match()..start();
    m.add(goal());
    final json = m.toJson()
      ..remove('keepers')
      ..remove('creatorId');
    final restored = Match.fromJson(json);
    expect(restored.keepers.every((k) => k.mode == 'manual'), true);
    expect(restored.score(0), 1);
  });
  test('rotazione confini, giro ciclico e prossimo turno', () {
    final p = KeeperPlan(mode: 'rotation', order: ['a', 'b'], minutes: 5);
    expect(
        p.at(epoch, epoch.add(const Duration(minutes: 4, seconds: 59))), 'a');
    expect(p.at(epoch, epoch.add(const Duration(minutes: 5))), 'b');
    expect(p.at(epoch, epoch.add(const Duration(minutes: 10))), 'a');
    expect(p.nextChange(epoch, epoch.add(const Duration(minutes: 5))),
        epoch.add(const Duration(minutes: 10)));
  });
  test('ordine rotazione valido include ogni partecipante una sola volta', () {
    expect(
        () => match(keepers: [
              KeeperPlan(mode: 'rotation', order: ['a', 'a']),
              KeeperPlan.manual()
            ]),
        throwsArgumentError);
    expect(
        () => match(keepers: [
              KeeperPlan(mode: 'fixed', fixed: 'c'),
              KeeperPlan.manual()
            ]),
        throwsArgumentError);
  });
  test('autogol salta assist e portiere fisso salta scelta portiere', () {
    final m = match(
        keepers: [KeeperPlan.manual(), KeeperPlan(mode: 'fixed', fixed: 'c')]);
    expect(goalSteps(m, 0, true), ['team', 'scorer', 'review']);
    expect(goalSteps(m, 0, false), ['team', 'scorer', 'assist', 'review']);
    expect(goalSteps(m, 1, true), ['team', 'scorer', 'keeper', 'review']);
    m.start();
    expect(() => m.add(goal(keeper: 'd')), throwsArgumentError);
  });
  test('editing del nome mantiene identità, gol e coppie', () {
    final m = match()..start();
    m.add(goal());
    m.finish();
    final l = league(m);
    l.players.first.name = 'Nuovo nome';
    expect(stats(l, null)['a']!.goals, 1);
    expect(ranking(l, null, 'pairs').first.label, contains('Nuovo nome'));
  });
  test('classifiche usano media e intesa usa partite insieme anche senza gol',
      () {
    final m1 = match(id: 'm1')..start();
    m1.add(goal());
    m1.finish();
    final m2 = match(id: 'm2')..start();
    m2.finish();
    final l = league(m1)..matches.add(m2);
    expect(ranking(l, null, 'goals').first.average, 0.5);
    final pair = ranking(l, null, 'pairs').first;
    expect(pair.total, 1);
    expect(pair.played, 2);
    expect(pair.average, 0.5);
    expect(ranking(l, 5, 'goals'), isEmpty);
    expect(stats(l, null)['c']!.losses, 1);
  });
  test('avvisi con stessa scadenza raggruppati e limite globale 60', () {
    final m = match(keepers: [
      KeeperPlan(mode: 'rotation', order: ['a', 'b']),
      KeeperPlan(mode: 'rotation', order: ['c', 'd'])
    ]);
    m.status = 'live';
    m.startedAt = epoch.toIso8601String();
    final alerts = rotationNotices([league(m)], epoch);
    expect(alerts.length, 60);
    expect(alerts.first.when, epoch.add(const Duration(minutes: 5)));
    expect(alerts.first.text, contains('b in porta'));
    expect(alerts.first.text, contains('d in porta'));
    m.finish();
    expect(rotationNotices([league(m)], epoch), isEmpty);
  });
  test('notifiche social segnalano solo richieste nuove e approvazioni', () {
    expect(newPendingRequests(null, {'l|u'}), isEmpty);
    expect(newPendingRequests({'l|u'}, {'l|u', 'l|v'}), {'l|v'});
    expect(newlyApprovedRequests(null, {'l': 'approved'}), isEmpty);
    expect(
        newlyApprovedRequests({'l': 'pending', 'x': 'approved'},
            {'l': 'approved', 'x': 'approved'}),
        {'l'});
  });
  testWidgets('autogol va direttamente al portiere senza pagina assist',
      (tester) async {
    final m = match()..start();
    final l = league(m);
    await tester.pumpWidget(MaterialApp(home: GoalPage(league: l, match: m)));
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('d'));
    await tester.pumpAndSettle();
    expect(find.text('Chi era in porta?'), findsOneWidget);
    expect(find.text('Nessun assist'), findsNothing);
    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();
    expect(find.text('Conferma gol'), findsNWidgets(2));
    expect(find.text('Autogol a favore di A'), findsOneWidget);
    expect(find.textContaining('Autore: d'), findsOneWidget);
    expect(find.textContaining('Portiere: c'), findsOneWidget);
    expect(find.textContaining('Assist:'), findsNothing);
  });
  testWidgets('formazione evidenzia selezione e richiede riepilogo',
      (tester) async {
    final l = League('l', 'L', [
      for (final n in [
        'Zeta',
        'Beta',
        'Alfa',
        'Delta',
        'Eta',
        'Gamma',
        'Iota',
        'Kappa',
        'Lambda',
        'Mu'
      ])
        Player(n, n)
    ], []);
    await tester.pumpWidget(MaterialApp(home: NewMatchPage(league: l)));
    await tester.ensureVisible(find.byKey(const ValueKey('event-venue')));
    await tester.enterText(
        find.byKey(const ValueKey('event-venue')), 'Campo test');
    await tester.ensureVisible(find.text('Seleziona formazione'));
    await tester.ensureVisible(find.text('Seleziona formazione'));
    await tester.tap(find.text('Seleziona formazione'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 5 selezionati'), findsOneWidget);
    await tester.tap(find.text('Alfa'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5 selezionati'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('team-player-0-Alfa')),
            matching: find.text('Selezionato')),
        findsOneWidget);
  });
}
