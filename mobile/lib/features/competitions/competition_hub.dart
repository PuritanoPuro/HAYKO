import 'dart:math';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/main.dart' show MatchPage;
import 'package:calcetto_mvp/features/competitions/competitions_page.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/customization.dart';

Competition? competitionOf(League l) =>
    l.competitions.isEmpty ? null : l.competitions.first;
bool calendarLocked(League l, Competition c) =>
    l.matches.any((m) => m.competitionId == c.id);
String teamName(League l, String id) =>
    l.presets.firstWhere((p) => p.id == id).name;

class CompetitionTeams extends StatelessWidget {
  final League league;
  final Save save;
  final VoidCallback changed;
  const CompetitionTeams(
      {super.key,
      required this.league,
      required this.save,
      required this.changed});
  @override
  Widget build(BuildContext context) {
    final c = competitionOf(league);
    if (c == null) {
      return const Center(child: Text('Competizione non configurata.'));
    }
    final locked = calendarLocked(league, c);
    final winners = competitionWinners(league, c);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Squadre partecipanti',
          style: TextStyle(
              fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (league.manage)
        AccountButton('+ Squadra',
            onPressed: locked
                ? null
                : () async {
                    await Navigator.push<TeamPreset>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TeamEditor(
                                league: league,
                                save: save,
                                initialFormat: c.format,
                                competition: c)));
                    if (context.mounted) changed();
                  }),
      const SizedBox(height: 12),
      Text(
          locked
              ? 'Le partecipanti sono confermate: è già stata creata una partita.'
              : c.kind == 'knockout'
                  ? 'Aggiungi 2, 4, 8 o 16 squadre per completare il torneo.'
                  : 'Aggiungi almeno due squadre per completare il campionato.',
          style: const TextStyle(
              color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
      if (c.teamIds.isNotEmpty) const SizedBox(height: 12),
      for (var index = 0; index < c.teamIds.length; index++) ...[
        Builder(builder: (context) {
          final p = league.presets
              .firstWhere((preset) => preset.id == c.teamIds[index]);
          return _CompetitionTeamRow(
              team: p,
              winner: winners.contains(p.id),
              onTap: !league.manage
                  ? null
                  : () async {
                      await Navigator.push<TeamPreset>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TeamEditor(
                                  league: league,
                                  save: save,
                                  team: p,
                                  competition: c,
                                  initialFormat: c.format)));
                      if (context.mounted) changed();
                    });
        }),
        if (index != c.teamIds.length - 1) const SizedBox(height: 12),
      ],
    ]);
  }
}

class _CompetitionTeamRow extends StatelessWidget {
  const _CompetitionTeamRow(
      {required this.team, required this.winner, required this.onTap});

  final TeamPreset team;
  final bool winner;
  final VoidCallback? onTap;

  String get initials {
    final words = team.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(team.color),
                    child: Text(initials,
                        style: TextStyle(
                            color: contrastColor(team.color),
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(team.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, height: 1.5)),
                      Text('${team.players.length} giocatori',
                          style: const TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600)),
                    ])),
                if (winner) ...[
                  const WinnerBadge(),
                  const SizedBox(width: 8),
                ],
                const SizedBox(
                    width: 64,
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('›',
                            style: TextStyle(
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w600)))),
              ]),
            ),
          ),
        ),
      );
}

class CompetitionStatistics extends StatefulWidget {
  final League league;
  const CompetitionStatistics({super.key, required this.league});
  @override
  State<CompetitionStatistics> createState() => _CompetitionStatisticsState();
}

