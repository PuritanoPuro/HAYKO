/// Each point records the side (0 or 1) that won it. Keeping the sequence
/// makes the last point reversible without guessing which pair scored.
class AmericanoCourtResult {
  AmericanoCourtResult({
    List<int>? points,
    this.finished = false,
    this.startedAt,
  }) : points = points ?? <int>[];

  final List<int> points;
  bool finished;
  String? startedAt;

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
  }

  Map<String, dynamic> toJson() => {
        'points': points,
        'finished': finished,
        if (startedAt != null) 'startedAt': startedAt,
      };

  factory AmericanoCourtResult.fromJson(Map<String, dynamic> json) =>
      AmericanoCourtResult(
        points: List<int>.from(json['points'] ?? const []),
        finished: json['finished'] ?? false,
        startedAt: json['startedAt'],
      );

  AmericanoCourtResult copy() => AmericanoCourtResult(
        points: [...points],
        finished: finished,
        startedAt: startedAt,
      );
}
