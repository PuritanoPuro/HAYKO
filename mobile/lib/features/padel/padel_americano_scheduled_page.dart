import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/core/domain/americano_flow.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_calendar_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_live_page.dart';
import 'package:calcetto_mvp/shared/ui.dart';

/// The confirmed Americano calendar, before the current round begins.
class PadelAmericanoScheduledPage extends StatefulWidget {
  const PadelAmericanoScheduledPage({
    super.key,
    required this.league,
    required this.competition,
    required this.save,
  });

  final League league;
  final Competition competition;
  final Save save;

  @override
  State<PadelAmericanoScheduledPage> createState() =>
      _PadelAmericanoScheduledPageState();
}

class _PadelAmericanoScheduledPageState
    extends State<PadelAmericanoScheduledPage> {
  bool saving = false;

  String playerName(String id) {
    final player = widget.league.players.firstWhere((p) => p.id == id);
    final first = player.name.trim().split(RegExp(r'\s+')).first;
    final duplicate = widget.competition.americanoPlayerIds.where((candidate) {
          final name = widget.league.players
              .firstWhere((p) => p.id == candidate)
              .name
              .trim()
              .split(RegExp(r'\s+'))
              .first;
          return name.toLowerCase() == first.toLowerCase();
        }).length >
        1;
    return duplicate ? player.name : first;
  }

  Future<void> editCalendar() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PadelAmericanoCalendarPage(
          league: widget.league,
          competition: widget.competition,
          save: widget.save,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> changeStatus(String nextStatus) async {
    if (saving) return;
    final previous = widget.competition.americanoTurnStatus;
    final previousResults = [
      for (final round in widget.competition.americanoResults)
        [for (final result in round) result.copy()],
    ];
    ensureAmericanoResults(widget.competition);
    if (nextStatus == 'live') {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final result in currentAmericanoResults(widget.competition)) {
        result.startedAt ??= now;
      }
    }
    widget.competition.americanoTurnStatus = nextStatus;
    setState(() => saving = true);
    try {
      await widget.save();
      if (mounted && nextStatus == 'live') {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PadelAmericanoLivePage(
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
        ..addAll(previousResults);
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    final round = competition.americanoCurrentRound;
    final schedule = competition.americanoSchedule;
    final fixtures =
        round < schedule.length ? schedule[round] : const <List<String>>[];
    final status = competition.americanoTurnStatus == 'live'
        ? 'In corso'
        : competition.americanoTurnStatus == 'finished'
            ? 'Terminato'
            : 'Programmato';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: Text(competition.name),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('americano-scheduled'),
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              height: 76,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HaykoColors.fieldSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HaykoColors.padelAccent.withValues(alpha: .42),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Turno corrente',
                      style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                      'Turno ${round + 1} di ${competition.americanoRounds} · $status',
                      key: const ValueKey('americano-current-round'),
                      style: const TextStyle(fontSize: 16, height: 24 / 16)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _Metric(
                  value: competition.americanoPlayerCount, label: 'Giocatori'),
              const SizedBox(width: 9),
              _Metric(value: competition.americanoCourts, label: 'Campi'),
              const SizedBox(width: 9),
              _Metric(value: competition.americanoRounds, label: 'Turni'),
            ]),
            const SizedBox(height: 10),
            const Text('Partite del turno',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (var index = 0; index < fixtures.length; index++) ...[
              AmericanoCourtCard(
                key: ValueKey('americano-scheduled-court-${index + 1}'),
                court: index + 1,
                targetPoints: competition.americanoTargetPoints,
                fixture: fixtures[index],
                playerName: playerName,
              ),
              const SizedBox(height: 10),
            ],
            Text(
              '${fixtures.length == 1 ? 'La partita inizia' : 'Le partite iniziano insieme'}. '
              'Al termine il sistema prepara automaticamente il turno successivo.',
              style: const TextStyle(
                color: HaykoColors.mutedText,
                fontSize: 13,
                height: 20 / 13,
              ),
            ),
            const SizedBox(height: 10),
            if (competition.americanoTurnStatus == 'scheduled') ...[
              AccountButton('Modifica calendario',
                  key: const ValueKey('americano-edit-calendar'),
                  outline: true,
                  onPressed: saving ||
                          !widget.league.manage ||
                          competition.americanoCurrentRound > 0 ||
                          competition.americanoResults.any((round) => round.any(
                              (result) =>
                                  result.points.isNotEmpty || result.finished))
                      ? null
                      : editCalendar),
              const SizedBox(height: 10),
              AccountButton('Inizia turno',
                  key: const ValueKey('americano-start-round'),
                  onPressed: saving || !widget.league.manage || fixtures.isEmpty
                      ? null
                      : () => changeStatus('live')),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(
              color: HaykoColors.padelAccent.withValues(alpha: .28),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value',
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
            ],
          ),
        ),
      );
}
