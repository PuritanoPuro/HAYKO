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
  final playerSearch = TextEditingController();
  final playerSearchFocus = FocusNode();
  String? competitionId, fixtureKey;
  @override
  void initState() {
    super.initState();
    playerSearchFocus.addListener(_refreshPlayerSearch);
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
    playerSearch.dispose();
    playerSearchFocus
      ..removeListener(_refreshPlayerSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshPlayerSearch() {
    if (mounted) setState(() {});
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
    final selected =
        alphabetical.where((p) => teams[t].contains(p.id)).toList();
    final result = await showDialog<_FormationConfirmationResult>(
        context: context,
        builder: (context) => _FormationConfirmationDialog(
              teamName: teamName(t),
              players: selected,
              allowSavePreset: competitionId == null,
            ));
    if (!mounted || result == null) return;
    final label = result.presetName.trim();
    if (result.savePreset) {
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
    playerSearch.clear();
    playerSearchFocus.unfocus();
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
        Text(teamName(t),
            style: TextStyle(
                color: Color(colors[t]),
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _KeeperModeChip(
                  label: 'Fisso',
                  selected: modes[t] == 'fixed',
                  onTap: () => setState(() => modes[t] = 'fixed'))),
          const SizedBox(width: 8),
          Expanded(
              child: _KeeperModeChip(
                  label: 'A rotazione',
                  selected: modes[t] == 'rotation',
                  onTap: () => setState(() => modes[t] = 'rotation'))),
        ]),
        const SizedBox(height: 12),
        if (modes[t] == 'fixed')
          _SetupField(
            label: 'Portiere fisso',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  isExpanded: true,
                  value: fixed[t],
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  hint: const Text('Seleziona portiere'),
                  items: teams[t]
                      .map((id) => DropdownMenuItem(
                          value: id, child: Text(widget.league.playerName(id))))
                      .toList(),
                  onChanged: (value) => setState(() => fixed[t] = value)),
            ),
          ),
        if (modes[t] == 'rotation') ...[
          _SetupField(
            label: 'Intervallo cambio',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                  isExpanded: true,
                  value: minutes[t],
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    for (var n = 1; n <= 60; n++)
                      DropdownMenuItem(value: n, child: Text('$n minuti'))
                  ],
                  onChanged: (value) => setState(() => minutes[t] = value!)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: AccountButton('Mescola ordine portieri',
                  outline: true,
                  onPressed: () =>
                      setState(() => order[t].shuffle(Random.secure())))),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            key: ValueKey('keeper-list-$t'),
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) {
                final progress = Curves.easeOutCubic.transform(animation.value);
                return Material(
                  color: Colors.transparent,
                  shadowColor: Colors.transparent,
                  child: Transform.scale(
                    scale: 1 + (0.018 * progress),
                    child: Opacity(
                      opacity: 1 - (0.04 * progress),
                      child: child,
                    ),
                  ),
                );
              },
            ),
            itemCount: order[t].length,
            onReorderItem: (oldIndex, newIndex) => setState(() {
              final player = order[t].removeAt(oldIndex);
              order[t].insert(newIndex, player);
            }),
            itemBuilder: (context, i) {
              final id = order[t][i];
              final player =
                  widget.league.players.firstWhere((p) => p.id == id);
              return Padding(
                key: ValueKey('keeper-$t-$id'),
                padding:
                    EdgeInsets.only(bottom: i == order[t].length - 1 ? 0 : 12),
                child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: _KeeperPlayerRow(
                        player: player,
                        current: widget.league.myPlayer == id,
                        turn: i + 1)),
              );
            },
          ),
          const SizedBox(height: 12),
          _KeeperToggle(
              label: 'Suono sul telefono',
              value: sound[t],
              onChanged: (value) => setState(() => sound[t] = value)),
          const SizedBox(height: 12),
          _KeeperToggle(
              label: 'Vibrazione sul telefono',
              value: vibration[t],
              onChanged: (value) => setState(() => vibration[t] = value)),
        ],
      ]);

  void createMatch() {
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
      final match = Match(
          id: newId(),
          format: format,
          names: names.map((name) => name.text.trim()).toList(),
          teams: teams.map((team) => List<String>.from(team)).toList(),
          keepers: plans,
          creatorId: widget.league.currentUser,
          scheduledAt: scheduled.toUtc().toIso8601String(),
          venue: venue.text.trim(),
          teamColors: [...colors],
          presetIds: [...presetIds],
          competitionId: competitionId,
          knockoutRound: competition?.kind == 'knockout'
              ? fixtures.firstWhere((tie) => fixtureId(tie) == fixtureKey).round
              : null);
      validateCompetitionMatch(widget.league, match);
      Navigator.pop(context, match);
    } catch (error) {
      showError(context, error);
    }
  }

  Widget selectionBody(int t) {
    final query = playerSearch.text.trim().toLowerCase();
    final matchingPlayers = alphabetical
        .where((player) =>
            query.isEmpty || player.name.toLowerCase().contains(query))
        .toList();
    final selectablePlayers = matchingPlayers
        .where((player) => !teams[1 - t].contains(player.id))
        .toList();
    final assignedPlayers = matchingPlayers
        .where((player) => teams[1 - t].contains(player.id))
        .toList();
    final players = [
      ...selectablePlayers,
      ...assignedPlayers,
    ];
    final searchActive = playerSearchFocus.hasFocus;
    final presets = widget.league.presets
        .where((preset) =>
            !preset.archived &&
            (widget.league.type == 'competition'
                ? preset.players.length >= format
                : preset.players.length == format) &&
            (competition == null || competition!.teamIds.contains(preset.id)))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(children: [
          _SetupField(
            label: 'Preset',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  value: presetIds[t],
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  hint: const Text('Carica una squadra salvata'),
                  items: presets
                      .map((preset) => DropdownMenuItem(
                          value: preset.id, child: Text(preset.name)))
                      .toList(),
                  onChanged: presets.isEmpty
                      ? null
                      : (value) => setState(() => loadPreset(t, value!))),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text('${teams[t].length} / $format selezionati',
                    key: const ValueKey('selection-counter'),
                    style: const TextStyle(
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              height: 52,
              child: FilledButton(
                  key: const ValueKey('selection-confirm'),
                  style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(120, 52)),
                      padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                      textStyle: const WidgetStatePropertyAll(TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700))),
                  onPressed:
                      teams[t].length == format ? () => acceptTeam(t) : null,
                  child: const Text('Conferma')),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _PlayerSearchField(
                    controller: playerSearch,
                    focusNode: playerSearchFocus,
                    onChanged: (_) => setState(() {}))),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: searchActive
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 124,
                        height: 52,
                        child: AccountButton('+ Giocatore',
                            outline: true, onPressed: addPlayer),
                      ),
                    ),
            ),
          ]),
        ]),
      ),
      Expanded(
          child: ListView.builder(
              key: ValueKey('team-roster-$t'),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: players.length + (searchActive ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == players.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: players.isEmpty ? 0 : 12),
                    child: SizedBox(
                        width: double.infinity,
                        child: AccountButton('+ Giocatore',
                            outline: true, onPressed: addPlayer)),
                  );
                }
                final p = players[index];
                final other = teams[1 - t].contains(p.id),
                    selected = teams[t].contains(p.id);
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: index == players.length - 1 ? 0 : 12),
                  child: _FormationPlayerRow(
                    key: ValueKey('team-player-$t-${p.id}'),
                    player: p,
                    current: widget.league.myPlayer == p.id,
                    selected: selected,
                    disabled: other && !selected,
                    assignedTeam: other && !selected ? teamName(1 - t) : null,
                    onTap: other && !selected
                        ? null
                        : () => setState(() {
                              if (!selected && teams[t].length < format) {
                                teams[t].add(p.id);
                              } else if (selected) {
                                teams[t].remove(p.id);
                              }
                            }),
                  ),
                );
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
                        padding: const EdgeInsets.all(24),
                        children: [
                            keeperSettings(0),
                            const SizedBox(height: 24),
                            keeperSettings(1),
                            const SizedBox(height: 12),
                            AccountButton('Crea partita',
                                onPressed: createMatch),
                          ])));
  }
}