class _CompetitionStatisticsState extends State<CompetitionStatistics> {
  int phase = 0;
  League get league => widget.league;
  @override
  Widget build(BuildContext context) {
    final c = competitionOf(league);
    if (c == null) {
      return const Center(child: Text('Competizione non configurata.'));
    }
    final rows = teamStandings(league, c);
    final winners = competitionWinners(league, c);
    var phaseCount = 0, size = c.teamIds.length;
    while (size > 1) {
      phaseCount++;
      size ~/= 2;
    }
    final allTies =
        c.kind == 'knockout' ? tournamentTies(league, c) : <TournamentTie>[];
    if (c.kind == 'knockout' && phase == 0 && phaseCount > 0) {
      final playedRounds = allTies
          .where((tie) => tie.match != null)
          .map((tie) => tie.round)
          .toList();
      phase = playedRounds.isEmpty ? 1 : playedRounds.reduce(max);
    }
    final selectedPhase = phase.clamp(1, max(1, phaseCount)).toInt();
    final ties = allTies.where((tie) => tie.round == selectedPhase).toList();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(c.kind == 'league' ? 'Classifica squadre' : 'Tabellone',
          style: const TextStyle(
              fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800)),
      if (c.kind == 'league') ...[
        const SizedBox(height: 12),
        _CompetitionStandingsTable(rows: rows, winners: winners),
      ],
      if (c.kind == 'knockout') ...[
        if (!c.ready)
          const Text(
              'Completa le squadre partecipanti per visualizzare il tabellone.'),
        if (c.ready) ...[
          const SizedBox(height: 12),
          _TournamentPhaseField(
              competition: c,
              phaseCount: phaseCount,
              selected: selectedPhase,
              changed: (value) => setState(() => phase = value)),
          const SizedBox(height: 12),
        ],
        if (c.ready && ties.isEmpty)
          const Text(
              'Le squadre di questa fase saranno definite al termine della fase precedente.'),
        for (var index = 0; index < ties.length; index++) ...[
          _TournamentResultCard(
              league: league, competition: c, tie: ties[index]),
          if (index != ties.length - 1) const SizedBox(height: 12),
        ],
        if (c.ready && ties.any((tie) => tie.teams.contains(''))) ...[
          const SizedBox(height: 12),
          const Text(
              'Le squadre saranno definite al termine della fase precedente.',
              style: TextStyle(
                  color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
        ],
      ],
      if (c.kind == 'knockout' &&
          selectedPhase == phaseCount &&
          winners.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final id in winners)
          Text('${teamName(league, id)} · Vincitrice',
              key: ValueKey('competition-winner-$id'),
              style: const TextStyle(
                  fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700)),
      ],
      CompetitionScorers(league: league, competition: c),
    ]);
  }
}

class _TournamentPhaseField extends StatelessWidget {
  const _TournamentPhaseField(
      {required this.competition,
      required this.phaseCount,
      required this.selected,
      required this.changed});

  final Competition competition;
  final int phaseCount;
  final int selected;
  final ValueChanged<int> changed;

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
          const Text('Fase del torneo',
              style: TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600)),
          Expanded(
              child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('tournament-phase-filter'),
              value: selected,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              dropdownColor: HaykoColors.fieldSurface,
              style: const TextStyle(
                  color: HaykoColors.chalk, fontSize: 16, height: 24 / 16),
              items: [
                for (var round = 1; round <= phaseCount; round++)
                  DropdownMenuItem(
                      value: round,
                      child: Text(tournamentRoundName(competition, round)))
              ],
              onChanged: (value) {
                if (value != null) changed(value);
              },
            ),
          )),
        ]),
      );
}

class _TournamentResultCard extends StatelessWidget {
  const _TournamentResultCard(
      {required this.league, required this.competition, required this.tie});

  final League league;
  final Competition competition;
  final TournamentTie tie;

  TeamPreset? team(int side) {
    final id = tie.teams[side];
    final teams = league.presets.where((team) => team.id == id);
    return teams.isEmpty ? null : teams.first;
  }

