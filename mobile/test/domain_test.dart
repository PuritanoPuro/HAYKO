import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';

void main() {
  Match match() => Match(id: 'm', format: 2, names: [
        'A',
        'B'
      ], teams: [
        ['a', 'b'],
        ['c', 'd']
      ]);
  Goal goal(
          {String id = 'g',
          String? scorer = 'a',
          String? assist = 'b',
          String? keeper = 'c',
          bool own = false}) =>
      Goal(
          id: id,
          team: 0,
          scorer: scorer,
          assist: assist,
          keeper: keeper,
          ownGoal: own,
          time: '2026-10-10T00:00:00Z');
  League league(Match m) => League('l', 'Lega', [
        for (final id in ['a', 'b', 'c', 'd']) Player(id, id)
      ], [
        m
      ]);
  test('gol idempotente, annullamento, persistenza', () {
    final m = match()..start();
    m.add(goal());
    m.add(goal());
    expect(m.score(0), 1);
    m.undo('g');
    expect(m.score(0), 0);
    expect(Match.fromJson(m.toJson()).goals.first.voided, true);
  });
  test('conflitti e assist a se stesso vengono rifiutati', () {
    final m = match()..start();
    expect(() => m.add(goal(assist: 'a')), throwsArgumentError);
    m.add(goal());
    expect(() => m.add(goal(scorer: 'b', assist: null)), throwsStateError);
  });
  test('statistiche solo concluse e coppie senza doppio conteggio', () {
    final m = match()..start();
    m.add(goal());
    final l = league(m);
    expect(stats(l, null)['a']!.goals, 0);
    m.finish();
    expect(stats(l, 2)['a']!.goals, 1);
    expect(stats(l, 5)['a']!.played, 0);
    expect(pairs(l, null)['a|b'], 1);
    expect(stats(l, 2)['c']!.conceded, 1);
  });
  test('autogol non incrementa gol o assist o coppie', () {
    final m = match()..start();
    m.add(goal(scorer: 'c', assist: null, own: true));
    m.finish();
    final s = stats(league(m), null);
    expect(s['c']!.ownGoals, 1);
    expect(s['c']!.goals, 0);
    expect(pairs(league(m), null), isEmpty);
  });
  test('annullamento toglie gol da tutte le statistiche', () {
    final m = match()..start();
    m.add(goal());
    m.undo('g');
    m.finish();
    final l = league(m);
    expect(stats(l, null)['a']!.goals, 0);
    expect(stats(l, null)['b']!.assists, 0);
    expect(stats(l, null)['c']!.conceded, 0);
    expect(pairs(l, null), isEmpty);
  });
  test('modifica e cancellazione gol concluso ricalcolano le statistiche', () {
    final m = match()..start();
    m.add(goal());
    m.finish();
    final l = league(m);
    m.editGoal(goal(scorer: 'c', assist: null, own: true));
    expect(m.score(0), 1);
    expect(stats(l, null)['a']!.goals, 0);
    expect(stats(l, null)['b']!.assists, 0);
    expect(stats(l, null)['c']!.ownGoals, 1);
    m.deleteGoal('g');
    expect(m.score(0), 0);
    expect(stats(l, null)['c']!.ownGoals, 0);
  });
  test('gol non modificabile prima della conclusione o dopo eliminazione', () {
    final m = match()..start();
    m.add(goal());
    expect(() => m.editGoal(goal(scorer: 'b', assist: null)), throwsStateError);
    m.finish();
    m.deleteGoal('g');
    expect(() => m.editGoal(goal(scorer: 'b', assist: null)), throwsStateError);
  });
  test('un giocatore semplice non controlla neppure una partita creata prima',
      () {
    final m = match()..creatorId = 'user';
    final l = league(m)
      ..shared = true
      ..currentUser = 'user'
      ..myRole = 'member';
    expect(l.canRecord(m), isFalse);
    l.myRole = 'admin';
    expect(l.canRecord(m), isTrue);
  });
}
