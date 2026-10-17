import 'dart:math';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/competitions/competition_match_form.dart';

class NewMatchPage extends StatefulWidget {
  final League league;
  final Save? save;
  final String? initialCompetition;
  final List<String>? initialTeams;
  const NewMatchPage(
      {super.key,
      required this.league,
      this.save,
      this.initialCompetition,
      this.initialTeams});
  @override
  State<NewMatchPage> createState() => _NewMatchPageState();
}

class _NewMatchPageState extends State<NewMatchPage> {
  int format = 5, step = 0;
  final names = [
    TextEditingController(text: 'Chiari'),
    TextEditingController(text: 'Scuri')
  ];
  final teams = [<String>[], <String>[]];
  final presetIds = <String?>[null, null];
  final colors = [0xff8ebcff, 0xffffab64];
  DateTime scheduled = DateTime.now();
  final venue = TextEditingController();
  String? competitionId, fixtureKey;
  @override
  void initState() {
    super.initState();
    scheduled = DateTime(scheduled.year, scheduled.month, scheduled.day,
        scheduled.hour, scheduled.minute);
    colors[0] = widget.league.primaryColor;
    colors[1] = widget.league.secondaryColor;
    competitionId = widget.initialCompetition ??
        (widget.league.type == 'competition' &&
                widget.league.competitions.isNotEmpty
            ? widget.league.competitions.first.id
            : null);
    if (competitionId != null) {
      format = widget.league.competitions
          .firstWhere((c) => c.id == competitionId)
          .format;
    }
    if (widget.initialTeams != null) {
      for (var t = 0; t < 2; t++) {
        loadPreset(t, widget.initialTeams![t]);
      }
      final ties = fixtures.where((tie) => tie.teams.every(presetIds.contains));
      if (ties.isNotEmpty) fixtureKey = fixtureId(ties.first);
    }
  }

  Competition? get competition => competitionId == null
      ? null
      : widget.league.competitions.firstWhere((c) => c.id == competitionId);
  List<TournamentTie> get fixtures => competition?.kind == 'knockout'
      ? tournamentTies(widget.league, competition!)
          .where((t) => t.match == null)
          .toList()
      : [];
  String fixtureId(TournamentTie t) => '${t.round}:${t.teams.join('|')}';
  void loadPreset(int t, String id) {
    final p = widget.league.presets.firstWhere((p) => p.id == id);
    teams[t] = p.players.take(format).toList();
    names[t].text = p.name;
    colors[t] = p.color;
    presetIds[t] = id;
    order[t] = [...teams[t]]..shuffle(Random.secure());
    fixed[t] = null;
  }

  final modes = ['rotation', 'rotation'];
  final fixed = <String?>[null, null];
  final order = [<String>[], <String>[]];
  final minutes = [5, 5];
  final sound = [true, true], vibration = [true, true];
  @override
  void dispose() {
    for (final n in names) {
      n.dispose();
    }
    venue.dispose();
    super.dispose();
  }