  String get phaseLabel {
    final value = tournamentRoundName(competition, tie.round);
    return switch (value) {
      'Semifinali' => 'Semifinale',
      'Quarti di finale' => 'Quarto di finale',
      'Ottavi di finale' => 'Ottavo di finale',
      'Sedicesimi di finale' => 'Sedicesimo di finale',
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final first = team(0), second = team(1), match = tie.match;
    final details = tie.winner == null
        ? phaseLabel
        : '$phaseLabel · Passa ${teamName(league, tie.winner!)}';
    return Container(
      key: ValueKey('tournament-tie-${tie.round}-${tie.teams.join('-')}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          _TournamentCardTeam(team: first),
          SizedBox(
              width: 42,
              child: Text('${match?.score(0) ?? 0}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w800))),
          const SizedBox(
              width: 12,
              child: Text('–',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.w700))),
          SizedBox(
              width: 42,
              child: Text('${match?.score(1) ?? 0}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w800))),
          _TournamentCardTeam(team: second),
        ]),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerLeft,
            child: Text(details,
                style: const TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 14,
                    height: 20 / 14))),
      ]),
    );
  }
}

class _TournamentCardTeam extends StatelessWidget {
  const _TournamentCardTeam({required this.team});
  final TeamPreset? team;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(team?.name ?? 'Da definire',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
              width: 56,
              height: 6,
              color: team == null ? HaykoColors.fieldLine : Color(team!.color)),
        ]),
      );
}

class CompetitionCalendar extends StatefulWidget {
  final League league;
  final Save save;
  final VoidCallback changed;
  const CompetitionCalendar(
      {super.key,
      required this.league,
      required this.save,
      required this.changed});
  @override
  State<CompetitionCalendar> createState() => _CompetitionCalendarState();
}

class _CompetitionCalendarState extends State<CompetitionCalendar> {
  bool busy = false;
  int? selectedRound;
  League get l => widget.league;
  Future<void> order(Competition c, bool random) async {
    if (busy || calendarLocked(l, c)) return;
    List<String>? ids;
    if (random) {
      if (!await confirm(context, 'Sorteggiare il calendario?',
          'Verranno modificati gli accoppiamenti e le giornate prima della creazione delle partite.')) {
        return;
      }
      ids = [...c.teamIds]..shuffle(Random.secure());
    } else {
      ids = await Navigator.push<List<String>>(
          context,
          MaterialPageRoute(
              builder: (_) => CalendarOrder(league: l, competition: c)));
    }
    if (!mounted || ids == null) return;
    final old = [...c.teamIds];
    setState(() => busy = true);
    c.teamIds
      ..clear()
      ..addAll(ids);
    try {
      await widget.save();
    } catch (e) {
      c.teamIds
        ..clear()
        ..addAll(old);
      if (mounted) showError(context, e);
    }
    if (mounted) {
      setState(() => busy = false);
      widget.changed();
    }
  }

