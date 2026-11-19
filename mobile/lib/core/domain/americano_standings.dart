import 'package:calcetto_mvp/core/domain/competition_domain.dart';

class AmericanoStanding {
  const AmericanoStanding({
    required this.playerId,
    required this.rank,
    required this.points,
    required this.wins,
    required this.losses,
    required this.difference,
  });

  final String playerId;
  final int rank;
  final int points;
  final int wins;
  final int losses;
  final int difference;
}

/// Only finished encounters count. A corrected encounter is recalculated
/// from its current point sequence, so standings never need a separate sync.
List<AmericanoStanding> americanoStandings(
  Competition competition, {
  required int throughRound,
}) {
  final totals = <String, _StandingTotals>{
    for (final id in competition.americanoPlayerIds) id: _StandingTotals(),
  };
  final lastRound = competition.americanoSchedule.isEmpty
      ? -1
      : throughRound.clamp(0, competition.americanoSchedule.length - 1);
  for (var round = 0; round <= lastRound; round++) {
    if (round >= competition.americanoResults.length) break;
    final fixtures = competition.americanoSchedule[round];
    final results = competition.americanoResults[round];
    for (var court = 0;
        court < fixtures.length && court < results.length;
        court++) {
      final result = results[court];
      if (!result.finished) continue;
      final fixture = fixtures[court];
      final first = result.scoreFor(0);
      final second = result.scoreFor(1);
      for (var side = 0; side < 2; side++) {
        for (final id in fixture.skip(side * 2).take(2)) {
          final total = totals[id];
          if (total == null) continue;
          total.points += side == 0 ? first : second;
          total.difference += side == 0 ? first - second : second - first;
          if (first > second) {
            if (side == 0) {
              total.wins++;
            } else {
              total.losses++;
            }
          } else if (second > first) {
            if (side == 1) {
              total.wins++;
            } else {
              total.losses++;
            }
          }
        }
      }
    }
  }
  final ids = totals.keys.toList()
    ..sort((a, b) {
      final first = totals[a]!;
      final second = totals[b]!;
      final points = second.points.compareTo(first.points);
      if (points != 0) return points;
      final wins = second.wins.compareTo(first.wins);
      if (wins != 0) return wins;
      final difference = second.difference.compareTo(first.difference);
      if (difference != 0) return difference;
      final losses = first.losses.compareTo(second.losses);
      if (losses != 0) return losses;
      return competition.americanoPlayerIds
          .indexOf(a)
          .compareTo(competition.americanoPlayerIds.indexOf(b));
    });
  final standings = <AmericanoStanding>[];
  var rank = 0;
  _StandingTotals? previous;
  for (var index = 0; index < ids.length; index++) {
    final total = totals[ids[index]]!;
    if (previous == null ||
        total.points != previous.points ||
        total.wins != previous.wins ||
        total.difference != previous.difference ||
        total.losses != previous.losses) {
      rank = index + 1;
    }
    standings.add(AmericanoStanding(
      playerId: ids[index],
      rank: rank,
      points: total.points,
      wins: total.wins,
      losses: total.losses,
      difference: total.difference,
    ));
    previous = total;
  }
  return standings;
}

class _StandingTotals {
  int points = 0;
  int wins = 0;
  int losses = 0;
  int difference = 0;
}
