import 'dart:math';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/statistics/statistics_page.dart';

class CompetitionsPage extends StatefulWidget {
  final League league;
  final Save save;
  const CompetitionsPage({super.key, required this.league, required this.save});
  @override
  State<CompetitionsPage> createState() => _CompetitionsPageState();
}

class _CompetitionsPageState extends State<CompetitionsPage> {
  League get l => widget.league;
  String? selected;
  bool busy = false;
  Future<void> team() async {
    if (busy) return;
    await Navigator.push<TeamPreset>(
        context,
        MaterialPageRoute(
            builder: (_) => TeamEditor(league: l, save: widget.save)));
    if (mounted) setState(() {});
  }

  Future<void> draw(Competition c) async {
    if (busy || l.matches.any((m) => m.competitionId == c.id)) return;
    if (!await confirm(context, 'Generare i turni casuali?',
        'Le squadre verranno sorteggiate. Le date e i luoghi si scelgono creando le singole partite.')) {
      return;
    }
    if (!mounted) return;
    final before = [...c.teamIds];
    setState(() => busy = true);
    c.teamIds.shuffle(Random.secure());
    try {
      await widget.save();
    } catch (e) {
      c.teamIds
        ..clear()
        ..addAll(before);
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> create() async {
    final c = await Navigator.push<Competition>(
        context,
        MaterialPageRoute(
            builder: (_) => CompetitionForm(league: l, save: widget.save)));
    if (c == null) return;
    l.competitions.add(c);
    try {
      await widget.save();
      selected = c.id;
    } catch (e) {
      l.competitions.remove(c);
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() {});
  }

  Future<void> event(Competition c) async {
    if (busy) return;
    final m = await Navigator.push<Match>(
        context,
        MaterialPageRoute(
            builder: (_) => NewMatchPage(
                league: l, save: widget.save, initialCompetition: c.id)));
    if (m == null) return;
    setState(() => busy = true);
    try {
      validateCompetitionMatch(l, m);
      l.matches.add(m);
      await widget.save();
    } catch (e) {
      l.matches.remove(m);
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final options = l.competitions;
    final c = options.isEmpty
        ? null
        : options.firstWhere((c) => c.id == selected,
            orElse: () => options.first);
    final rows = c == null ? <TeamStats>[] : teamStandings(l, c);
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Competizioni', style: TextStyle(fontSize: 24)),
      if (l.manage)
        OutlinedButton.icon(
            onPressed: busy ? null : team,
            icon: const Icon(Icons.groups),
            label: const Text('+ Squadra')),
      if (l.manage)
        FilledButton.icon(
            onPressed: busy ? null : create,
            icon: const Icon(Icons.add),
            label: const Text('Nuova competizione')),
      if (c == null)
        const Text(
            'Crea le squadre con + Squadra, poi selezionale in un campionato o torneo.'),
      if (c != null) ...[
        DropdownButton<String>(
            value: c.id,
            isExpanded: true,
            items: options
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => selected = v)),
        Text(c.kind == 'league'
            ? 'Campionato · 3 punti vittoria, 1 pareggio, 0 sconfitta'
            : 'Torneo a eliminazione · turni successivi dopo la conclusione del precedente'),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DataTable(
                columnSpacing: 16,
                columns: [
                  for (final title in [
                    'Squadra',
                    'PG',
                    'V',
                    'P',
                    'S',
                    'GF',
                    'GS',
                    'DG',
                    if (c.kind == 'league') 'Punti' else 'Stato'
                  ])
                    DataColumn(label: Text(title))
                ],
                rows: rows
                    .map((r) => DataRow(cells: [
                          DataCell(Row(children: [
                            CircleAvatar(
                                radius: 7,
                                backgroundColor: Color(r.team.color)),
                            const SizedBox(width: 6),
                            Text(r.team.name)
                          ])),
                          for (final n in [
                            r.played,
                            r.wins,
                            r.draws,
                            r.losses,
                            r.goals,
                            r.conceded,
                            r.difference
                          ])
                            DataCell(Text('$n')),
                          DataCell(Text(c.kind == 'league'
                              ? '${r.points}'
                              : tournamentStatus(l, c, r.team.id))),
                        ]))
                    .toList())),
        if (l.manage && !l.matches.any((m) => m.competitionId == c.id))
          TextButton.icon(
              onPressed: busy ? null : () => draw(c),
              icon: const Icon(Icons.shuffle),
              label: const Text('Genera turni casuali')),
        if (c.kind == 'league') ...[
          const SizedBox(height: 16),
          const Text('Calendario · sola andata',
              style: TextStyle(fontSize: 22)),
          ...leagueFixtures(l, c).map((tie) => Card(
                  child: ListTile(
                title: Text(tie.teams
                    .map((id) => l.presets.firstWhere((p) => p.id == id).name)
                    .join(' – ')),
                subtitle: Text(
                    'Giornata ${tie.round} · ${tie.match == null ? 'Da programmare' : statusName(tie.match!.status)}'),
              ))),
        ],
        if (c.kind == 'knockout') ...[
          const SizedBox(height: 16),
          const Text('Incontri', style: TextStyle(fontSize: 22)),
          ...tournamentTies(l, c).map((tie) => Card(
                  child: ListTile(
                title: Text(tie.teams
                    .map((id) => l.presets.firstWhere((p) => p.id == id).name)
                    .join(' – ')),
                subtitle: Text(
                    'Turno ${tie.round} · ${tie.match == null ? 'Da programmare' : statusName(tie.match!.status)}'),
                trailing: tie.winner == null
                    ? null
                    : Text(
                        'Passa ${l.presets.firstWhere((p) => p.id == tie.winner).name}'),
              ))),
        ],
        if (l.manage)
          FilledButton.icon(
              onPressed: busy ? null : () => event(c),
              icon: const Icon(Icons.sports_soccer),
              label: const Text('Crea partita della competizione')),
        const SizedBox(height: 24),
        const Text('Statistiche giocatori della competizione',
            style: TextStyle(fontSize: 22)),
        StatisticsPage(
            key: ValueKey(c.id),
            league: competitionPlayers(l, c),
            embedded: true),
      ],
    ]);
  }
}