  Future<void> event(Competition c, TournamentTie tie) async {
    if (busy) return;
    if (tie.match != null) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  MatchPage(league: l, match: tie.match!, save: widget.save)));
    } else {
      if (!l.manage) return;
      final m = await Navigator.push<Match>(
          context,
          MaterialPageRoute(
              builder: (_) => NewMatchPage(
                  league: l,
                  save: widget.save,
                  initialCompetition: c.id,
                  initialTeams: tie.teams)));
      if (!mounted || m == null) return;
      setState(() => busy = true);
      try {
        validateCompetitionMatch(l, m);
        l.matches.add(m);
        await widget.save();
      } catch (e) {
        l.matches.remove(m);
        if (mounted) showError(context, e);
      }
    }
    if (mounted) {
      setState(() => busy = false);
      widget.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = competitionOf(l);
    if (c == null) {
      return const Center(child: Text('Competizione non configurata.'));
    }
    final fixtures =
        c.kind == 'knockout' ? tournamentTies(l, c) : leagueFixtures(l, c);
    final rounds = fixtures.map((tie) => tie.round).toSet().toList()..sort();
    final locked = calendarLocked(l, c);
    if (rounds.isNotEmpty && !rounds.contains(selectedRound)) {
      selectedRound = rounds.first;
    }
    final visible = selectedRound == null
        ? <TournamentTie>[]
        : fixtures.where((tie) => tie.round == selectedRound).toList();
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Calendario',
          style: TextStyle(
              fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(
          '${c.format}v${c.format} · ${c.kind == 'knockout' ? 'Eliminazione' : c.doubleLeg ? 'Andata e ritorno' : 'Solo andata'}',
          style: const TextStyle(
              color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
      const SizedBox(height: 12),
      if (l.manage && c.ready) ...[
        AccountButton('Genera calendario casuale',
            onPressed: busy || locked ? null : () => order(c, true)),
        const SizedBox(height: 12),
        AccountButton('Configura calendario',
            outline: true,
            onPressed: busy || locked ? null : () => order(c, false)),
        const SizedBox(height: 12),
      ],
      if (!c.ready) ...[
        const Text('Completa le squadre partecipanti nella sezione Squadre.',
            style: TextStyle(
                color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
        const SizedBox(height: 12),
      ],
      if (rounds.isNotEmpty) ...[
        _CalendarRoundField(
          rounds: rounds,
          selected: selectedRound!,
          label: (round) => c.kind == 'knockout'
              ? tournamentRoundName(c, round)
              : 'Giornata $round',
          changed: (round) => setState(() => selectedRound = round),
        ),
        const SizedBox(height: 12),
      ],
      for (var index = 0; index < visible.length; index++) ...[
        _CompetitionCalendarMatch(
            league: l,
            tie: visible[index],
            onTap: busy ? null : () => event(c, visible[index])),
        if (index != visible.length - 1) const SizedBox(height: 12),
      ],
      if (c.kind == 'league' &&
          selectedRound != null &&
          c.teamIds.length.isOdd) ...[
        const SizedBox(height: 12),
        Text(
            'Riposa: ${c.teamIds.where((id) => !visible.any((tie) => tie.teams.contains(id))).map((id) => teamName(l, id)).join(', ')}',
            style: const TextStyle(
                color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
      ],
      if (l.competitions.length > 1)
        TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => Scaffold(
                        appBar: AppBar(
                            title: const Text('Competizioni precedenti')),
                        body: CompetitionsPage(league: l, save: widget.save)))),
            child: const Text('Apri le altre competizioni precedenti')),
    ]);
  }
}

class _CalendarRoundField extends StatelessWidget {
  const _CalendarRoundField(
      {required this.rounds,
      required this.selected,
      required this.label,
      required this.changed});

  final List<int> rounds;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> changed;

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
          const Text('Giornata',
              style: TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const ValueKey('competition-round-filter'),
                isExpanded: true,
                value: selected,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(
                    color: HaykoColors.chalk, fontSize: 16, height: 24 / 16),
                dropdownColor: HaykoColors.fieldSurface,
                items: [
                  for (final round in rounds)
                    DropdownMenuItem(value: round, child: Text(label(round)))
                ],
                onChanged: (round) {
                  if (round != null) changed(round);
                },
              ),
            ),
          ),
        ]),
      );
}

class _CompetitionCalendarMatch extends StatelessWidget {
  const _CompetitionCalendarMatch(
      {required this.league, required this.tie, required this.onTap});

  final League league;
  final TournamentTie tie;
  final VoidCallback? onTap;

  TeamPreset team(int index) =>
      league.presets.firstWhere((team) => team.id == tie.teams[index]);

