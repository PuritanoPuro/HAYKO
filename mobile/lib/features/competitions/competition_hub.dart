import 'dart:math';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/main.dart' show MatchPage;
import 'package:calcetto_mvp/features/competitions/competitions_page.dart';

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
      const Text('Squadre partecipanti', style: TextStyle(fontSize: 24)),
      if (league.manage)
        FilledButton.icon(
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
                  },
            icon: const Icon(Icons.add),
            label: const Text('Squadra')),
      Text(locked
          ? 'Le partecipanti sono confermate: è già stata creata una partita.'
          : c.kind == 'knockout'
              ? 'Aggiungi 2, 4, 8 o 16 squadre per completare il torneo.'
              : 'Aggiungi almeno due squadre per completare il campionato.'),
      ...c.teamIds.map((id) {
        final p = league.presets.firstWhere((p) => p.id == id);
        return Card(
            child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: Color(p.color),
                    child: const Icon(Icons.groups)),
                title: Text(p.name),
                subtitle: Text('${p.players.length} giocatori'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (winners.contains(p.id)) const WinnerBadge(),
                  const Icon(Icons.chevron_right)
                ]),
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TeamDetails(
                              league: league,
                              team: p,
                              competition: c,
                              save: save)));
                  if (context.mounted) changed();
                }));
      }),
    ]);
  }
}

class TeamDetails extends StatefulWidget {
  final League league;
  final TeamPreset team;
  final Competition competition;
  final Save save;
  const TeamDetails(
      {super.key,
      required this.league,
      required this.team,
      required this.competition,
      required this.save});
  @override
  State<TeamDetails> createState() => _TeamDetailsState();
}

class _TeamDetailsState extends State<TeamDetails> {
  @override
  Widget build(BuildContext context) {
    final p = widget.league.presets.firstWhere((p) => p.id == widget.team.id);
    final players = p.players
        .map((id) => widget.league.players.firstWhere((v) => v.id == id))
        .toList()
      ..sort(
          (a, b) => (p.numbers[a.id] ?? 100).compareTo(p.numbers[b.id] ?? 100));
    return Scaffold(
        appBar: AppBar(title: Text(p.name)),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          if (widget.league.manage)
            FilledButton.icon(
                onPressed: () async {
                  await Navigator.push<TeamPreset>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TeamEditor(
                              league: widget.league,
                              save: widget.save,
                              team: p,
                              competition: widget.competition,
                              initialFormat: widget.competition.format)));
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.edit),
                label: const Text('Modifica squadra e numeri')),
          ...players.map((player) => ListTile(
              leading: CircleAvatar(
                  backgroundColor: Color(p.color),
                  child: Text('${p.numbers[player.id] ?? '—'}')),
              title: Text(player.name),
              subtitle: const Text('Numero di maglia'))),
        ]));
  }
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
    final selectedPhase = phase <= phaseCount ? phase : 0;
    final ties = c.kind == 'knockout'
        ? tournamentTies(league, c)
            .where((tie) => selectedPhase == 0 || tie.round == selectedPhase)
            .toList()
        : <TournamentTie>[];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(c.kind == 'league' ? 'Classifica squadre' : 'Tabellone',
          style: const TextStyle(fontSize: 24)),
      if (c.kind == 'league')
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
                columnSpacing: 16,
                columns: [
                  for (final name in [
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
                rows: rows
                    .map((r) => DataRow(cells: [
                          DataCell(Row(children: [
                            CircleAvatar(
                                radius: 7,
                                backgroundColor: Color(r.team.color)),
                            const SizedBox(width: 8),
                            Text(r.team.name),
                            if (winners.contains(r.team.id))
                              const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: WinnerBadge())
                          ])),
                          for (final n in [
                            r.played,
                            r.wins,
                            r.draws,
                            r.losses,
                            r.goals,
                            r.conceded,
                            r.difference,
                            r.points
                          ])
                            DataCell(Text('$n'))
                        ]))
                    .toList())),
      if (c.kind == 'knockout') ...[
        if (!c.ready)
          const Text(
              'Completa le squadre partecipanti per visualizzare il tabellone.'),
        if (c.ready)
          DropdownButton<int>(
              key: const ValueKey('tournament-phase-filter'),
              value: selectedPhase,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 0, child: Text('Tutte le fasi')),
                for (var round = 1; round <= phaseCount; round++)
                  DropdownMenuItem(
                      value: round, child: Text(tournamentRoundName(c, round))),
              ],
              onChanged: (v) => setState(() => phase = v!)),
        if (c.ready && selectedPhase != 0 && ties.isEmpty)
          const Text(
              'Le squadre di questa fase saranno definite al termine della fase precedente.'),
        ...ties.map((tie) => ListTile(
            title:
                Text(tie.teams.map((id) => teamName(league, id)).join(' – ')),
            subtitle: Text(
                '${tournamentRoundName(c, tie.round)}${tie.winner == null ? '' : ' · Passa ${teamName(league, tie.winner!)}'}'),
            trailing: tie.match == null
                ? null
                : Text('${tie.match!.score(0)} – ${tie.match!.score(1)}'))),
        if (c.ready)
          const Text(
              'I turni successivi si completano con le squadre qualificate.'),
      ],
      if (winners.isNotEmpty)
        ...winners.map((id) => ListTile(
            leading: const Icon(Icons.emoji_events),
            title: Text(teamName(league, id)),
            subtitle: Text(
                winners.length > 1 ? 'Primo posto condiviso' : 'Vincitrice'))),
      CompetitionScorers(league: league, competition: c),
    ]);
  }
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
    final rounds = fixtures.map((t) => t.round).toSet().toList()..sort();
    final locked = calendarLocked(l, c);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Calendario', style: TextStyle(fontSize: 24)),
      Text(
          '${c.name} · ${c.format}v${c.format} · ${c.kind == 'knockout' ? 'Eliminazione' : c.doubleLeg ? 'Andata e ritorno' : 'Solo andata'}'),
      if (!c.ready)
        const Text('Completa le squadre partecipanti nella sezione Squadre.'),
      if (l.manage && c.ready) ...[
        FilledButton.icon(
            onPressed: busy || locked ? null : () => order(c, true),
            icon: const Icon(Icons.shuffle),
            label: const Text('Genera calendario casuale')),
        OutlinedButton.icon(
            onPressed: busy || locked ? null : () => order(c, false),
            icon: const Icon(Icons.tune),
            label: const Text('Configura calendario')),
        Text(locked
            ? 'Accoppiamenti confermati. Puoi modificare data, ora e luogo delle partite ancora programmate.'
            : 'Puoi sorteggiare o impostare l’ordine delle squadre. Premi un incontro per impostare data, ora e luogo.'),
      ],
      for (final round in rounds) ...[
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
                c.kind == 'knockout'
                    ? tournamentRoundName(c, round)
                    : 'Giornata $round',
                style: const TextStyle(fontSize: 22))),
        ...fixtures.where((t) => t.round == round).map((tie) => Card(
                child: ListTile(
              title: Text(tie.teams.map((id) => teamName(l, id)).join(' – ')),
              subtitle: Text(tie.match == null
                  ? 'Da programmare'
                  : statusName(tie.match!.status)),
              trailing: tie.match == null
                  ? const Icon(Icons.add)
                  : Text('${tie.match!.score(0)} – ${tie.match!.score(1)}'),
              onTap: busy ? null : () => event(c, tie),
            ))),
        if (c.kind == 'league' && c.teamIds.length.isOdd)
          Text(
              'Riposa: ${c.teamIds.where((id) => !fixtures.where((t) => t.round == round).any((t) => t.teams.contains(id))).map((id) => teamName(l, id)).join(', ')}'),
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
            style: const TextStyle(fontSize: 24)),
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
          return Column(
              children: players.asMap().entries.map((entry) {
            final p = entry.value;
            final teams = league.presets.where((t) =>
                competition.teamIds.contains(t.id) && t.players.contains(p.id));
            final team = teams.isEmpty ? null : teams.first;
            return ListTile(
                leading: Text('${entry.key + 1}'),
                title: Row(children: [
                  if (team != null) ...[
                    CircleAvatar(radius: 7, backgroundColor: Color(team.color)),
                    const SizedBox(width: 8)
                  ],
                  Expanded(child: Text(p.name))
                ]),
                subtitle: team == null
                    ? null
                    : Text(
                        '${team.name}${team.numbers[p.id] == null ? '' : ' · #${team.numbers[p.id]}'}'),
                trailing: Text('${total(p)}'));
          }).toList());
        }),
      ],
    ]);
  }
}