class _PlayerSearchField extends StatelessWidget {
  const _PlayerSearchField(
      {required this.controller,
      required this.focusNode,
      required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        height: 52,
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: focusNode.hasFocus
                    ? HaykoColors.chalk
                    : HaykoColors.fieldLine)),
        child: TextField(
          key: const ValueKey('player-search'),
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16, height: 1.5),
          decoration: const InputDecoration(
              isDense: true,
              hintText: 'Cerca giocatore',
              prefixIcon: Icon(Icons.search, size: 22),
              prefixIconConstraints:
                  BoxConstraints(minWidth: 44, minHeight: 52),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14)),
        ),
      );
}

class _KeeperModeChip extends StatelessWidget {
  const _KeeperModeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? HaykoColors.fieldLine : HaykoColors.fieldBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HaykoColors.fieldLine)),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, height: 1.5, fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _KeeperPlayerRow extends StatelessWidget {
  const _KeeperPlayerRow(
      {required this.player, required this.current, required this.turn});
  final Player player;
  final bool current;
  final int turn;

  String get initials {
    final words = player.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: Color(player.color),
              child: Text(initials,
                  style: TextStyle(
                      color: contrastColor(player.color),
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${player.name}${current ? ' · Tu' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                  Text('Turno $turn',
                      style: const TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
                ]),
          ),
          const SizedBox(
              width: 64,
              child:
                  Icon(Icons.drag_handle, size: 24, color: HaykoColors.chalk)),
        ]),
      );
}

