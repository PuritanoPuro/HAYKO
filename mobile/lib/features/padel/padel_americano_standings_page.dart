import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:calcetto_mvp/core/domain/americano_standings.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_scheduled_page.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoStandingsPage extends StatefulWidget {
  const PadelAmericanoStandingsPage({
    super.key,
    required this.league,
    required this.competition,
    required this.save,
  });

  final League league;
  final Competition competition;
  final Save save;

  @override
  State<PadelAmericanoStandingsPage> createState() =>
      _PadelAmericanoStandingsPageState();
}

class _PadelAmericanoStandingsPageState
    extends State<PadelAmericanoStandingsPage> {
  late int selectedRound = widget.competition.americanoCurrentRound;
  bool saving = false;

  bool get finalResults => widget.competition.americanoTurnStatus == 'finished';

  int get completedRounds {
    var count = 0;
    for (final round in widget.competition.americanoResults) {
      if (round.isEmpty || !round.every((result) => result.finished)) break;
      count++;
    }
    return count;
  }

  String playerName(String id) {
    final player = widget.league.players.firstWhere((p) => p.id == id);
    final first = player.name.trim().split(RegExp(r'\s+')).first;
    final repeated = widget.competition.americanoPlayerIds.where((other) {
          final name = widget.league.players
              .firstWhere((p) => p.id == other)
              .name
              .trim()
              .split(RegExp(r'\s+'))
              .first;
          return name.toLowerCase() == first.toLowerCase();
        }).length >
        1;
    return repeated ? player.name : first;
  }

  Future<void> advance() async {
    if (saving ||
        !widget.league.manage ||
        widget.competition.americanoTurnStatus != 'completed') {
      return;
    }
    final competition = widget.competition;
    final previousRound = competition.americanoCurrentRound;
    final last = previousRound + 1 == competition.americanoRounds;
    competition.americanoTurnStatus = last ? 'finished' : 'scheduled';
    if (!last) competition.americanoCurrentRound++;
    setState(() => saving = true);
    try {
      await widget.save();
      if (!mounted) return;
      if (last) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PadelAmericanoStandingsPage(
              league: widget.league,
              competition: competition,
              save: widget.save,
            ),
          ),
        );
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
      competition.americanoTurnStatus = 'completed';
      competition.americanoCurrentRound = previousRound;
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> share(
      BuildContext buttonContext, List<AmericanoStanding> standings) async {
    final text = StringBuffer('HAYKO · ${widget.competition.name}\n'
        'Classifica finale Americano\n');
    for (final row in standings) {
      text.writeln('${row.rank}° ${playerName(row.playerId)} · '
          '${row.points} PT · ${row.wins} V · ${row.losses} S · '
          '${row.difference >= 0 ? '+' : ''}${row.difference} +/-');
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(ShareParams(
        text: text.toString().trimRight(),
        subject: 'Classifica ${widget.competition.name}',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    final lastCompleted = completedRounds;
    final round = finalResults
        ? competition.americanoRounds - 1
        : selectedRound.clamp(0, (lastCompleted - 1).clamp(0, 999));
    final standings = americanoStandings(competition, throughRound: round);
    final encounters = competition.americanoSchedule
        .fold<int>(0, (sum, fixtures) => sum + fixtures.length);
    final canAdvance = competition.americanoTurnStatus == 'completed' &&
        widget.league.manage &&
        round == competition.americanoCurrentRound;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title:
            Text(finalResults ? 'Americano terminato' : 'Classifica Americano'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: ValueKey(finalResults
              ? 'americano-final-standings'
              : 'americano-round-standings'),
          padding: const EdgeInsets.all(24),
          children: [
            if (finalResults)
              _StandingField(
                label: 'Competizione',
                value: '${competition.americanoRounds} turni · Terminata',
              )
            else
              _RoundSelector(
                round: round,
                completedRounds: lastCompleted,
                totalRounds: competition.americanoRounds,
                onChanged: (value) => setState(() => selectedRound = value),
              ),
            const SizedBox(height: 10),
            if (finalResults) ...[
              _AmericanoPodium(standings: standings, playerName: playerName),
              const SizedBox(height: 10),
            ],
            Text(finalResults ? 'Classifica finale' : 'Classifica individuale',
                style: const TextStyle(
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            AmericanoStandingTable(
              standings: standings,
              playerName: playerName,
              currentPlayerId: widget.league.myPlayer,
              players: widget.league.players,
            ),
            const SizedBox(height: 8),
            Text(
              finalResults
                  ? 'Classifica definitiva dopo ${competition.americanoRounds} turni · $encounters incontri\n'
                      'PT punti · V vittorie · S sconfitte · +/- differenza'
                  : 'PT punti accumulati · V vittorie · S sconfitte\n'
                      '+/- differenza punti',
              style: const TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (finalResults) ...[
              Builder(
                  builder: (buttonContext) => AccountButton(
                        'Condividi classifica',
                        key: const ValueKey('americano-share-standings'),
                        outline: true,
                        onPressed: () => share(buttonContext, standings),
                      )),
              const SizedBox(height: 10),
              AccountButton('Torna alle competizioni',
                  key: const ValueKey('americano-back-to-competitions'),
                  onPressed: () => Navigator.pop(context)),
            ] else if (canAdvance)
              AccountButton(
                round + 1 == competition.americanoRounds
                    ? 'Termina Americano'
                    : 'Vai al turno ${round + 2}',
                key: const ValueKey('americano-standings-next'),
                onPressed: saving ? null : advance,
              ),
          ],
        ),
      ),
    );
  }
}

class _StandingField extends StatelessWidget {
  const _StandingField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
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

class _RoundSelector extends StatelessWidget {
  const _RoundSelector(
      {required this.round,
      required this.completedRounds,
      required this.totalRounds,
      required this.onChanged});
  final int round;
  final int completedRounds;
  final int totalRounds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Classifica dopo',
              style: TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600)),
          Expanded(
              child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('americano-standing-round-select'),
              value: round,
              isExpanded: true,
              dropdownColor: HaykoColors.fieldSurface,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.arrow_drop_down, color: HaykoColors.chalk),
              items: [
                for (var index = 0; index < completedRounds; index++)
                  DropdownMenuItem(
                      value: index,
                      child: Text('Turno ${index + 1} di $totalRounds'))
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          )),
        ]),
      );
}

