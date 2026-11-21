import 'package:calcetto_mvp/core/domain/domain.dart';

abstract final class PadelScoring {
  static int requiredSets(Match match) => (match.padelBestOf ~/ 2) + 1;

  /// Ordine dei quattro battitori, con alternanza tra le coppie a ogni game.
  /// Nel tie-break il primo serve una volta, poi gli altri due punti ciascuno.
  static String servingPlayerId(Match match) {
    final firstId = match.padelFirstServerId ?? match.teams[0].first;
    final firstTeam = match.teams[0].contains(firstId) ? 0 : 1;
    final otherTeam = 1 - firstTeam;
    final firstMate = match.teams[firstTeam].firstWhere((id) => id != firstId);
    final order = [
      firstId,
      match.teams[otherTeam][0],
      firstMate,
      match.teams[otherTeam][1],
    ];
    var completedGames = 0;
    for (var i = 0; i < match.padelSetScores.length; i++) {
      // Nel super tie-break il punteggio del set sono punti, non game.
      if (i == match.padelBestOf - 1 &&
          match.padelDecidingSet == 'super_tiebreak_10') {
        continue;
      }
      completedGames += match.padelSetScores[i][0] + match.padelSetScores[i][1];
    }
    if (!_isTieBreak(match)) return order[completedGames % 4];
    final points = _numericPoint(match.padelPoints[0]) +
        _numericPoint(match.padelPoints[1]);
    final extraTurns = points == 0 ? 0 : 1 + ((points - 1) ~/ 2);
    return order[(completedGames + extraTurns) % 4];
  }

  static int? setWinner(Match match, int index) {
    if (index < 0 || index >= match.padelSetScores.length) return null;
    final set = match.padelSetScores[index];
    if (set.length != 2 || set[0] == set[1]) return null;
    final winner = set[0] > set[1] ? 0 : 1;
    final mine = set[winner], other = set[1 - winner];
    if (index == match.padelBestOf - 1 &&
        match.padelDecidingSet == 'super_tiebreak_10') {
      return mine >= 10 && mine - other >= 2 ? winner : null;
    }
    if (mine >= 6 && mine - other >= 2) return winner;
    final fullDeciding =
        index == match.padelBestOf - 1 && match.padelDecidingSet == 'full_set';
    return !fullDeciding && mine == 7 && other == 6 ? winner : null;
  }

  static int wonSets(Match match, int team) => [
        for (var i = 0; i < match.padelSetScores.length; i++)
          if (setWinner(match, i) == team) i,
      ].length;

  static void awardPoint(Match match, int team) {
    if (match.status != 'live' || team < 0 || team > 1) {
      throw StateError('Partita Padel non in corso.');
    }
    if (match.padelSetScores.isEmpty) match.padelSetScores.add([0, 0]);
    match.padelSetStartedAt ??= DateTime.now().toUtc().toIso8601String();
    match.padelPointTotals[team]++;
    if (_isTieBreak(match)) {
      _awardTieBreakPoint(match, team);
    } else {
      _awardGamePoint(match, team);
    }
  }

  static bool _isDecidingSet(Match match) =>
      match.padelSetScores.length == match.padelBestOf;

  static bool _isSuperTieBreak(Match match) =>
      _isDecidingSet(match) && match.padelDecidingSet == 'super_tiebreak_10';

  static bool _isTieBreak(Match match) {
    if (match.padelSetScores.isEmpty) return false;
    if (_isSuperTieBreak(match)) return true;
    final games = match.padelSetScores.last;
    if (games[0] != 6 || games[1] != 6) return false;
    return !(_isDecidingSet(match) && match.padelDecidingSet == 'full_set');
  }

  static int _numericPoint(String value) => int.tryParse(value) ?? 0;

  static void _awardTieBreakPoint(Match match, int team) {
    final other = 1 - team;
    final points = [
      _numericPoint(match.padelPoints[0]),
      _numericPoint(match.padelPoints[1])
    ];
    points[team]++;
    match.padelPoints
      ..clear()
      ..addAll(points.map((point) => '$point'));
    final target = _isSuperTieBreak(match) ? 10 : 7;
    if (points[team] < target || points[team] - points[other] < 2) return;
    if (_isSuperTieBreak(match)) {
      match.padelSetScores.last
        ..[0] = points[0]
        ..[1] = points[1];
    } else {
      match.padelSetScores.last[team]++;
    }
    _completeSet(match, team);
  }

  static void _awardGamePoint(Match match, int team) {
    final other = 1 - team;
    final mine = match.padelPoints[team];
    final theirs = match.padelPoints[other];
    if (mine == 'AD') {
      _winGame(match, team);
      return;
    }
    if (theirs == 'AD') {
      match.padelPoints[other] = '40';
      return;
    }
    const next = {'0': '15', '15': '30', '30': '40'};
    if (next.containsKey(mine)) {
      match.padelPoints[team] = next[mine]!;
      return;
    }
    if (mine == '40' && theirs == '40' && match.padelGameRule == 'advantages') {
      match.padelPoints[team] = 'AD';
      return;
    }
    _winGame(match, team);
  }

  static void _winGame(Match match, int team) {
    final other = 1 - team;
    final games = match.padelSetScores.last;
    games[team]++;
    _resetPoints(match);
    final fullDecidingSet =
        _isDecidingSet(match) && match.padelDecidingSet == 'full_set';
    final wonByTwo = games[team] >= 6 && games[team] - games[other] >= 2;
    final wonAtSevenFive =
        !fullDecidingSet && games[team] == 7 && games[other] == 5;
    if (wonByTwo || wonAtSevenFive) _completeSet(match, team);
  }

  static void _completeSet(Match match, int team) {
    _resetPoints(match);
    final now = DateTime.now().toUtc();
    final started = match.padelSetStartedAt == null
        ? now
        : DateTime.parse(match.padelSetStartedAt!);
    match.padelSetDurationsSeconds.add(now.difference(started).inSeconds);
    if (wonSets(match, team) >= requiredSets(match)) {
      match.padelSetStartedAt = null;
      match.finish();
    } else if (match.padelSetScores.length < match.padelBestOf) {
      match.padelSetScores.add([0, 0]);
      match.padelSetStartedAt = now.toIso8601String();
    }
  }

  static void _resetPoints(Match match) {
    match.padelPoints
      ..clear()
      ..addAll(const ['0', '0']);
  }
}
