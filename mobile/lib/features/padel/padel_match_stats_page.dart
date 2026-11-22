import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/core/domain/padel_scoring.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

class PadelMatchStatsPage extends StatelessWidget {
  const PadelMatchStatsPage(
      {super.key, required this.league, required this.match});

  final League league;
  final Match match;

  String pairName(int team) => match.teams[team]
      .map((id) => league.playerName(id).trim().split(RegExp(r'\s+')).first)
      .join(' / ');

  int setWins(int team) => PadelScoring.wonSets(match, team);

  int gameWins(int team) {
    var games = 0;
    for (var index = 0; index < match.padelSetScores.length; index++) {
      final superTieBreak = index == match.padelBestOf - 1 &&
          match.padelDecidingSet == 'super_tiebreak_10';
      if (!superTieBreak) games += match.padelSetScores[index][team];
    }
    return games;
  }

  int? get winner {
    final first = setWins(0), second = setWins(1);
    if (first == second) return null;
    return first > second ? 0 : 1;
  }

  String get durationLabel {
    if (match.startedAt == null || match.finishedAt == null) return '—';
    final duration = DateTime.parse(match.finishedAt!)
        .difference(DateTime.parse(match.startedAt!));
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '$hours h $minutes min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Statistiche partita')),
        body: ListView(
          key: const ValueKey('padel-match-stats'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            _FinishedScoreboard(
                match: match,
                names: [pairName(0), pairName(1)],
                winner: winner,
                duration: durationLabel),
            const SizedBox(height: 10),
            const _SectionTitle('Confronto coppie'),
            const SizedBox(height: 10),
            Row(children: [
              for (var team = 0; team < 2; team++) ...[
                if (team > 0) const SizedBox(width: 12),
                Expanded(
                  child: _CoupleStatsCard(
                    name: pairName(team),
                    color: Color(match.teamColors[team]),
                    sets: setWins(team),
                    games: gameWins(team),
                    points: match.padelPointTotals[team],
                    result: winner == null
                        ? 'PARI'
                        : winner == team
                            ? 'VINCITORI'
                            : 'SECONDI',
                  ),
                ),
              ]
            ]),
            const SizedBox(height: 10),
            const _SectionTitle('Dettaglio set'),
            const SizedBox(height: 10),
            for (var set = 0; set < match.padelSetScores.length; set++) ...[
              _SetSummary(
                index: set,
                score: match.padelSetScores[set],
                winner: PadelScoring.setWinner(match, set),
                durationSeconds: set < match.padelSetDurationsSeconds.length
                    ? match.padelSetDurationsSeconds[set]
                    : null,
                color: Color(match.teamColors[
                    match.padelSetScores[set][0] > match.padelSetScores[set][1]
                        ? 0
                        : 1]),
              ),
              if (set < match.padelSetScores.length - 1)
                const SizedBox(height: 10),
            ]
          ],
        ),
      );
}

