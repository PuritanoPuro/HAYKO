import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/americano_schedule.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoCalendarPage extends StatefulWidget {
  const PadelAmericanoCalendarPage({
    super.key,
    required this.league,
    required this.competition,
    required this.save,
  });

  final League league;
  final Competition competition;
  final Save save;

  @override
  State<PadelAmericanoCalendarPage> createState() =>
      _PadelAmericanoCalendarPageState();
}

class _PadelAmericanoCalendarPageState
    extends State<PadelAmericanoCalendarPage> {
  late AmericanoSchedule schedule;
  int selectedRound = 0;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    schedule = widget.competition.americanoSchedule.isNotEmpty
        ? _copy(widget.competition.americanoSchedule)
        : _generate();
  }

  AmericanoSchedule _generate() => generateAmericanoSchedule(
        playerIds: widget.competition.americanoPlayerIds,
        rounds: widget.competition.americanoRounds,
        courts: widget.competition.americanoCourts,
        rotatingPairs: widget.competition.americanoRotatingPairs,
      );

  AmericanoSchedule _copy(AmericanoSchedule source) => [
        for (final round in source)
          [
            for (final fixture in round) [...fixture]
          ],
      ];

  String playerName(String id) {
    final player = widget.league.players.firstWhere((p) => p.id == id);
    final first = player.name.trim().split(RegExp(r'\s+')).first;
    final sameFirst = widget.competition.americanoPlayerIds.where((candidate) {
      final name = widget.league.players
          .firstWhere((p) => p.id == candidate)
          .name
          .trim()
          .split(RegExp(r'\s+'))
          .first;
      return name.toLowerCase() == first.toLowerCase();
    }).length;
    return sameFirst > 1 ? player.name : first;
  }

  void regenerate() {
    setState(() {
      schedule = _generate();
      selectedRound = 0;
    });
  }

  Future<void> confirm() async {
    if (saving) return;
    final previous = _copy(widget.competition.americanoSchedule);
    widget.competition.americanoSchedule
      ..clear()
      ..addAll(_copy(schedule));
    setState(() => saving = true);
    try {
      await widget.save();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      widget.competition.americanoSchedule
        ..clear()
        ..addAll(previous);
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixtures = schedule[selectedRound];
    final playing = fixtures.expand((fixture) => fixture).toSet();
    final resting = widget.competition.americanoPlayerIds
        .where((id) => !playing.contains(id))
        .map(playerName)
        .toList();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: const Text('Calendario Americano'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('americano-calendar'),
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: HaykoColors.fieldSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: HaykoColors.padelAccent.withValues(alpha: .42)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Turno',
                      style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        key: const ValueKey('americano-round-picker'),
                        value: selectedRound,
                        isExpanded: true,
                        dropdownColor: HaykoColors.fieldSurface,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        items: [
                          for (var index = 0; index < schedule.length; index++)
                            DropdownMenuItem(
                              value: index,
                              child: Text(
                                  'Turno ${index + 1} di ${schedule.length}'),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedRound = value!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(
              height: 25,
              child: Text('Partite del turno',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < fixtures.length; index++) ...[
              _AmericanoCourtCard(
                key: ValueKey('americano-court-${index + 1}'),
                court: index + 1,
                targetPoints: widget.competition.americanoTargetPoints,
                fixture: fixtures[index],
                playerName: playerName,
              ),
              const SizedBox(height: 10),
            ],
            if (resting.isNotEmpty) ...[
              Text('Riposo: ${resting.join(', ')}',
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 13,
                      height: 20 / 13)),
              const SizedBox(height: 10),
            ],
            Text(
              widget.competition.americanoRotatingPairs
                  ? 'Al turno successivo compagni e avversari cambiano automaticamente.'
                  : 'Le coppie restano fisse; gli avversari cambiano automaticamente.',
              style: const TextStyle(
                  color: HaykoColors.mutedText, fontSize: 13, height: 20 / 13),
            ),
            const SizedBox(height: 10),
            AccountButton('Rigenera turni',
                key: const ValueKey('americano-regenerate'),
                outline: true,
                onPressed: saving ? null : regenerate),
            const SizedBox(height: 10),
            AccountButton('Conferma calendario',
                key: const ValueKey('americano-confirm-calendar'),
                onPressed: saving ? null : confirm),
          ],
        ),
      ),
    );
  }
}

class _AmericanoCourtCard extends StatelessWidget {
  const _AmericanoCourtCard({
    super.key,
    required this.court,
    required this.targetPoints,
    required this.fixture,
    required this.playerName,
  });

  final int court;
  final int targetPoints;
  final List<String> fixture;
  final String Function(String) playerName;

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: HaykoColors.padelAccent.withValues(alpha: .35)),
        ),
        child: Column(children: [
          SizedBox(
            height: 20,
            child: Row(children: [
              Expanded(
                child: Text('CAMPO $court',
                    style: const TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              Text('$targetPoints PUNTI',
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 5),
          _AmericanoPair(
              color: HaykoColors.padelAccent,
              names: '${playerName(fixture[0])} / ${playerName(fixture[1])}'),
          const SizedBox(height: 5),
          const SizedBox(
            height: 18,
            child: Center(
              child: Text('VS',
                  style: TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 5),
          _AmericanoPair(
              color: const Color(0xffff8c47),
              names: '${playerName(fixture[2])} / ${playerName(fixture[3])}'),
        ]),
      );
}

class _AmericanoPair extends StatelessWidget {
  const _AmericanoPair({required this.color, required this.names});
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
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(names,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