class _AmericanoPodium extends StatelessWidget {
  const _AmericanoPodium({required this.standings, required this.playerName});
  final List<AmericanoStanding> standings;
  final String Function(String) playerName;

  @override
  Widget build(BuildContext context) {
    final podium = standings.take(3).toList();
    final order = [1, 0, 2];
    const colors = [Color(0xff63c7f2), Color(0xffb8bfbf), Color(0xffcc7a42)];
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var slot = 0; slot < 3; slot++) ...[
            if (slot > 0) const SizedBox(width: 9),
            Expanded(
                child: order[slot] >= podium.length
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey('americano-podium-${slot + 1}'),
                        height: [96.0, 116.0, 86.0][slot],
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: HaykoColors.fieldSurface,
                          border: Border.all(
                              color: colors[order[slot]].withValues(alpha: .8)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${podium[order[slot]].rank}°',
                                  style: TextStyle(
                                      color: colors[order[slot]],
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(playerName(podium[order[slot]].playerId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${podium[order[slot]].points} pt',
                                  style: const TextStyle(
                                      color: HaykoColors.mutedText,
                                      fontSize: 12)),
                            ]),
                      )),
          ]
        ],
      ),
    );
  }
}

class AmericanoStandingTable extends StatelessWidget {
  const AmericanoStandingTable(
      {super.key,
      required this.standings,
      required this.playerName,
      required this.currentPlayerId,
      required this.players});
  final List<AmericanoStanding> standings;
  final String Function(String) playerName;
  final String? currentPlayerId;
  final List<Player> players;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const base = <double>[36, 146, 38, 38, 38, 38];
        final ratio =
            (box.maxWidth - 2) / base.fold<double>(0, (a, b) => a + b);
        final widths = [for (final width in base) width * ratio];
        return Container(
          decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(color: HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _StandingRow(
                widths: widths,
                header: true,
                values: const ['#', 'Giocatore', 'PT', 'V', 'S', '+/-']),
            for (final row in standings)
              _StandingRow(
                key: ValueKey('americano-standing-${row.playerId}'),
                widths: widths,
                currentColor: row.playerId == currentPlayerId
                    ? Color(
                        players.firstWhere((p) => p.id == row.playerId).color)
                    : null,
                values: [
                  '${row.rank}',
                  playerName(row.playerId),
                  '${row.points}',
                  '${row.wins}',
                  '${row.losses}',
                  '${row.difference >= 0 ? '+' : ''}${row.difference}',
                ],
              ),
          ]),
        );
      });
}

class _StandingRow extends StatelessWidget {
  const _StandingRow(
      {super.key,
      required this.widths,
      required this.values,
      this.header = false,
      this.currentColor});
  final List<double> widths;
  final List<String> values;
  final bool header;
  final Color? currentColor;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        color: header ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
        child: Stack(children: [
          if (!header && currentColor != null)
            Align(
                alignment: Alignment.centerLeft,
                child: Container(
                    key: const ValueKey('americano-current-player-indicator'),
                    width: 4,
                    height: 32,
                    color: currentColor)),
          Row(children: [
            for (var index = 0; index < values.length; index++)
              SizedBox(
                  width: widths[index],
                  child: Padding(
                    padding:
                        EdgeInsets.only(left: index == 0 ? 4 : 2, right: 2),
                    child: Text(values[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: index == 1 || index > 1
                            ? TextAlign.center
                            : TextAlign.left,
                        style: TextStyle(
                            fontSize: header ? 12 : 14,
                            height: header ? 16 / 12 : 20 / 14,
                            fontWeight:
                                header ? FontWeight.w600 : FontWeight.w400)),
                  )),
          ]),
        ]),
      );
}
