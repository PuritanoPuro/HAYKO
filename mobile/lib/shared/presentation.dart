import 'package:calcetto_mvp/core/domain/domain.dart';

List<Player> playersByAppearances(League l, int? format) {
  final totals = stats(l, format);
  return [...l.players]..sort((a, b) {
      final count = totals[b.id]!.played.compareTo(totals[a.id]!.played);
      if (count != 0) return count;
      final wins = totals[b.id]!.wins.compareTo(totals[a.id]!.wins);
      if (wins != 0) return wins;
      final goals = totals[b.id]!.goals.compareTo(totals[a.id]!.goals);
      return goals != 0
          ? goals
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

Duration matchElapsed(Match m, DateTime now) {
  if (m.startedAt == null) return Duration.zero;
  final end = m.finishedAt == null ? now : DateTime.parse(m.finishedAt!);
  final elapsed = end.difference(DateTime.parse(m.startedAt!));
  return elapsed.isNegative ? Duration.zero : elapsed;
}

String clockText(Duration duration) {
  final seconds = duration.isNegative ? 0 : duration.inSeconds;
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${(seconds ~/ 3600).toString().padLeft(2, '0')}:$minutes:$rest'
      : '$minutes:$rest';
}