class _CalendarOrderState extends State<CalendarOrder> {
  late final List<String> ids;
  @override
  void initState() {
    super.initState();
    ids = [...widget.competition.teamIds];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Configura calendario'), actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, ids),
            child: const Text('Conferma'))
      ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.competition.kind == 'knockout'
                ? 'Trascina le squadre: prima contro seconda, terza contro quarta e così via.'
                : 'Trascina le squadre per configurare gli accoppiamenti del girone. Le giornate vengono calcolate senza doppie presenze.')),
        if (widget.competition.kind == 'league')
          SizedBox(
              height: 140,
              child: ListView(
                  children: leagueFixtures(
                          widget.league,
                          Competition(
                              widget.competition.id,
                              widget.competition.name,
                              'league',
                              widget.competition.format,
                              [...ids],
                              doubleLeg: widget.competition.doubleLeg))
                      .where((t) => t.round == 1)
                      .map((tie) => Card(
                          child: ListTile(
                              title: Text(tie.teams
                                  .map((id) => teamName(widget.league, id))
                                  .join(' – ')),
                              subtitle: const Text('Prima giornata'))))
                      .toList())),
        Expanded(
            child: ReorderableListView.builder(
                itemCount: ids.length,
                onReorderItem: (from, to) => setState(() {
                      ids.insert(to, ids.removeAt(from));
                    }),
                itemBuilder: (context, i) => Container(
                    key: ValueKey(ids[i]),
                    margin: EdgeInsets.fromLTRB(
                        16, i.isEven ? 12 : 0, 16, i.isOdd ? 12 : 0),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.vertical(
                            top: i.isEven
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottom: i.isOdd || i == ids.length - 1
                                ? const Radius.circular(12)
                                : Radius.zero)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i.isEven)
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Text(
                                    widget.competition.kind == 'knockout'
                                        ? 'Incontro ${i ~/ 2 + 1}'
                                        : 'Posizioni ${i + 1}–${i + 2}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                          if (i.isOdd)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                              leading: Text('${i + 1}'),
                              title: Text(teamName(widget.league, ids[i])),
                              trailing: const Icon(Icons.drag_handle)),
                        ])))),
      ]));
}