class _KeeperToggle extends StatelessWidget {
  const _KeeperToggle(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 16, height: 1.5))),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

class _FormationConfirmationResult {
  const _FormationConfirmationResult(this.savePreset, this.presetName);
  final bool savePreset;
  final String presetName;
}

class _FormationConfirmationDialog extends StatefulWidget {
  const _FormationConfirmationDialog(
      {required this.teamName,
      required this.players,
      required this.allowSavePreset});

  final String teamName;
  final List<Player> players;
  final bool allowSavePreset;

  @override
  State<_FormationConfirmationDialog> createState() =>
      _FormationConfirmationDialogState();
}

class _FormationConfirmationDialogState
    extends State<_FormationConfirmationDialog> {
  late final TextEditingController presetName;
  bool savePreset = false;

  @override
  void initState() {
    super.initState();
    presetName = TextEditingController(text: widget.teamName);
  }

  @override
  void dispose() {
    presetName.dispose();
    super.dispose();
  }

  String initials(Player player) {
    final words = player.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 342, maxHeight: 720),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: HaykoColors.fieldSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaykoColors.fieldLine)),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Formazione ${widget.teamName}',
                      style: const TextStyle(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Controlla i giocatori prima di confermare.',
                      style: TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final player = widget.players[index];
                        return Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                              color: HaykoColors.fieldBackground,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(player.color),
                                child: Text(initials(player),
                                    style: TextStyle(
                                        color: contrastColor(player.color),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(player.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16, height: 1.5))),
                            const Text('✓',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ]),
                        );
                      },
                    ),
                  ),
                  if (widget.allowSavePreset) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: HaykoColors.fieldBackground,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => savePreset = !savePreset),
                        child: SizedBox(
                          height: 56,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(children: [
                              const Expanded(
                                  child: Text('Salva come squadra',
                                      style: TextStyle(
                                          fontSize: 16, height: 1.5))),
                              Checkbox(
                                  value: savePreset,
                                  onChanged: (value) => setState(
                                      () => savePreset = value ?? false)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    if (savePreset) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 76,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: HaykoColors.fieldBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: HaykoColors.fieldLine)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nome squadra',
                                  style: TextStyle(
                                      color: HaykoColors.mutedText,
                                      fontSize: 12,
                                      height: 16 / 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: presetName,
                                    maxLength: 60,
                                    style: const TextStyle(
                                        fontSize: 16, height: 1.5),
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
                    ],
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AccountButton('Conferma',
                        onPressed: () => Navigator.pop(
                            context,
                            _FormationConfirmationResult(
                                savePreset, presetName.text))),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: AccountButton('Modifica',
                        outline: true, onPressed: () => Navigator.pop(context)),
                  ),
                ]),
          ),
        ),
      );
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

class _FormationPlayerRow extends StatelessWidget {
  const _FormationPlayerRow(
      {super.key,
      required this.player,
      required this.current,
      required this.selected,
      required this.disabled,
      required this.assignedTeam,
      required this.onTap});

  final Player player;
  final bool current;
  final bool selected;
  final bool disabled;
  final String? assignedTeam;
  final VoidCallback? onTap;

  String get initials {
    final words = player.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Material(
          color: selected ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 72,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(color: HaykoColors.chalk, width: 2)
                      : null),
              child: Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(player.color),
                    child: Text(initials,
                        style: TextStyle(
                            color: contrastColor(player.color),
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${player.name}${current ? ' · Tu' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, height: 1.5)),
                        Text(
                            selected
                                ? 'Selezionato'
                                : assignedTeam == null
                                    ? 'Disponibile'
                                    : 'Già in $assignedTeam',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
                SizedBox(
                    width: 64,
                    child: Text(selected ? '✓' : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        ),
      );
}
