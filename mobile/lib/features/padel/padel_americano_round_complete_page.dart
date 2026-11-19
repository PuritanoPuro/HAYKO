import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/americano_flow.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_live_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_scheduled_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_score_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_standings_page.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoRoundCompletePage extends StatefulWidget {
  const PadelAmericanoRoundCompletePage({
    super.key,
    required this.league,
    required this.competition,
    required this.save,
  });

  final League league;
  final Competition competition;
  final Save save;

  @override
  State<PadelAmericanoRoundCompletePage> createState() =>
      _PadelAmericanoRoundCompletePageState();
}

class _PadelAmericanoRoundCompletePageState
    extends State<PadelAmericanoRoundCompletePage> {
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

  Future<void> openScore(int court) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PadelAmericanoScorePage(
          league: widget.league,
          competition: widget.competition,
          courtIndex: court,
          save: widget.save,
        ),
      ),
    );
    if (!mounted) return;
    if (widget.competition.americanoTurnStatus == 'live') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PadelAmericanoLivePage(
            league: widget.league,
            competition: widget.competition,
            save: widget.save,
          ),
        ),
      );
    } else {
      setState(() {});
    }
  }

  Future<void> chooseCorrection() async {
    final count = widget.competition
        .americanoSchedule[widget.competition.americanoCurrentRound].length;
    final court = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: HaykoColors.fieldSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Correggi risultati',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          for (var index = 0; index < count; index++)
            ListTile(
              title: Text('Campo ${index + 1}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, index),
            ),
        ]),
      ),
    );
    if (court != null && mounted) await openScore(court);
  }

  Future<void> prepareNext() async {
    if (saving) return;
    final competition = widget.competition;
    final oldRound = competition.americanoCurrentRound;
    final oldStatus = competition.americanoTurnStatus;
    final last = oldRound + 1 == competition.americanoRounds;
    competition.americanoCurrentRound = last ? oldRound : oldRound + 1;
    competition.americanoTurnStatus = last ? 'finished' : 'scheduled';
    setState(() => saving = true);
    try {
      await widget.save();
      if (!mounted) return;
      if (last) {
        Navigator.pop(context);
      } else {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PadelAmericanoScheduledPage(
              league: widget.league,
              competition: competition,
              save: widget.save,
            ),
          ),
        );
      }
    } catch (error) {
      competition.americanoCurrentRound = oldRound;
      competition.americanoTurnStatus = oldStatus;
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
    final assigned =
        results.fold<int>(0, (sum, result) => sum + result.points.length);
    final last = round + 1 == competition.americanoRounds;
    final tournamentFinished = competition.americanoTurnStatus == 'finished';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: Text(tournamentFinished
            ? 'Americano terminato'
            : 'Turno ${round + 1} completato'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('americano-round-complete'),
          padding: const EdgeInsets.all(24),
          children: [
            AmericanoStatusField(
              label: tournamentFinished ? 'Competizione' : 'Turno concluso',
              value: tournamentFinished
                  ? '${competition.americanoRounds} turni · Terminata'
                  : 'Turno ${round + 1} di ${competition.americanoRounds} · Completato',
            ),
            const SizedBox(height: 10),
            Row(children: [
              AmericanoMetric(
                  value: '${round + 1} / ${competition.americanoRounds}',
                  label: 'Turno'),
              const SizedBox(width: 9),
              AmericanoMetric(
                  value: '${results.length} / ${fixtures.length}',
                  label: 'Concluse'),
              const SizedBox(width: 9),
              AmericanoMetric(value: '$assigned', label: 'Punti assegnati'),
            ]),
            const SizedBox(height: 10),
            const Text('Risultati del turno',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (var court = 0; court < fixtures.length; court++) ...[
              AmericanoLiveCourtCard(
                court: court + 1,
                fixture: fixtures[court],
                result: results[court],
                playerName: playerName,
                completed: true,
                onTap: () => openScore(court),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              'I punti di ogni giocatore sono stati aggiunti alla classifica individuale.',
              style: TextStyle(
                  color: HaykoColors.mutedText, fontSize: 13, height: 20 / 13),
            ),
            const SizedBox(height: 10),
            AccountButton('Correggi risultati',
                key: const ValueKey('americano-correct-results'),
                outline: true,
                onPressed:
                    saving || !widget.league.manage ? null : chooseCorrection),
            const SizedBox(height: 10),
            AccountButton('Vedi classifica',
                key: const ValueKey('americano-view-standings'),
                outline: true, onPressed: () async {
              await Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PadelAmericanoStandingsPage(
                      league: widget.league,
                      competition: competition,
                      save: widget.save,
                    ),
                  ));
            }),
            const SizedBox(height: 10),
            if (!tournamentFinished)
              AccountButton(
                  last ? 'Termina Americano' : 'Prepara turno ${round + 2}',
                  key: const ValueKey('americano-next-round'),
                  onPressed:
                      saving || !widget.league.manage ? null : prepareNext),
          ],
        ),
      ),
    );
  }
}
