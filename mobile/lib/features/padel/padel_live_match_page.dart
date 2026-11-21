import 'dart:async';

import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/core/domain/padel_scoring.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelLiveMatchPage extends StatefulWidget {
  const PadelLiveMatchPage({
    super.key,
    required this.league,
    required this.match,
    required this.save,
    this.reload,
  });

  final League league;
  final Match match;
  final Save save;
  final Save? reload;

  @override
  State<PadelLiveMatchPage> createState() => _PadelLiveMatchPageState();
}

class _PadelLiveMatchPageState extends State<PadelLiveMatchPage> {
  final List<Map<String, dynamic>> pointHistory = [];
  Timer? ticker;
  bool saving = false;

  Match get match => widget.match;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && match.status == 'live') setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  String pairName(int team) => match.teams[team]
      .map((id) =>
          widget.league.playerName(id).trim().split(RegExp(r'\s+')).first)
      .join(' / ');

  String setValue(int team, int set) => set < match.padelSetScores.length
      ? '${match.padelSetScores[set][team]}'
      : '—';

  int get currentSet => match.padelSetScores.isEmpty
      ? 1
      : match.padelSetScores.length.clamp(1, match.padelBestOf);

  Future<void> mutate(void Function() change, {bool remember = false}) async {
    if (saving || match.status != 'live') return;
    final backup = Match.fromJson(match.toJson()).toJson();
    if (remember) pointHistory.add(backup);
    setState(() => saving = true);
    try {
      change();
      await widget.save();
    } catch (error) {
      if (remember && pointHistory.isNotEmpty) pointHistory.removeLast();
      _restore(Match.fromJson(backup));
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => saving = false);
  }

  void _restore(Match old) {
    match.status = old.status;
    match.startedAt = old.startedAt;
    match.finishedAt = old.finishedAt;
    match.padelSetScores
      ..clear()
      ..addAll(old.padelSetScores.map((set) => [...set]));
    match.padelPoints
      ..clear()
      ..addAll(old.padelPoints);
    match.padelPointTotals
      ..clear()
      ..addAll(old.padelPointTotals);
    match.padelSetDurationsSeconds
      ..clear()
      ..addAll(old.padelSetDurationsSeconds);
    match.padelSetStartedAt = old.padelSetStartedAt;
  }

  Future<void> addPoint(int team) async {
    await mutate(() => PadelScoring.awardPoint(match, team), remember: true);
    if (mounted && match.status == 'finished') Navigator.pop(context);
  }

  Future<void> undoPoint() async {
    if (saving || pointHistory.isEmpty) return;
    final previous = pointHistory.removeLast();
    final current = Match.fromJson(match.toJson()).toJson();
    setState(() => saving = true);
    try {
      _restore(Match.fromJson(previous));
      await widget.save();
    } catch (error) {
      _restore(Match.fromJson(current));
      pointHistory.add(previous);
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> finish() async {
    if (saving ||
        !await confirm(context, 'Terminare la partita?',
            'Il risultato verrà salvato nelle statistiche della lega.')) {
      return;
    }
    await mutate(match.finish);
    if (mounted && match.status == 'finished') Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Partita in corso')),
        body: ListView(
          key: const ValueKey('padel-live-match'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            _LiveScoreboard(
              match: match,
              pairNames: [pairName(0), pairName(1)],
              elapsed: clockText(matchElapsed(match, DateTime.now().toUtc())),
              currentSet: currentSet,
            ),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final serverId = PadelScoring.servingPlayerId(match);
              final team = match.teams[0].contains(serverId) ? 0 : 1;
              return Container(
                key: const ValueKey('padel-current-server'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: HaykoColors.fieldSurface,
                  border: Border.all(color: HaykoColors.fieldLine),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Container(
                      width: 4,
                      height: 28,
                      color: Color(match.teamColors[team])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AL SERVIZIO',
                          style: TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      Text(widget.league.playerName(serverId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  )),
                ]),
              );
            }),
            const SizedBox(height: 10),
            Row(children: [
              for (var team = 0; team < 2; team++) ...[
                if (team > 0) const SizedBox(width: 12),
                Expanded(
                  child: _PointButton(
                    key: ValueKey('padel-point-$team'),
                    label: pairName(team),
                    color: Color(match.teamColors[team]),
                    onPressed: saving ? null : () => addPoint(team),
                  ),
                ),
              ]
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                key: const ValueKey('padel-undo-point'),
                onPressed: saving || pointHistory.isEmpty ? null : undoPoint,
                child: const Text('Annulla ultimo punto'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                key: const ValueKey('padel-finish-match'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffffb4ab),
                    side: const BorderSide(color: Color(0xffffb4ab))),
                onPressed: saving ? null : finish,
                child: const Text('Termina partita'),
              ),
            ),
          ],
        ),
      );
}