  String details() {
    final match = tie.match;
    if (match == null) return 'Da programmare';
    if (match.scheduledAt == null) return statusName(match.status);
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    final date = DateTime.parse(match.scheduledAt!).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} · $hour:$minute · ${statusName(match.status)}';
  }

  @override
  Widget build(BuildContext context) {
    final first = team(0), second = team(1), match = tie.match;
    return Material(
      color: HaykoColors.fieldSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _CalendarTeam(team: first),
              SizedBox(
                  width: 42,
                  child: Text('${match?.score(0) ?? 0}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          height: 30 / 24,
                          fontWeight: FontWeight.w800))),
              const SizedBox(
                  width: 12,
                  child: Text('–',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 20,
                          height: 26 / 20,
                          fontWeight: FontWeight.w700))),
              SizedBox(
                  width: 42,
                  child: Text('${match?.score(1) ?? 0}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          height: 30 / 24,
                          fontWeight: FontWeight.w800))),
              _CalendarTeam(team: second),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (match == null) ...[
                const Icon(Icons.schedule,
                    color: HaykoColors.mutedText, size: 24),
                const SizedBox(width: 8),
              ],
              Expanded(
                  child: Text(details(),
                      style: const TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 14,
                          height: 20 / 14))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CalendarTeam extends StatelessWidget {
  const _CalendarTeam({required this.team});
  final TeamPreset team;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(width: 56, height: 6, color: Color(team.color)),
        ]),
      );
}

class CalendarOrder extends StatefulWidget {
  final League league;
  final Competition competition;
  const CalendarOrder(
      {super.key, required this.league, required this.competition});
  @override
  State<CalendarOrder> createState() => _CalendarOrderState();
}

class WinnerBadge extends StatelessWidget {
  const WinnerBadge({super.key});
  @override
  Widget build(BuildContext context) => const Tooltip(
      message: 'Vincitrice',
      child: Icon(Icons.emoji_events, color: Color(0xffffd54f), size: 22));
}

class CompetitionScorers extends StatelessWidget {
  final League league;
  final Competition competition;
  const CompetitionScorers(
      {super.key, required this.league, required this.competition});
  @override
  Widget build(BuildContext context) {
    final scoped = competitionPlayers(league, competition),
        data = stats(scoped, null);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final assists in [false, true]) ...[
        const SizedBox(height: 24),
        Text(assists ? 'Assistmen' : 'Marcatori',
            style: const TextStyle(
                fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          int total(Player p) =>
              assists ? data[p.id]!.assists : data[p.id]!.goals;
          final players = scoped.players.where((p) => total(p) > 0).toList()
            ..sort((a, b) {
              final diff = total(b).compareTo(total(a));
              return diff != 0
                  ? diff
                  : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          if (players.isEmpty) {
            return Text(assists
                ? 'Nessun assist registrato in partite terminate.'
                : 'Nessun gol registrato in partite terminate.');
          }
          return Column(children: [
            for (final player in players.take(3)) ...[
              _CompetitionPlayerStatRow(
                  player: player,
                  team: _competitionTeamFor(league, competition, player.id),
                  value: total(player),
                  current: league.myPlayer == player.id),
              const SizedBox(height: 12),
            ],
            _CompetitionRankingButton(
                label: assists
                    ? 'Vedi tutti gli assistmen'
                    : 'Vedi tutti i marcatori',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _CompetitionRankingPage(
                            league: league,
                            competition: competition,
                            players: players,
                            values: {for (final p in players) p.id: total(p)},
                            assists: assists)))),
          ]);
        }),
      ],
    ]);
  }
}

TeamPreset? _competitionTeamFor(
    League league, Competition competition, String playerId) {
  final teams = league.presets.where((team) =>
      competition.teamIds.contains(team.id) && team.players.contains(playerId));
  return teams.isEmpty ? null : teams.first;
}

class _CompetitionPlayerStatRow extends StatelessWidget {
  const _CompetitionPlayerStatRow(
      {required this.player,
      required this.team,
      required this.value,
      required this.current});

  final Player player;
  final TeamPreset? team;
  final int value;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('competition-stat-${player.id}'),
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
          border: current ? Border.all(color: HaykoColors.chalk) : null,
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${player.name}${current ? ' · Tu' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, height: 24 / 16)),
                if (team != null)
                  Text(
                      '${team!.name}${team!.numbers[player.id] == null ? '' : ' · #${team!.numbers[player.id]}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
              ])),
          const SizedBox(width: 8),
          SizedBox(
              width: 64,
              child: Text('$value',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700))),
        ]),
      );
}

