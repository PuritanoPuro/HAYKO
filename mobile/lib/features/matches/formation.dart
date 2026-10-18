import 'dart:math';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/competitions/competition_match_form.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
              padding: const EdgeInsets.all(16),
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

  Future<void> pickScheduled() async {
    final date = await showDatePicker(
        context: context,
        initialDate: scheduled,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(scheduled));
    if (time == null || !mounted) return;
    setState(() => scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String get scheduledLabel {
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
    final hour = scheduled.hour.toString().padLeft(2, '0');
    final minute = scheduled.minute.toString().padLeft(2, '0');
    return '${scheduled.day} ${months[scheduled.month - 1]} ${scheduled.year} · $hour:$minute';
  }

  void continueToFormation() {
    if (competition != null && presetIds.any((id) => id == null)) {
      showError(context, 'Seleziona entrambe le squadre della competizione.');
      return;
    }
    if (names.any((name) => name.text.trim().isEmpty)) {
      showError(context, 'Inserisci i nomi delle squadre.');
      return;
    }
    if (widget.league.players.length < format * 2) {
      showError(context, 'Servono almeno ${format * 2} giocatori nella lega.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => step = 1);
  }

  Widget setupBody() => ListView(
        key: const ValueKey('match-setup'),
        padding: const EdgeInsets.all(24),
        children: [
          _SetupField(
            label: 'Tipologia partita',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                  isExpanded: true,
                  value: format,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    for (var value = 2; value <= 11; value++)
                      DropdownMenuItem(
                          value: value, child: Text('$value contro $value'))
                  ],
                  onChanged: competitionId != null
                      ? null
                      : (value) => setState(() {
                            format = value!;
                            for (final team in teams) {
                              team.clear();
                            }
                            presetIds[0] = presetIds[1] = null;
                          })),
            ),
          ),
          const SizedBox(height: 12),
          if (competition == null)
            for (var team = 0; team < 2; team++) ...[
              _TeamSetupField(
                label: 'Squadra ${team == 0 ? 'A' : 'B'}',
                controller: names[team],
                color: colors[team],
                onColor: () async {
                  final value = await chooseColor(context, colors[team]);
                  if (value != null && mounted) {
                    setState(() => colors[team] = value);
                  }
                },
              ),
              const SizedBox(height: 12),
            ]
          else
            for (var team = 0; team < 2; team++) ...[
              _SetupField(
                label: 'Squadra ${team == 0 ? 'A' : 'B'}',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey('competition-team-$team'),
                    isExpanded: true,
                    value: presetIds[team],
                    hint: const Text('Seleziona squadra'),
                    items: widget.league.presets
                        .where((preset) =>
                            !preset.archived &&
                            competition!.teamIds.contains(preset.id) &&
                            preset.id != presetIds[1 - team])
                        .map((preset) => DropdownMenuItem(
                            value: preset.id, child: Text(preset.name)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => loadPreset(team, value!)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          _SetupField(
            label: 'Data e ora',
            onTap: pickScheduled,
            child: Text(scheduledLabel,
                style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
          const SizedBox(height: 12),
          _SetupField(
            label: 'Luogo · facoltativo',
            child: TextField(
              key: const ValueKey('event-venue'),
              controller: venue,
              maxLength: 120,
              style: const TextStyle(fontSize: 16, height: 1.5),
              decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: 'Inserisci il luogo',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 12),
          AccountButton('Seleziona formazione', onPressed: continueToFormation),
        ],
      );

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
                : step == 0
                    ? setupBody()
                    : ListView(
                        key: ValueKey(step),
                        padding: const EdgeInsets.all(20),
                        children: [
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
                                              order:
                                                  List<String>.from(order[n]),
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
                                          scheduledAt: scheduled
                                              .toUtc()
                                              .toIso8601String(),
                                          venue: venue.text.trim(),
                                          teamColors: [...colors],
                                          presetIds: [...presetIds],
                                          competitionId: competitionId,
                                          knockoutRound:
                                              competition?.kind == 'knockout'
                                                  ? fixtures
                                                      .firstWhere((t) =>
                                                          fixtureId(t) ==
                                                          fixtureKey)
                                                      .round
                                                  : null);
                                      validateCompetitionMatch(
                                          widget.league, m);
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

class _SetupField extends StatelessWidget {
  const _SetupField({required this.label, required this.child, this.onTap});
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 76,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HaykoColors.fieldLine)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: child)),
            ]),
          ),
        ),
      );
}

class _TeamSetupField extends StatelessWidget {
  const _TeamSetupField(
      {required this.label,
      required this.controller,
      required this.color,
      required this.onColor});
  final String label;
  final TextEditingController controller;
  final int color;
  final VoidCallback onColor;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: controller,
                    maxLength: 60,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    decoration: const InputDecoration(
                        isCollapsed: true,
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
            ]),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onColor,
            child: Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: Color(color), shape: BoxShape.circle)),
          ),
        ]),
      );
}
