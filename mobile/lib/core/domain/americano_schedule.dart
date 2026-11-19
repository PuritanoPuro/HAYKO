import 'dart:math';

/// rounds -> courts -> [first partner, second partner, first opponent,
/// second opponent]. The order of player IDs is stable after confirmation.
typedef AmericanoSchedule = List<List<List<String>>>;

AmericanoSchedule generateAmericanoSchedule({
  required List<String> playerIds,
  required int rounds,
  required int courts,
  required bool rotatingPairs,
  Random? random,
}) {
  if (playerIds.length < 4 ||
      playerIds.length % 4 != 0 ||
      playerIds.toSet().length != playerIds.length ||
      rounds < 1 ||
      courts < 1 ||
      courts > playerIds.length ~/ 4) {
    throw ArgumentError('Configurazione Americano non valida.');
  }

  final rng = random ?? Random.secure();
  final circle = [...playerIds]..shuffle(rng);
  final appearances = {for (final id in playerIds) id: 0};
  final opponents = <String, int>{};
  final result = <List<List<String>>>[];

  int meetings(String a, String b) {
    final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
    return opponents[key] ?? 0;
  }

  void recordMeeting(String a, String b) {
    final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
    opponents[key] = (opponents[key] ?? 0) + 1;
  }

  for (var round = 0; round < rounds; round++) {
    final pairs = <List<String>>[
      for (var i = 0; i < circle.length ~/ 2; i++)
        [circle[i], circle[circle.length - 1 - i]],
    ];
    // Whole pairs rest together. Pick the least-used players first so a
    // smaller number of courts does not consistently exclude the same group.
    pairs.shuffle(rng);
    pairs.sort((a, b) => (appearances[a[0]]! + appearances[a[1]]!)
        .compareTo(appearances[b[0]]! + appearances[b[1]]!));
    final remaining = pairs.take(courts * 2).toList();
    final matches = <List<String>>[];

    while (remaining.isNotEmpty) {
      final first = remaining.removeAt(0);
      var opponentIndex = 0;
      var lowestRepeats = 1 << 30;
      for (var i = 0; i < remaining.length; i++) {
        final score = [
          for (final a in first)
            for (final b in remaining[i]) meetings(a, b),
        ].reduce((a, b) => a + b);
        if (score < lowestRepeats) {
          lowestRepeats = score;
          opponentIndex = i;
        }
      }
      final second = remaining.removeAt(opponentIndex);
      matches.add([...first, ...second]);
      for (final id in [...first, ...second]) {
        appearances[id] = appearances[id]! + 1;
      }
      for (final a in first) {
        for (final b in second) {
          recordMeeting(a, b);
        }
      }
    }
    result.add(matches);

    if (rotatingPairs) {
      final last = circle.removeLast();
      circle.insert(1, last);
    }
  }
  return result;
}
