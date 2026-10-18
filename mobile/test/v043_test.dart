import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/features/matches/goal_page.dart';
import 'package:calcetto_mvp/features/teams/team_presets_page.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';

void main() {
  test('presenze poi vittorie poi gol prima del nome', () {
    final l = League('l', 'L', [
      for (final id in ['a', 'b', 'x', 'y', 'c', 'z', 'd', 'w'])
        Player(
            id,
            id == 'a'
                ? 'Alfa'
                : id == 'b'
                    ? 'Aardvark'
                    : id == 'x'
                        ? 'Zulu'
                        : id)
    ], []);
    void game(String id, List<List<String>> teams, List<String> scorers) {
      final m = Match(id: id, format: 2, names: ['A', 'B'], teams: teams)
        ..start();
      for (var i = 0; i < scorers.length; i++) {
        m.add(Goal(
            id: '$id$i',
            team: 0,
            scorer: scorers[i],
            time: DateTime.now().toUtc().toIso8601String()));
      }
      m.finish();
      l.matches.add(m);
    }

    game('one', [
      ['a', 'x'],
      ['b', 'y']
    ], [
      'x',
      'x'
    ]);
    game('two', [
      ['a', 'x'],
      ['c', 'z']
    ], [
      'a'
    ]);
    game('three', [
      ['b', 'y'],
      ['d', 'w']
    ], [
      'b'
    ]);
    final ids = playersByAppearances(l, null).map((p) => p.id).toList();
    expect(ids.indexOf('x'), lessThan(ids.indexOf('a')));
    expect(ids.indexOf('a'), lessThan(ids.indexOf('b')));
  });
  testWidgets(
      'portiere previsto precede gli altri anche se alfabeticamente ultimo',
      (tester) async {
    final l = League('l', 'L', [
      Player('a', 'Attaccante'),
      Player('b', 'Altro'),
      Player('c', 'Alfa'),
      Player('d', 'Zeta')
    ], []);
    final m = Match(id: 'm', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ], keepers: [
      KeeperPlan.manual(),
      KeeperPlan(mode: 'rotation', order: ['d', 'c'])
    ])
      ..start();
    await tester.pumpWidget(MaterialApp(home: GoalPage(league: l, match: m)));
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attaccante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nessun assist'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Zeta · turno previsto')).dy,
        lessThan(tester.getTopLeft(find.text('Alfa')).dy));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
  testWidgets('rimozione preset conserva partite e identita storiche',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = TeamPreset('p', 'Salvata', ['a', 'b']);
    final m = Match(id: 'm', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ], presetIds: [
      'p',
      null
    ]);
    final l = League('l', 'L', [
      for (final id in ['a', 'b', 'c', 'd']) Player(id, id)
    ], [
      m
    ], presets: [
      p
    ]);
    await tester.pumpWidget(
        MaterialApp(home: TeamPresetsPage(league: l, save: () async {})));
    await tester.tap(find.text('Salvata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina squadra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();
    expect(find.text('Salvata'), findsNothing);
    expect(p.archived, true);
    expect(l.matches.single.presetIds.first, 'p');
    expect(League.fromJson(l.toJson()).presets.single.archived, true);
  });
  test('messaggio Android non contiene istruzioni iOS', () {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    RotationAlerts.instance.coveredUntil = DateTime.now();
    addTearDown(() {
      debugDefaultTargetPlatformOverride = previous;
      RotationAlerts.instance.coveredUntil = null;
    });
    expect(RotationAlerts.instance.scheduleInfo, contains('Android'));
    expect(RotationAlerts.instance.scheduleInfo, isNot(contains('iOS')));
  });
}