class _CompetitionRankingButton extends StatelessWidget {
  const _CompetitionRankingButton(
      {required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: HaykoColors.fieldSurface,
              foregroundColor: HaykoColors.chalk,
              side: const BorderSide(color: HaykoColors.fieldLine),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w700),
            ),
            onPressed: onPressed,
            child: Text(label)),
      );
}

class _CompetitionRankingPage extends StatelessWidget {
  const _CompetitionRankingPage(
      {required this.league,
      required this.competition,
      required this.players,
      required this.values,
      required this.assists});

  final League league;
  final Competition competition;
  final List<Player> players;
  final Map<String, int> values;
  final bool assists;

  @override
  Widget build(BuildContext context) {
    final title = assists ? 'Assistmen' : 'Marcatori';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        for (final player in players) ...[
          _CompetitionPlayerStatRow(
              player: player,
              team: _competitionTeamFor(league, competition, player.id),
              value: values[player.id]!,
              current: league.myPlayer == player.id),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _CompetitionStandingsTable extends StatelessWidget {
  const _CompetitionStandingsTable({required this.rows, required this.winners});

  final List<TeamStats> rows;
  final List<String> winners;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaykoColors.fieldLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor:
                    const WidgetStatePropertyAll(HaykoColors.fieldLine),
                headingRowHeight: 48,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                horizontalMargin: 4,
                columnSpacing: 12,
                dividerThickness: 0,
                headingTextStyle: const TextStyle(
                    color: HaykoColors.chalk,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600),
                dataTextStyle: const TextStyle(
                    color: HaykoColors.chalk, fontSize: 14, height: 20 / 14),
                columns: [
                  for (final name in const [
                    'Squadra',
                    'PG',
                    'V',
                    'P',
                    'S',
                    'GF',
                    'GS',
                    'DR',
                    'Punti'
                  ])
                    DataColumn(label: Text(name))
                ],
                rows: [
                  for (final row in rows)
                    DataRow(cells: [
                      DataCell(SizedBox(
                          width: 118,
                          child: Row(children: [
                            Container(
                                width: 4,
                                height: 20,
                                color: Color(row.team.color)),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(row.team.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            if (winners.contains(row.team.id))
                              const Icon(Icons.emoji_events,
                                  size: 16, color: Color(0xffe3f24a)),
                          ]))),
                      for (final value in [
                        row.played,
                        row.wins,
                        row.draws,
                        row.losses,
                        row.goals,
                        row.conceded,
                        row.difference,
                        row.points
                      ])
                        DataCell(Center(child: Text('$value'))),
                    ]),
                ],
              ),
            ),
          ),
        ),
      );
}

class _CalendarOrderState extends State<CalendarOrder> {
  late final List<String> ids;
  int selectedRound = 1;

  @override
  void initState() {
    super.initState();
    ids = [...widget.competition.teamIds];
  }

  Competition get preview => Competition(
        widget.competition.id,
        widget.competition.name,
        widget.competition.kind,
        widget.competition.format,
        [...ids],
        doubleLeg: widget.competition.doubleLeg,
        allowDraft: true,
      );

  List<int> get rounds {
    if (widget.competition.kind == 'league') {
      final values = leagueFixtures(widget.league, preview)
          .map((tie) => tie.round)
          .toSet()
          .toList();
      values.sort();
      return values;
    }
    final values = <int>[];
    var teams = ids.length, round = 1;
    while (teams >= 2) {
      values.add(round++);
      teams ~/= 2;
    }
    return values;
  }

  String roundLabel(int round) => widget.competition.kind == 'league'
      ? 'Giornata $round'
      : tournamentRoundName(preview, round);

  List<TournamentTie> get visibleTies {
    if (widget.competition.kind == 'league') {
      return leagueFixtures(widget.league, preview)
          .where((tie) => tie.round == selectedRound)
          .toList();
    }
    if (selectedRound == 1) {
      return [
        for (var index = 0; index < ids.length; index += 2)
          TournamentTie(1, [ids[index], ids[index + 1]], null)
      ];
    }
    final teamCount = ids.length >> (selectedRound - 1);
    return [
      for (var index = 0; index < teamCount ~/ 2; index++)
        TournamentTie(selectedRound, const ['', ''], null)
    ];
  }

