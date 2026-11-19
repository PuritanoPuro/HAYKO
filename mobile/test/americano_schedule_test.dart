import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/americano_schedule.dart';

void main() {
  test('otto giocatori, sette turni: ogni coppia gioca insieme una volta', () {
    final players = List.generate(8, (index) => 'p$index');
    final schedule = generateAmericanoSchedule(
      playerIds: players,
      rounds: 7,
      courts: 2,
      rotatingPairs: true,
      random: Random(42),
    );
    final partners = <String>{};
    expect(schedule.length, 7);
    for (final round in schedule) {
      expect(round.length, 2);
      expect(round.expand((fixture) => fixture).toSet(), players.toSet());
      for (final fixture in round) {
        expect(fixture.length, 4);
        for (final pair in [fixture.sublist(0, 2), fixture.sublist(2, 4)]) {
          pair.sort();
          expect(partners.add(pair.join(':')), isTrue);
        }
      }
    }
    expect(partners.length, 28);
  });

  test('con un campo le presenze sono distribuite', () {
    final players = List.generate(8, (index) => 'p$index');
    final schedule = generateAmericanoSchedule(
      playerIds: players,
      rounds: 8,
      courts: 1,
      rotatingPairs: true,
      random: Random(7),
    );
    final appearances = {for (final player in players) player: 0};
    for (final round in schedule) {
      expect(round.length, 1);
      expect(round.single.toSet().length, 4);
      for (final player in round.single) {
        appearances[player] = appearances[player]! + 1;
      }
    }
    expect(appearances.values.reduce(min), greaterThanOrEqualTo(3));
    expect(appearances.values.reduce(max), lessThanOrEqualTo(5));
  });
}
