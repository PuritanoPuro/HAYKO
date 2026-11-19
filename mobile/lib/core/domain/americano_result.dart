/// Each point records the side (0 or 1) that won it. Keeping the sequence
/// makes the last point reversible without guessing which pair scored.
class AmericanoCourtResult {
  AmericanoCourtResult({
    List<int>? points,
    this.finished = false,
    this.startedAt,
    this.pausedAt,
    this.finishedAt,
    this.pausedSeconds = 0,
  }) : points = points ?? <int>[];

  final List<int> points;
  bool finished;
  String? startedAt;
  String? pausedAt;
  String? finishedAt;
  int pausedSeconds;

  int scoreFor(int side) => points.where((point) => point == side).length;

  void addPoint(int side, int target) {
    if (finished || ![0, 1].contains(side) || points.length >= target) {
      throw StateError('Incontro non disponibile per altri punti.');
    }
    points.add(side);
  }

  void undoLastPoint() {
    if (finished || points.isEmpty) {
      throw StateError('Nessun punto da annullare.');
    }
    points.removeLast();
  }

  void finish(int target) {
    if (points.length != target) {
      throw StateError('Assegna tutti i punti prima di terminare.');
    }
    finished = true;
    finishedAt = DateTime.now().toUtc().toIso8601String();
  }

  void pause(DateTime now) {
    if (!finished && pausedAt == null) pausedAt = now.toUtc().toIso8601String();
  }

  void resume(DateTime now) {
    if (pausedAt == null) return;
    pausedSeconds +=
        now.toUtc().difference(DateTime.parse(pausedAt!)).inSeconds;
    pausedAt = null;
  }

  void reopen(DateTime now) {
    if (!finished) return;
    if (finishedAt != null) {
      pausedSeconds +=
          now.toUtc().difference(DateTime.parse(finishedAt!)).inSeconds;
    }
    finishedAt = null;
    finished = false;
  }

  Duration elapsed(DateTime now) {
    if (startedAt == null) return Duration.zero;
    final end =
        DateTime.parse(finishedAt ?? pausedAt ?? now.toUtc().toIso8601String());
    final seconds =
        end.difference(DateTime.parse(startedAt!)).inSeconds - pausedSeconds;
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }

  Map<String, dynamic> toJson() => {
        'points': points,
        'finished': finished,
        if (startedAt != null) 'startedAt': startedAt,
        if (pausedAt != null) 'pausedAt': pausedAt,
        if (finishedAt != null) 'finishedAt': finishedAt,
        'pausedSeconds': pausedSeconds,
      };

  factory AmericanoCourtResult.fromJson(Map<String, dynamic> json) =>
      AmericanoCourtResult(
        points: List<int>.from(json['points'] ?? const []),
        finished: json['finished'] ?? false,
        startedAt: json['startedAt'],
        pausedAt: json['pausedAt'],
        finishedAt: json['finishedAt'],
        pausedSeconds: json['pausedSeconds'] ?? 0,
      );

  AmericanoCourtResult copy() => AmericanoCourtResult(
        points: [...points],
        finished: finished,
        startedAt: startedAt,
        pausedAt: pausedAt,
        finishedAt: finishedAt,
        pausedSeconds: pausedSeconds,
      );
}
