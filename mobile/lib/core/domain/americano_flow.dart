import 'package:calcetto_mvp/core/domain/americano_result.dart';
import 'package:calcetto_mvp/core/domain/competition_domain.dart';

void ensureAmericanoResults(Competition competition) {
  if (competition.americanoResults.isEmpty) {
    competition.americanoResults.addAll([
      for (final round in competition.americanoSchedule)
        [for (final _ in round) AmericanoCourtResult()],
    ]);
  }
  if (competition.americanoResults.length !=
      competition.americanoSchedule.length) {
    throw StateError('I risultati non corrispondono al calendario.');
  }
  for (var round = 0; round < competition.americanoSchedule.length; round++) {
    if (competition.americanoResults[round].length !=
        competition.americanoSchedule[round].length) {
      throw StateError('I risultati non corrispondono ai campi del turno.');
    }
  }
}

List<AmericanoCourtResult> currentAmericanoResults(Competition competition) {
  ensureAmericanoResults(competition);
  return competition.americanoResults[competition.americanoCurrentRound];
}

bool americanoRoundComplete(Competition competition) =>
    currentAmericanoResults(competition).every((result) => result.finished);