class CompetitionForm extends StatefulWidget {
  final League league;
  final Save save;
  const CompetitionForm({super.key, required this.league, required this.save});
  @override
  State<CompetitionForm> createState() => _CompetitionFormState();
}

class _CompetitionFormState extends State<CompetitionForm> {
  final name = TextEditingController();
  String kind = 'league';
  int format = 5;
  final selected = <String>[];
  @override
  void initState() {
    super.initState();
    if (widget.league.presets.isNotEmpty) {
      format = widget.league.presets.first.players.length;
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Nuova competizione')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
            controller: name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nome competizione')),
        DropdownButton<String>(
            value: kind,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'league', child: Text('Campionato')),
              DropdownMenuItem(
                  value: 'knockout', child: Text('Torneo a eliminazione'))
            ],
            onChanged: (v) => setState(() => kind = v!)),
        DropdownButton<int>(
            value: format,
            isExpanded: true,
            items: [
              for (var n = 2; n <= 11; n++)
                DropdownMenuItem(value: n, child: Text('$n contro $n'))
            ],
            onChanged: (v) => setState(() {
                  format = v!;
                  selected.clear();
                })),
        OutlinedButton.icon(
            onPressed: () async {
              final p = await Navigator.push<TeamPreset>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TeamEditor(
                          league: widget.league,
                          save: widget.save,
                          initialFormat: format)));
              if (mounted) {
                setState(() {
                  if (p != null) selected.add(p.id);
                });
              }
            },
            icon: const Icon(Icons.groups),
            label: const Text('+ Squadra')),
        const Text(
            'Seleziona le squadre partecipanti. L’ordine definisce gli accoppiamenti del primo turno a eliminazione.'),
        if (kind == 'knockout')
          const Text(
              'Servono 2, 4, 8 o 16 squadre. I pareggi richiedono la scelta di chi passa il turno.'),
        for (final p
            in widget.league.presets.where((p) => p.players.length == format))
          CheckboxListTile(
              title: Text(p.name),
              value: selected.contains(p.id),
              secondary:
                  CircleAvatar(radius: 10, backgroundColor: Color(p.color)),
              onChanged: (v) => setState(() {
                    if (v == true) {
                      selected.add(p.id);
                    } else {
                      selected.remove(p.id);
                    }
                  })),
        Text('${selected.length} squadre selezionate'),
        if (selected.isNotEmpty)
          Text(
              'Ordine: ${selected.map((id) => widget.league.presets.firstWhere((p) => p.id == id).name).join(' → ')}'),
        TextButton.icon(
            onPressed: selected.length < 2
                ? null
                : () => setState(() => selected.shuffle(Random.secure())),
            icon: const Icon(Icons.shuffle),
            label: const Text('Sorteggia ordine squadre')),
        FilledButton(
            onPressed: () {
              try {
                Navigator.pop(
                    context,
                    Competition(newId(), name.text.trim(), kind, format,
                        [...selected]));
              } catch (e) {
                showError(context, e);
              }
            },
            child: const Text('Crea competizione')),
      ]));
}
