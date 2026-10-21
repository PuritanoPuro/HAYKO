import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/features/matches/goal_page.dart';
import 'package:calcetto_mvp/features/teams/team_presets_page.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/statistics/statistics_page.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/design_system/hayko_theme.dart';

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
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('goal-player-d'))).dy,
        lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('goal-player-c'))).dy));
    expect(find.text('Turno previsto'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
  testWidgets('statistiche evidenziano il giocatore collegato all account',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final match = Match(id: 'm', format: 2, names: [
      'A',
      'B'
    ], teams: [
      ['a', 'b'],
      ['c', 'd']
    ])
      ..start()
      ..add(Goal(
          id: 'g',
          team: 0,
          scorer: 'a',
          time: DateTime.now().toUtc().toIso8601String()))
      ..finish();
    final league = League('l', 'L', [
      for (final id in ['a', 'b', 'c', 'd']) Player(id, id),
    ], [
      match
    ])
      ..myPlayer = 'b';

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: StatisticsPage(league: league))));

    final currentRow = tester
        .widget<Container>(find.byKey(const ValueKey('statistics-row-b')));
    final firstRow = tester
        .widget<Container>(find.byKey(const ValueKey('statistics-row-a')));
    expect((currentRow.decoration as BoxDecoration).color,
        HaykoColors.fieldSurface);
    expect(
        (firstRow.decoration as BoxDecoration).color, HaykoColors.fieldSurface);
    final header = tester
        .widget<Container>(find.byKey(const ValueKey('statistics-header')));
    expect((header.decoration as BoxDecoration).color, HaykoColors.fieldLine);
    expect(find.byKey(const ValueKey('statistics-current-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-current-a')), findsNothing);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal),
        findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('ranking-b')));
    await tester.pumpAndSettle();
    final currentRanking =
        tester.widget<Container>(find.byKey(const ValueKey('ranking-b')));
    final firstRanking =
        tester.widget<Container>(find.byKey(const ValueKey('ranking-a')));
    expect(
        ((currentRanking.decoration as BoxDecoration).border as Border)
            .top
            .color,
        HaykoColors.chalk);
    expect(
        ((firstRanking.decoration as BoxDecoration).border as Border).top.color,
        HaykoColors.fieldSurface);
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
  testWidgets('dialoghi compatti e selettore orario usano le rotelle HAYKO',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: buildHaykoTheme(),
        home: Builder(
            builder: (context) => Column(children: [
                  TextButton(
                      onPressed: () => confirm(
                          context, 'Terminare la partita?', 'Confermi?'),
                      child: const Text('Conferma partita')),
                  TextButton(
                      onPressed: () => chooseHaykoTime(
                          context, const TimeOfDay(hour: 18, minute: 30)),
                      child: const Text('Orario')),
                ]))));

    await tester.tap(find.text('Conferma partita'));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const ValueKey('hayko-dialog-panel'))).height,
        lessThan(360));
    await tester.tap(find.text('Indietro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orario'));
    await tester.pumpAndSettle();
    expect(find.text('Ore'), findsOneWidget);
    expect(find.text('Minuti'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.byType(TimePickerDialog), findsNothing);
  });
}