  List<Player> get alphabetical => [...widget.league.players]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  String teamName(int t) => names[t].text.trim();
  Future<void> acceptTeam(int t) async {
    if (teams[t].length != format) return;
    if (teams[t].any(teams[1 - t].contains)) {
      showError(
          context, 'Un giocatore non può partecipare a entrambe le squadre.');
      return;
    }
    final selected = alphabetical
        .where((p) => teams[t].contains(p.id))
        .map((p) => p.name)
        .join('\n');
    var savePreset = false;
    var presetName = teamName(t);
    final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                    title: Text('Formazione ${teamName(t)}'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(selected),
                      if (competitionId == null)
                        CheckboxListTile(
                            title: const Text('Salva squadra come preset'),
                            value: savePreset,
                            onChanged: (v) => set(() => savePreset = v!)),
                      if (savePreset)
                        TextFormField(
                            initialValue: presetName,
                            onChanged: (value) => presetName = value,
                            maxLength: 60,
                            decoration: const InputDecoration(
                                labelText: 'Nome del preset')),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Modifica')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Conferma'))
                    ])));
    final label = presetName.trim();
    if (!mounted || accepted != true) return;
    if (savePreset) {
      if (label.isEmpty ||
          widget.league.presets.any((p) =>
              !p.archived && p.name.toLowerCase() == label.toLowerCase())) {
        showError(context, 'Inserisci un nome di preset nuovo e non vuoto.');
        return;
      }
      final preset =
          TeamPreset(newId(), label, [...teams[t]], color: colors[t]);
      widget.league.presets.add(preset);
      try {
        await widget.save?.call();
      } catch (e) {
        widget.league.presets.remove(preset);
        if (mounted) showError(context, e);
        return;
      }
      if (!mounted) return;
      presetIds[t] = preset.id;
      names[t].text = label;
    }
    setState(() {
      if (order[t].length != teams[t].length ||
          order[t].any((p) => !teams[t].contains(p))) {
        order[t] = [...teams[t]]..shuffle(Random.secure());
        fixed[t] = null;
      }
      step++;
    });
  }

  Future<void> addPlayer() async {
    await addLeaguePlayer(context, widget.league, widget.save);
    if (mounted) setState(() {});
  }

  Widget keeperSettings(int t) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(teamName(t), style: const TextStyle(fontSize: 24)),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'fixed', label: Text('Fisso')),
          ButtonSegment(value: 'rotation', label: Text('Rotazione'))
        ], selected: {
          modes[t]
        }, onSelectionChanged: (v) => setState(() => modes[t] = v.first)),
        if (modes[t] == 'fixed')
          DropdownButton<String>(
              isExpanded: true,
              value: fixed[t],
              hint: const Text('Seleziona portiere'),
              items: teams[t]
                  .map((id) => DropdownMenuItem(
                      value: id, child: Text(widget.league.playerName(id))))
                  .toList(),
              onChanged: (v) => setState(() => fixed[t] = v)),
        if (modes[t] == 'rotation') ...[
          DropdownButton<int>(
              isExpanded: true,
              value: minutes[t],
              items: [
                for (var n = 1; n <= 60; n++)
                  DropdownMenuItem(
                      value: n, child: Text('Cambio ogni $n minuti'))
              ],
              onChanged: (v) => setState(() => minutes[t] = v!)),
          const Text(
              'Il primo giocatore inizia in porta. Tieni premuto un nome e trascinalo nella posizione desiderata.'),
          ReorderableListView.builder(
            key: ValueKey('keeper-list-$t'),
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: order[t].length,
            onReorderItem: (oldIndex, newIndex) => setState(() {
              final player = order[t].removeAt(oldIndex);
              order[t].insert(newIndex, player);
            }),
            itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
              key: ValueKey('keeper-$t-${order[t][i]}'),
              index: i,
              child: Listener(
                  behavior: HitTestBehavior.opaque,
                  child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                          leading: Text('${i + 1}'),
                          title: Text(widget.league.playerName(order[t][i])),
                          trailing: const Icon(Icons.drag_handle)))),
            ),
          ),
          TextButton.icon(
              onPressed: () =>
                  setState(() => order[t].shuffle(Random.secure())),
              icon: const Icon(Icons.shuffle),
              label: const Text('Genera nuovo ordine casuale')),
          SwitchListTile(
              title: const Text('Avviso sonoro sul telefono'),
              value: sound[t],
              onChanged: (v) => setState(() => sound[t] = v)),
          SwitchListTile(
              title: const Text('Vibrazione sul telefono'),
              value: vibration[t],
              onChanged: (v) => setState(() => vibration[t] = v)),
        ],
      ]);
  Widget selectionBody(int t) {
    final players = alphabetical;
    return Column(children: [
      Material(
          elevation: 2,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(children: [
                if (widget.league.presets.any((p) =>
                    !p.archived &&
                    (widget.league.type == 'competition'
                        ? p.players.length >= format
                        : p.players.length == format) &&
                    (competition == null ||
                        competition!.teamIds.contains(p.id))))
                  DropdownButton<String>(
                      value: presetIds[t],
                      isExpanded: true,
                      hint: const Text('Carica una squadra salvata'),
                      items: widget.league.presets
                          .where((p) =>
                              !p.archived &&
                              (widget.league.type == 'competition'
                                  ? p.players.length >= format
                                  : p.players.length == format) &&
                              (competition == null ||
                                  competition!.teamIds.contains(p.id)))
                          .map((p) => DropdownMenuItem(
                              value: p.id, child: Text(p.name)))
                          .toList(),
                      onChanged: (v) => setState(() => loadPreset(t, v!))),
                Row(children: [
                  Expanded(
                      child: Text('${teams[t].length} / $format selezionati',
                          key: const ValueKey('selection-counter'),
                          style: const TextStyle(fontSize: 20))),
                  const SizedBox(width: 12),
                  FilledButton(
                      key: const ValueKey('selection-confirm'),
                      onPressed: teams[t].length == format
                          ? () => acceptTeam(t)
                          : null,
                      child: const Text('Conferma')),
                ]),
                TextButton.icon(
                    onPressed: addPlayer,
                    icon: const Icon(Icons.person_add),
                    label: const Text('+ Giocatore')),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: teams[t].length / format),
              ]))),
      Expanded(
          child: ListView.builder(
              key: ValueKey('team-roster-$t'),
              padding: const EdgeInsets.all(24),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final p = players[index];
                final other = teams[1 - t].contains(p.id),
                    selected = teams[t].contains(p.id);
                return Card(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: CheckboxListTile(
                        value: selected,
                        title: Text(p.name),
                        secondary: CircleAvatar(
                            radius: 9, backgroundColor: Color(p.color)),
                        subtitle:
                            other ? Text('Già in ${teamName(1 - t)}') : null,
                        onChanged: other && !selected
                            ? null
                            : (v) => setState(() {
                                  if (v == true && teams[t].length < format) {
                                    teams[t].add(p.id);
                                  } else if (v == false) {
                                    teams[t].remove(p.id);
                                  }
                                })));
              })),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.league.type == 'competition') {
      return CompetitionMatchForm(
          league: widget.league,
          initialCompetition: widget.initialCompetition,
          initialTeams: widget.initialTeams);
    }
    final t = step - 1;
    return Theme(
        data: leagueTheme(context, widget.league),
        child: Scaffold(
            appBar: AppBar(
                title: Text(step == 0
                    ? 'Nuova partita'
                    : step <= 2
                        ? 'Formazione ${teamName(t)}'
                        : 'Portieri'),
                leading: step == 0
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => step--))),
            body: step == 1 || step == 2
                ? selectionBody(t)
                : ListView(
                    key: ValueKey(step),
                    padding: const EdgeInsets.all(24),
                    children: [
                        if (step == 0) ...[
                          DropdownButton<int>(
                              isExpanded: true,
                              value: format,
                              items: [
                                for (var n = 2; n <= 11; n++)
                                  DropdownMenuItem(
                                      value: n, child: Text('$n contro $n'))
                              ],
                              onChanged: competitionId != null
                                  ? null
                                  : (n) => setState(() {
                                        format = n!;
                                        for (final team in teams) {
                                          team.clear();
                                        }
                                        presetIds[0] = presetIds[1] = null;
                                      })),
                          if (competition == null)
                            for (var n = 0; n < 2; n++)
                              TextField(
                                  controller: names[n],
                                  maxLength: 60,
                                  decoration: InputDecoration(
                                      labelText:
                                          'Nome squadra ${n == 0 ? 'A' : 'B'}')),
                          if (competition != null)
                            for (var n = 0; n < 2; n++)
                              DropdownButton<String>(
                                  key: ValueKey('competition-team-$n'),
                                  isExpanded: true,
                                  value: presetIds[n],
                                  hint: Text(
                                      'Seleziona squadra ${n == 0 ? 'A' : 'B'}'),
                                  items: widget.league.presets
                                      .where((p) =>
                                          !p.archived &&
                                          competition!.teamIds.contains(p.id) &&
                                          p.id != presetIds[1 - n])
                                      .map((p) => DropdownMenuItem(
                                          value: p.id, child: Text(p.name)))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                        loadPreset(n, v!);
                                        fixtureKey = null;
                                        if (competition?.kind == 'knockout') {
                                          final available = fixtures.where(
                                              (t) => t.teams
                                                  .every(presetIds.contains));
                                          if (available.isNotEmpty) {
                                            fixtureKey =
                                                fixtureId(available.first);
                                          }
                                        }
                                      })),
                          for (var n = 0; n < 2; n++)
                            ColorChoice(
                                label: 'Colore ${names[n].text}',
                                color: colors[n],
                                changed: (v) => setState(() => colors[n] = v)),
                          EventDetailsFields(
                              date: scheduled,
                              venue: venue,
                              changed: (v) => setState(() => scheduled = v)),
                          if (widget.league.type != 'competition' &&
                              widget.initialCompetition != null)
                            DropdownButton<String>(
                                value: competitionId ?? '',
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                      value: '',
                                      child: Text(
                                          'Amichevole / nessuna competizione')),
                                  ...widget.league.competitions.map((c) =>
                                      DropdownMenuItem(
                                          value: c.id, child: Text(c.name)))
                                ],
                                onChanged: (v) => setState(() {
                                      competitionId = v == '' ? null : v;
                                      fixtureKey = null;
                                      if (competition != null) {
                                        format = competition!.format;
                                      }
                                      for (final team in teams) {
                                        team.clear();
                                      }
                                      presetIds[0] = presetIds[1] = null;
                                    })),
                          if (competition?.kind == 'knockout') ...[
                            DropdownButton<String>(
                                value: fixtureKey,
                                isExpanded: true,
                                hint: const Text(
                                    'Scegli incontro del turno disponibile'),
                                items: fixtures
                                    .map((tie) => DropdownMenuItem(
                                        value: fixtureId(tie),
                                        child: Text(tie.teams
                                            .map((id) => widget.league.presets
                                                .firstWhere((p) => p.id == id)
                                                .name)
                                            .join(' – '))))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                      fixtureKey = v;
                                      final tie = fixtures
                                          .firstWhere((t) => fixtureId(t) == v);
                                      loadPreset(0, tie.teams[0]);
                                      loadPreset(1, tie.teams[1]);
                                    })),
                            if (fixtures.isEmpty)
                              const Text(
                                  'Concludi le partite del turno attuale per sbloccare il successivo; se la finale è terminata, il torneo è concluso.'),
                          ],
                          TextButton.icon(
                              onPressed: addPlayer,
                              icon: const Icon(Icons.person_add),
                              label: const Text('+ Giocatore')),
                          FilledButton(
                              onPressed: () {
                                if (competition != null &&
                                    presetIds.any((id) => id == null)) {
                                  showError(context,
                                      'Seleziona entrambe le squadre della competizione.');
                                  return;
                                }
                                if (competition?.kind == 'knockout' &&
                                    fixtureKey == null) {
                                  showError(context,
                                      'Seleziona un incontro disponibile.');
                                  return;
                                }
                                if (names.any((n) => n.text.trim().isEmpty)) {
                                  showError(context,
                                      'Inserisci i nomi delle squadre.');
                                  return;
                                }
                                if (widget.league.players.length < format * 2) {
                                  showError(context,
                                      'Servono almeno ${format * 2} giocatori nella lega.');
                                  return;
                                }
                                FocusScope.of(context).unfocus();
                                setState(() => step = 1);
                              },
                              child: const Text('Seleziona formazione')),
                        ],
                        if (step == 3) ...[
                          keeperSettings(0),
                          const Divider(height: 40),
                          keeperSettings(1),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: () {
                                try {
                                  final plans = [
                                    for (var n = 0; n < 2; n++)
                                      KeeperPlan(
                                          mode: modes[n],
                                          fixed: fixed[n],
                                          order: List<String>.from(order[n]),
                                          minutes: minutes[n],
                                          sound: sound[n],
                                          vibration: vibration[n])
                                  ];
                                  final m = Match(
                                      id: newId(),
                                      format: format,
                                      names: names
                                          .map((n) => n.text.trim())
                                          .toList(),
                                      teams: teams
                                          .map((t) => List<String>.from(t))
                                          .toList(),
                                      keepers: plans,
                                      creatorId: widget.league.currentUser,
                                      scheduledAt:
                                          scheduled.toUtc().toIso8601String(),
                                      venue: venue.text.trim(),
                                      teamColors: [...colors],
                                      presetIds: [...presetIds],
                                      competitionId: competitionId,
                                      knockoutRound: competition?.kind ==
                                              'knockout'
                                          ? fixtures
                                              .firstWhere((t) =>
                                                  fixtureId(t) == fixtureKey)
                                              .round
                                          : null);
                                  validateCompetitionMatch(widget.league, m);
                                  Navigator.pop(context, m);
                                } catch (e) {
                                  showError(context, e);
                                }
                              },
                              child: const Text('Crea partita')),
                        ],
                      ])));
  }
}