  void selectTeam(String current, String selected) {
    if (current == selected) return;
    final currentIndex = ids.indexOf(current);
    final selectedIndex = ids.indexOf(selected);
    if (currentIndex < 0 || selectedIndex < 0) return;
    setState(() {
      ids[currentIndex] = selected;
      ids[selectedIndex] = current;
    });
  }

  Widget teamOption(String id) {
    final team = widget.league.presets.firstWhere((team) => team.id == id);
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: Color(team.color), shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget slot(String? teamId, int matchIndex, int slotIndex) {
    final enabled = teamId != null;
    return Container(
      height: 76,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HaykoColors.fieldSurface,
        border: Border.all(color: HaykoColors.fieldLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Squadra ${slotIndex + 1}',
            style: const TextStyle(
                color: HaykoColors.mutedText,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 24,
          child: enabled
              ? DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey('calendar-slot-$matchIndex-$slotIndex'),
                    isExpanded: true,
                    value: teamId,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    dropdownColor: HaykoColors.fieldSurface,
                    style: const TextStyle(
                        color: HaykoColors.chalk,
                        fontSize: 16,
                        height: 24 / 16),
                    items: [
                      for (final id in ids)
                        DropdownMenuItem(value: id, child: teamOption(id))
                    ],
                    onChanged: (selected) {
                      if (selected != null) selectTeam(teamId, selected);
                    },
                  ),
                )
              : const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Da definire dal turno precedente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 16,
                          height: 24 / 16)),
                ),
        ),
      ]),
    );
  }

  Widget matchCard(TournamentTie tie, int index) {
    final known = tie.teams.every((id) => id.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Incontro ${index + 1}',
            style: const TextStyle(
                fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        slot(known ? tie.teams[0] : null, index, 0),
        const SizedBox(height: 8),
        slot(known ? tie.teams[1] : null, index, 1),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = rounds;
    if (options.isNotEmpty && !options.contains(selectedRound)) {
      selectedRound = options.first;
    }
    final ties = visibleTies;
    return Scaffold(
      appBar:
          AppBar(toolbarHeight: 64, title: const Text('Configura calendario')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _CalendarConfigurationField(
            label: widget.competition.kind == 'knockout'
                ? 'Fase del torneo'
                : 'Giornata',
            rounds: options,
            selected: selectedRound,
            roundLabel: roundLabel,
            changed: (round) => setState(() => selectedRound = round),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < ties.length; index++) ...[
            matchCard(ties[index], index),
            const SizedBox(height: 12),
          ],
          AccountButton('Conferma calendario',
              onPressed: () => Navigator.pop(context, ids)),
          const SizedBox(height: 12),
          AccountButton('Annulla',
              outline: true, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _CalendarConfigurationField extends StatelessWidget {
  const _CalendarConfigurationField(
      {required this.label,
      required this.rounds,
      required this.selected,
      required this.roundLabel,
      required this.changed});

  final String label;
  final List<int> rounds;
  final int selected;
  final String Function(int) roundLabel;
  final ValueChanged<int> changed;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          border: Border.all(color: HaykoColors.fieldLine),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const ValueKey('calendar-round-select'),
                  isExpanded: true,
                  value: selected,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  dropdownColor: HaykoColors.fieldSurface,
                  style: const TextStyle(
                      color: HaykoColors.chalk, fontSize: 16, height: 24 / 16),
                  items: [
                    for (final round in rounds)
                      DropdownMenuItem(
                          value: round, child: Text(roundLabel(round)))
                  ],
                  onChanged: (round) {
                    if (round != null) changed(round);
                  },
                ),
              ),
            ),
          ],
        ),
      );
}
