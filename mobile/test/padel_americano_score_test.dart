import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/americano_flow.dart';
import 'package:calcetto_mvp/core/domain/americano_result.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_score_page.dart';

void main() {
  test('il risultato conserva i punti, annulla l’ultimo e non supera il limite',
      () {
    final result = AmericanoCourtResult();
    result.addPoint(0, 8);
    result.addPoint(1, 8);
    expect([result.scoreFor(0), result.scoreFor(1)], [1, 1]);
    result.undoLastPoint();
    expect([result.scoreFor(0), result.scoreFor(1)], [1, 0]);
    for (var index = 0; index < 7; index++) {
      result.addPoint(index.isEven ? 0 : 1, 8);
    }
    expect(result.points.length, 8);
    expect(() => result.addPoint(0, 8), throwsStateError);
    result.finish(8);
    expect(() => result.undoLastPoint(), throwsStateError);
    expect(AmericanoCourtResult.fromJson(result.toJson()).scoreFor(0), 5);
  });

  test('sospensione e ripresa escludono la pausa dal tempo', () {
    final result = AmericanoCourtResult(startedAt: '2026-11-20T10:00:00.000Z');
    result.pause(DateTime.utc(2026, 11, 20, 10, 2));
    expect(result.elapsed(DateTime.utc(2026, 11, 20, 10, 4)).inSeconds, 120);
    result.resume(DateTime.utc(2026, 11, 20, 10, 5));
    expect(result.elapsed(DateTime.utc(2026, 11, 20, 10, 6)).inSeconds, 180);
    final restored = AmericanoCourtResult.fromJson(result.toJson());
    expect(restored.pausedSeconds, 180);
    expect(restored.elapsed(DateTime.utc(2026, 11, 20, 10, 6)).inSeconds, 180);
  });

  testWidgets('un doppio tocco durante il salvataggio conta un solo punto',
      (tester) async {
    final players = [
      Player('a', 'Andrea'),
      Player('b', 'Bianca'),
      Player('c', 'Carlo'),
      Player('d', 'Daria'),
    ];
    final competition = Competition('c', 'Americano', 'americano', 2, const [],
        americanoPlayerCount: 4,
        americanoCourts: 1,
        americanoRounds: 3,
        americanoTargetPoints: 8,
        americanoTurnStatus: 'live',
        americanoPlayerIds: ['a', 'b', 'c', 'd'],
        americanoSchedule: [
          [
            ['a', 'b', 'c', 'd']
          ],
          [
            ['a', 'c', 'b', 'd']
          ],
          [
            ['a', 'd', 'b', 'c']
          ],
        ]);
    ensureAmericanoResults(competition);
    final league = League('l', 'Lega', players, const [],
        sport: LeagueSport.padel,
        type: 'competition',
        competitions: [competition]);
    final firstSave = Completer<void>();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: PadelAmericanoScorePage(
        league: league,
        competition: competition,
        courtIndex: 0,
        save: () async {
          saves++;
          if (saves == 1) await firstSave.future;
        },
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('americano-point-first')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('americano-point-first')));
    await tester.pump();
    expect(saves, 1);
    expect(competition.americanoResults[0][0].scoreFor(0), 1);
    firstSave.complete();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('americano-undo-point')));
    await tester.pump();
    expect(saves, 2);
    expect(competition.americanoResults[0][0].points, isEmpty);
  });
}
