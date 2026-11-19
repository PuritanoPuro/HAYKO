import 'dart:async';

import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/americano_flow.dart';
import 'package:calcetto_mvp/core/domain/americano_result.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoScorePage extends StatefulWidget {
  const PadelAmericanoScorePage({
    super.key,
    required this.league,
    required this.competition,
    required this.courtIndex,
    required this.save,
  });

  final League league;
  final Competition competition;
  final int courtIndex;
  final Save save;

  @override
  State<PadelAmericanoScorePage> createState() =>
      _PadelAmericanoScorePageState();
}

class _PadelAmericanoScorePageState extends State<PadelAmericanoScorePage> {
  Timer? clock;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  AmericanoCourtResult get result =>
      currentAmericanoResults(widget.competition)[widget.courtIndex];

  String playerName(String id) {
    final player = widget.league.players.firstWhere((p) => p.id == id);
    return player.name.trim().split(RegExp(r'\s+')).first;
  }

  String get duration {
    final seconds =
        result.elapsed(DateTime.now().toUtc()).inSeconds.clamp(0, 99999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> change(void Function(AmericanoCourtResult) action,
      {bool leaveAfter = false}) async {
    if (saving) return;
    final previous = result.copy();
    final previousStatus = widget.competition.americanoTurnStatus;
    try {
      action(result);
    } catch (error) {
      if (mounted) showError(context, error);
      return;
    }
    setState(() => saving = true);
    try {
      await widget.save();
      if (mounted && leaveAfter) Navigator.pop(context, true);
    } catch (error) {
      final current = result;
      current.points
        ..clear()
        ..addAll(previous.points);
      current.finished = previous.finished;
      current.startedAt = previous.startedAt;
      current.pausedAt = previous.pausedAt;
      current.finishedAt = previous.finishedAt;
      current.pausedSeconds = previous.pausedSeconds;
      widget.competition.americanoTurnStatus = previousStatus;
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    final fixture =
        competition.americanoSchedule[competition.americanoCurrentRound]
            [widget.courtIndex];
    final first = '${playerName(fixture[0])} / ${playerName(fixture[1])}';
    final second = '${playerName(fixture[2])} / ${playerName(fixture[3])}';
    final current = result;
    final target = competition.americanoTargetPoints;
    final canScore = !saving &&
        !current.finished &&
        current.points.length < target &&
        competition.americanoTurnStatus == 'live' &&
        widget.league.manage;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: Text('Campo ${widget.courtIndex + 1} · Turno '
            '${competition.americanoCurrentRound + 1}'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('americano-score'),
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              height: 218,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: HaykoColors.fieldSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: HaykoColors.padelAccent.withValues(alpha: .28)),
              ),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text('CAMPO ${widget.courtIndex + 1}',
                          style: _smallLabel)),
                  Text(current.finished ? 'COMPLETATA' : 'LIVE',
                      style: const TextStyle(
                          color: HaykoColors.padelAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _TeamLabel(first, side: 0)),
                  const Text('VS',
                      style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  Expanded(child: _TeamLabel(second, side: 1)),
                ]),
                const SizedBox(height: 8),
                Text('${current.scoreFor(0)} – ${current.scoreFor(1)}',
                    key: const ValueKey('americano-score-value'),
                    style: const TextStyle(
                        fontSize: 46,
                        height: 51 / 46,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Obiettivo · $target punti\nTempo incontro · $duration',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 12,
                        height: 18 / 12)),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _PointButton(
                key: const ValueKey('americano-point-first'),
                label: first,
                color: HaykoColors.padelAccent,
                onTap: canScore
                    ? () => change((result) => result.addPoint(0, target))
                    : null,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _PointButton(
                key: const ValueKey('americano-point-second'),
                label: second,
                color: const Color(0xffff8c47),
                onTap: canScore
                    ? () => change((result) => result.addPoint(1, target))
                    : null,
              )),
            ]),
            const SizedBox(height: 10),
            if (saving) const LinearProgressIndicator(minHeight: 2),
            AccountButton('Annulla ultimo punto',
                key: const ValueKey('americano-undo-point'),
                outline: true,
                onPressed: !saving &&
                        !current.finished &&
                        current.points.isNotEmpty &&
                        widget.league.manage
                    ? () => change((result) => result.undoLastPoint())
                    : null),
            const SizedBox(height: 10),
            if (current.finished)
              AccountButton('Riapri incontro',
                  key: const ValueKey('americano-reopen-court'),
                  onPressed: saving || !widget.league.manage
                      ? null
                      : () => change((result) {
                            result.reopen(DateTime.now().toUtc());
                            competition.americanoTurnStatus = 'live';
                          }))
            else
              AccountButton('Termina incontro',
                  key: const ValueKey('americano-finish-court'),
                  onPressed: saving ||
                          current.points.length != target ||
                          !widget.league.manage
                      ? null
                      : () => change((result) => result.finish(target),
                          leaveAfter: true)),
          ],
        ),
      ),
    );
  }
}

const _smallLabel = TextStyle(
    color: HaykoColors.mutedText, fontSize: 11, fontWeight: FontWeight.w600);

class _TeamLabel extends StatelessWidget {
  const _TeamLabel(this.name, {required this.side});
  final String name;
  final int side;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (side == 0) ...[
          Container(width: 4, height: 28, color: HaykoColors.padelAccent),
          const SizedBox(width: 8),
        ],
        Expanded(
            child: Text(name,
                textAlign: side == 0 ? TextAlign.left : TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
        if (side == 1) ...[
          const SizedBox(width: 8),
          Container(width: 4, height: 28, color: const Color(0xffff8c47)),
        ],
      ]);
}

class _PointButton extends StatelessWidget {
  const _PointButton(
      {super.key, required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('+ PUNTO',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}