class _FinishedScoreboard extends StatelessWidget {
  const _FinishedScoreboard(
      {required this.match,
      required this.names,
      required this.winner,
      required this.duration});
  final Match match;
  final List<String> names;
  final int? winner;
  final String duration;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: HaykoColors.padelAccent.withValues(alpha: .28))),
        child: LayoutBuilder(builder: (context, constraints) {
          final sets = match.padelSetScores.length.clamp(1, match.padelBestOf);
          final setWidth = sets > 3 ? 28.0 : 32.0;
          final nameWidth = constraints.maxWidth - (setWidth * sets);
          return Column(children: [
            SizedBox(
              height: 24,
              child: Row(children: [
                SizedBox(width: nameWidth, child: const _SmallLabel('COPPIE')),
                for (var set = 1; set <= sets; set++)
                  SizedBox(
                      width: setWidth,
                      child: _SmallLabel('$set', centered: true)),
              ]),
            ),
            _ResultRow(
                name: names[0],
                color: match.teamColors[0],
                dimmedSets: {
                  for (var i = 0; i < match.padelSetScores.length; i++)
                    if (PadelScoring.setWinner(match, i) == 1) i
                },
                width: nameWidth,
                setWidth: setWidth,
                scores: [
                  for (var set = 0; set < sets; set++)
                    set < match.padelSetScores.length
                        ? '${match.padelSetScores[set][0]}'
                        : '—'
                ]),
            Container(height: 1, color: HaykoColors.fieldBackground),
            _ResultRow(
                name: names[1],
                color: match.teamColors[1],
                dimmedSets: {
                  for (var i = 0; i < match.padelSetScores.length; i++)
                    if (PadelScoring.setWinner(match, i) == 0) i
                },
                width: nameWidth,
                setWidth: setWidth,
                scores: [
                  for (var set = 0; set < sets; set++)
                    set < match.padelSetScores.length
                        ? '${match.padelSetScores[set][1]}'
                        : '—'
                ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${winner == null ? 'Partita conclusa' : 'Vittoria ${names[winner!]} · ${PadelScoring.wonSets(match, 0)}–${PadelScoring.wonSets(match, 1)}'}\nDurata partita · $duration',
                style: const TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 12,
                    height: 18 / 12),
              ),
            )
          ]);
        }),
      );
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel(this.text, {this.centered = false});
  final String text;
  final bool centered;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
          color: HaykoColors.mutedText,
          fontSize: 10,
          height: 16 / 10,
          fontWeight: FontWeight.w600));
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(
      {required this.name,
      required this.color,
      required this.dimmedSets,
      required this.width,
      required this.setWidth,
      required this.scores});
  final String name;
  final int color;
  final Set<int> dimmedSets;
  final double width;
  final double setWidth;
  final List<String> scores;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: Row(children: [
          SizedBox(
            width: width,
            child: Row(children: [
              Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Color(color),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
            ]),
          ),
          for (var index = 0; index < scores.length; index++)
            SizedBox(
                width: setWidth,
                child: Text(scores[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: dimmedSets.contains(index)
                            ? HaykoColors.mutedText
                            : HaykoColors.chalk,
                        fontSize: 16,
                        fontWeight: FontWeight.w600))),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 20, height: 25 / 20, fontWeight: FontWeight.w700));
}

class _CoupleStatsCard extends StatelessWidget {
  const _CoupleStatsCard(
      {required this.name,
      required this.color,
      required this.sets,
      required this.games,
      required this.points,
      required this.result});
  final String name;
  final Color color;
  final int sets;
  final int games;
  final int points;
  final String result;
  @override
  Widget build(BuildContext context) => Container(
        height: 136,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .75))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 7),
            Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 5),
          _line('Set vinti · $sets'),
          _line('Game vinti · $games'),
          _line('Punti totali · $points'),
          Text(result,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                color: HaykoColors.mutedText, fontSize: 12, height: 18 / 12)),
      );
}

class _SetSummary extends StatelessWidget {
  const _SetSummary(
      {required this.index,
      required this.score,
      required this.winner,
      required this.durationSeconds,
      required this.color});
  final int index;
  final List<int> score;
  final int? winner;
  final int? durationSeconds;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: .28))),
        child: Row(children: [
          Expanded(
              child: Text('${index + 1}° set',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          SizedBox(
              width: 72,
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var team = 0; team < 2; team++) ...[
                      if (team == 1)
                        const Text(' – ', style: TextStyle(fontSize: 16)),
                      Text('${score[team]}',
                          key: ValueKey('padel-set-$index-team-$team-score'),
                          style: TextStyle(
                              color: winner != null && winner != team
                                  ? HaykoColors.mutedText
                                  : HaykoColors.chalk,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ]))),
          Expanded(
              child: Text(
                  durationSeconds == null
                      ? '—'
                      : '${(durationSeconds! / 60).ceil()} min',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: HaykoColors.mutedText, fontSize: 12))),
        ]),
      );
}
