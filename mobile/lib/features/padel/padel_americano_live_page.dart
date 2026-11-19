import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/americano_flow.dart';
import 'package:calcetto_mvp/core/domain/americano_result.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_score_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_round_complete_page.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoLivePage extends StatefulWidget {
  const PadelAmericanoLivePage({
    super.key,
    required this.league,
    required this.competition,
    required this.save,
  });

  final League league;
  final Competition competition;
  final Save save;

  @override
  State<PadelAmericanoLivePage> createState() => _PadelAmericanoLivePageState();
}

class _PadelAmericanoLivePageState extends State<PadelAmericanoLivePage> {
  bool saving = false;

  String playerName(String id) {
    final player = widget.league.players.firstWhere((p) => p.id == id);
    final first = player.name.trim().split(RegExp(r'\s+')).first;
    final repeated = widget.competition.americanoPlayerIds.where((candidate) {
          final name = widget.league.players
              .firstWhere((p) => p.id == candidate)
              .name
              .trim()
              .split(RegExp(r'\s+'))
              .first;
          return name.toLowerCase() == first.toLowerCase();
        }).length >
        1;
    return repeated ? player.name : first;
  }

  Future<void> changeStatus(String next) async {
    if (saving) return;
    final previous = widget.competition.americanoTurnStatus;
    final oldResults = [
      for (final round in widget.competition.americanoResults)
        [for (final result in round) result.copy()],
    ];
    final now = DateTime.now().toUtc();
    if (next == 'paused') {
      for (final result in currentAmericanoResults(widget.competition)) {
        result.pause(now);
      }
    } else if (previous == 'paused' && next == 'live') {
      for (final result in currentAmericanoResults(widget.competition)) {
        result.resume(now);
      }
    }
    widget.competition.americanoTurnStatus = next;
    setState(() => saving = true);
    try {
      await widget.save();
      if (mounted && next == 'completed') {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PadelAmericanoRoundCompletePage(
              league: widget.league,
              competition: widget.competition,
              save: widget.save,
            ),
          ),
        );
      }
    } catch (error) {
      widget.competition.americanoTurnStatus = previous;
      widget.competition.americanoResults
        ..clear()
        ..addAll(oldResults);
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    final round = competition.americanoCurrentRound;
    final fixtures = competition.americanoSchedule[round];
    final results = currentAmericanoResults(competition);
    final completed = results.where((result) => result.finished).length;
    final paused = competition.americanoTurnStatus == 'paused';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: Text(competition.name),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('americano-live'),
          padding: const EdgeInsets.all(24),
          children: [
            AmericanoStatusField(
              label: 'Turno corrente',
              value: 'Turno ${round + 1} di ${competition.americanoRounds} · '
                  '${paused ? 'Sospeso' : 'In corso'}',
            ),
            const SizedBox(height: 10),
            Row(children: [
              AmericanoMetric(
                  value: '${round + 1} / ${competition.americanoRounds}',
                  label: 'Turno'),
              const SizedBox(width: 9),
              AmericanoMetric(
                  value: '$completed / ${fixtures.length}', label: 'Concluse'),
              const SizedBox(width: 9),
              AmericanoMetric(
                  value: '${competition.americanoTargetPoints}',
                  label: 'Punti'),
            ]),
            const SizedBox(height: 10),
            const Text('Partite in corso',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (var court = 0; court < fixtures.length; court++) ...[
              AmericanoLiveCourtCard(
                key: ValueKey('americano-live-court-${court + 1}'),
                court: court + 1,
                fixture: fixtures[court],
                result: results[court],
                playerName: playerName,
                onTap: paused
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PadelAmericanoScorePage(
                              league: widget.league,
                              competition: competition,
                              courtIndex: court,
                              save: widget.save,
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Termina il turno quando ${fixtures.length == 1 ? 'l’incontro ha' : 'tutti gli incontri hanno'} '
              'raggiunto ${competition.americanoTargetPoints} punti.',
              style: const TextStyle(
                  color: HaykoColors.mutedText, fontSize: 13, height: 20 / 13),
            ),
            const SizedBox(height: 10),
            AccountButton(paused ? 'Riprendi turno' : 'Sospendi turno',
                key: const ValueKey('americano-pause-round'),
                outline: true,
                onPressed: saving || !widget.league.manage
                    ? null
                    : () => changeStatus(paused ? 'live' : 'paused')),
            const SizedBox(height: 10),
            AccountButton('Termina turno',
                key: const ValueKey('americano-finish-round'),
                onPressed: saving ||
                        paused ||
                        !widget.league.manage ||
                        !americanoRoundComplete(competition)
                    ? null
                    : () => changeStatus('completed')),
          ],
        ),
      ),
    );
  }
}

class AmericanoStatusField extends StatelessWidget {
  const AmericanoStatusField(
      {super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: HaykoColors.padelAccent.withValues(alpha: .42)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, height: 24 / 16)),
        ]),
      );
}

class AmericanoMetric extends StatelessWidget {
  const AmericanoMetric({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: HaykoColors.padelAccent.withValues(alpha: .28)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    height: 25 / 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 11,
                    height: 18 / 11)),
          ]),
        ),
      );
}

class AmericanoLiveCourtCard extends StatelessWidget {
  const AmericanoLiveCourtCard({
    super.key,
    required this.court,
    required this.fixture,
    required this.result,
    required this.playerName,
    required this.onTap,
    this.completed = false,
  });

  final int court;
  final List<String> fixture;
  final AmericanoCourtResult result;
  final String Function(String) playerName;
  final VoidCallback? onTap;
  final bool completed;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 174,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: HaykoColors.padelAccent.withValues(alpha: .35)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('CAMPO $court', style: _labelStyle)),
              Text(completed || result.finished ? 'COMPLETATA' : 'LIVE',
                  style: const TextStyle(
                      color: HaykoColors.padelAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            _PairLine(
              color: HaykoColors.padelAccent,
              names: '${playerName(fixture[0])} / ${playerName(fixture[1])}',
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: Center(
                child: Text('${result.scoreFor(0)} – ${result.scoreFor(1)}',
                    style: const TextStyle(
                        fontSize: 20,
                        height: 24 / 20,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 4),
            _PairLine(
              color: const Color(0xffff8c47),
              names: '${playerName(fixture[2])} / ${playerName(fixture[3])}',
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(completed ? 'Vedi dettaglio  ›' : 'Apri punteggio  ›',
                  style: const TextStyle(
                      color: HaykoColors.padelAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}

const _labelStyle = TextStyle(
    color: HaykoColors.mutedText, fontSize: 11, fontWeight: FontWeight.w600);

class _PairLine extends StatelessWidget {
  const _PairLine({required this.color, required this.names});
  final Color color;
  final String names;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: Row(children: [
          Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600))),
        ]),
      );
}