class _LiveScoreboard extends StatelessWidget {
  const _LiveScoreboard({
    required this.match,
    required this.pairNames,
    required this.elapsed,
    required this.currentSet,
  });

  final Match match;
  final List<String> pairNames;
  final String elapsed;
  final int currentSet;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: HaykoColors.padelAccent.withValues(alpha: .28)),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final setWidth = match.padelBestOf == 5 ? 28.0 : 32.0;
          const pointsWidth = 56.0;
          final nameWidth = constraints.maxWidth -
              (setWidth * match.padelBestOf) -
              pointsWidth;
          return Column(children: [
            _Header(
                nameWidth: nameWidth,
                setWidth: setWidth,
                sets: match.padelBestOf),
            _ScoreRow(
                name: pairNames[0],
                color: match.teamColors[0],
                nameWidth: nameWidth,
                setWidth: setWidth,
                sets: [
                  for (var set = 0; set < match.padelBestOf; set++)
                    set < match.padelSetScores.length
                        ? '${match.padelSetScores[set][0]}'
                        : '—'
                ],
                points: match.padelPoints[0]),
            Container(height: 1, color: HaykoColors.fieldBackground),
            _ScoreRow(
                name: pairNames[1],
                color: match.teamColors[1],
                nameWidth: nameWidth,
                setWidth: setWidth,
                sets: [
                  for (var set = 0; set < match.padelBestOf; set++)
                    set < match.padelSetScores.length
                        ? '${match.padelSetScores[set][1]}'
                        : '—'
                ],
                points: match.padelPoints[1]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$currentSet° set · ${match.padelGameRule == 'advantages' ? 'Vantaggi' : 'Golden Point'}\nTempo partita · $elapsed',
                style: const TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 12,
                    height: 18 / 12),
              ),
            ),
          ]);
        }),
      );
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.nameWidth, required this.setWidth, required this.sets});
  final double nameWidth;
  final double setWidth;
  final int sets;

  Widget label(String value, double width) => SizedBox(
        width: width,
        child: Text(value,
            textAlign: value == 'COPPIE' ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
                color: HaykoColors.mutedText,
                fontSize: 10,
                height: 16 / 10,
                fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 24,
        child: Row(children: [
          label('COPPIE', nameWidth),
          for (var set = 1; set <= sets; set++) label('$set', setWidth),
          label('PUNTI', 56),
        ]),
      );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.name,
    required this.color,
    required this.nameWidth,
    required this.setWidth,
    required this.sets,
    required this.points,
  });
  final String name;
  final int color;
  final double nameWidth;
  final double setWidth;
  final List<String> sets;
  final String points;

  Widget score(String value, double width) => SizedBox(
        width: width,
        child: Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: value == '—' ? HaykoColors.mutedText : HaykoColors.chalk,
                fontSize: 16,
                height: 20 / 16,
                fontWeight: value == '—' ? FontWeight.w400 : FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: Row(children: [
          SizedBox(
            width: nameWidth,
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
                        fontSize: 14,
                        height: 18 / 14,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          for (final value in sets) score(value, setWidth),
          score(points, 56),
        ]),
      );
}

class _PointButton extends StatelessWidget {
  const _PointButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 100,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: HaykoColors.chalk,
            backgroundColor: color.withValues(alpha: .14),
            side: BorderSide(color: color, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('+ PUNTO',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
