import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelMatchCreationPage extends StatefulWidget {
  const PadelMatchCreationPage(
      {super.key, required this.league, required this.save});

  final League league;
  final Save save;

  @override
  State<PadelMatchCreationPage> createState() => _PadelMatchCreationPageState();
}

class _PadelMatchCreationPageState extends State<PadelMatchCreationPage> {
  int step = 0;
  int bestOf = 3;
  String gameRule = 'golden_point';
  String decidingSet = 'super_tiebreak_10';
  final colors = <int>[0xff63c7f2, 0xffff7a3d];
  final teams = <Set<String>>[<String>{}, <String>{}];
  final presetIds = <String?>[null, null];
  late DateTime scheduled;
  final venue = TextEditingController();
  final search = TextEditingController();
  final searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    scheduled = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    searchFocus.addListener(_refresh);
  }

  @override
  void dispose() {
    venue.dispose();
    search.dispose();
    searchFocus
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Player> get alphabetical => [...widget.league.players]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  String formulaLabel(int value) => 'Meglio di $value set';
  String gameRuleLabel(String value) =>
      value == 'advantages' ? 'Vantaggi' : 'Golden Point';
  String decidingSetLabel(String value) => value == 'full_set'
      ? 'Set completo'
      : value == 'tiebreak_7'
          ? 'Tie-break a 7'
          : 'Super tie-break a 10';

  String colorLabel(int value) {
    if (value == 0xff63c7f2) return 'Blu';
    if (value == 0xffff7a3d) return 'Arancio';
    if (value == 0xffe3f24a) return 'Lime';
    if (value == 0xffbbf568) return 'Verde';
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String teamTitle(int team) =>
      'Coppia ${team == 0 ? 'A' : 'B'} · ${colorLabel(colors[team])}';

  String teamPlayers(int team) => teams[team]
      .map((id) => widget.league.playerName(id))
      .toList()
      .join(' · ');

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

  Future<void> pickScheduled() async {
    final date = await showDatePicker(
        context: context,
        initialDate: scheduled,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time =
        await chooseHaykoTime(context, TimeOfDay.fromDateTime(scheduled));
    if (time == null || !mounted) return;
    setState(() => scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> pickTeamColor(int team) async {
    final value = await chooseColor(context, colors[team]);
    if (value != null && mounted) setState(() => colors[team] = value);
  }

  Future<void> addPlayer() async {
    await addLeaguePlayer(context, widget.league, widget.save);
    if (mounted) setState(() {});
  }

  void selectPreset(int team, String? id) {
    setState(() {
      presetIds[team] = id;
      teams[team].clear();
      if (id == null) return;
      final preset = widget.league.presets.firstWhere((item) => item.id == id);
      teams[team].addAll(preset.players.take(2));
      colors[team] = preset.color;
    });
  }

  void continueFromSetup() {
    if (hasAmateurScheduleConflict(widget.league, scheduled)) {
      showError(context,
          'Esiste già una partita programmata nello stesso giorno e orario.');
      return;
    }
    if (widget.league.players.length < 4) {
      showError(context, 'Servono almeno quattro giocatori nella lega.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => step = 1);
  }

  void confirmTeam(int team) {
    if (teams[team].length != 2) return;
    search.clear();
    searchFocus.unfocus();
    setState(() => step = team == 0 ? 2 : 3);
  }

  void createMatch() {
    if (hasAmateurScheduleConflict(widget.league, scheduled)) {
      showError(context,
          'Esiste già una partita programmata nello stesso giorno e orario.');
      return;
    }
    final match = Match(
        id: newId(),
        format: 2,
        names: ['Coppia A', 'Coppia B'],
        teams: [teams[0].toList(), teams[1].toList()],
        keepers: [KeeperPlan.none(), KeeperPlan.none()],
        creatorId: widget.league.currentUser,
        scheduledAt: scheduled.toUtc().toIso8601String(),
        venue: venue.text.trim(),
        teamColors: [...colors],
        presetIds: [...presetIds],
        padelBestOf: bestOf,
        padelGameRule: gameRule,
        padelDecidingSet: decidingSet);
    Navigator.pop(context, match);
  }

  Widget setupBody() => ListView(
        key: const ValueKey('padel-match-setup'),
        padding: const EdgeInsets.all(24),
        children: [
          _PadelDropdownField<int>(
              label: 'Formula partita',
              value: bestOf,
              items: const [3, 5],
              itemLabel: formulaLabel,
              onChanged: (value) => setState(() => bestOf = value)),
          const SizedBox(height: 10),
          _PadelDropdownField<String>(
              label: 'Punteggio game',
              value: gameRule,
              items: const ['golden_point', 'advantages'],
              itemLabel: gameRuleLabel,
              onChanged: (value) => setState(() => gameRule = value)),
          const SizedBox(height: 10),
          _PadelDropdownField<String>(
              label: 'Set decisivo',
              value: decidingSet,
              items: const ['super_tiebreak_10', 'tiebreak_7', 'full_set'],
              itemLabel: decidingSetLabel,
              onChanged: (value) => setState(() => decidingSet = value)),
          const SizedBox(height: 10),
          for (var team = 0; team < 2; team++) ...[
            _PadelColorField(
                label: 'Coppia ${team == 0 ? 'A' : 'B'}',
                value: colorLabel(colors[team]),
                color: colors[team],
                onTap: () => pickTeamColor(team)),
            const SizedBox(height: 10),
          ],
          _PadelField(
              label: 'Data e ora', value: scheduledLabel, onTap: pickScheduled),
          const SizedBox(height: 10),
          _PadelTextField(
              label: 'Campo · facoltativo',
              controller: venue,
              hint: 'Inserisci il campo'),
          const SizedBox(height: 10),
          AccountButton('Seleziona coppie', onPressed: continueFromSetup),
        ],
      );

  Widget selectionBody(int team) {
    final query = search.text.trim().toLowerCase();
    final matching = alphabetical
        .where((player) =>
            query.isEmpty || player.name.toLowerCase().contains(query))
        .toList();
    final available = matching
        .where((player) => !teams[1 - team].contains(player.id))
        .toList();
    final assigned = matching
        .where((player) => teams[1 - team].contains(player.id))
        .toList();
    final players = [...available, ...assigned];
    final presets = widget.league.presets
        .where((preset) => !preset.archived && preset.players.length == 2)
        .where((preset) =>
            preset.players.every((id) => !teams[1 - team].contains(id)))
        .toList();
    final searchActive = searchFocus.hasFocus;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        child: Column(children: [
          _PadelDropdownField<String?>(
              label: 'Coppia salvata',
              value: presetIds[team],
              items: <String?>[null, ...presets.map((preset) => preset.id)],
              itemLabel: (id) => id == null
                  ? 'Carica una coppia salvata'
                  : presets.firstWhere((preset) => preset.id == id).name,
              onChanged: (value) => selectPreset(team, value)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Text('${teams[team].length} / 2 selezionati',
                    key: const ValueKey('padel-selection-counter'),
                    style: const TextStyle(
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            SizedBox(
                width: 120,
                height: 52,
                child: FilledButton(
                    key: const ValueKey('padel-selection-confirm'),
                    onPressed: teams[team].length == 2
                        ? () => confirmTeam(team)
                        : null,
                    child: const Text('Conferma'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _PadelSearchField(
                    controller: search,
                    focusNode: searchFocus,
                    onChanged: (_) => setState(() {}))),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: searchActive
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                          width: 120,
                          height: 52,
                          child: AccountButton('+ Giocatore',
                              outline: true, onPressed: addPlayer))),
            )
          ])
        ]),
      ),
      Expanded(
          child: ListView.builder(
              key: ValueKey('padel-team-roster-$team'),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: players.length + (searchActive ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == players.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: players.isEmpty ? 0 : 10),
                    child: AccountButton('+ Giocatore',
                        outline: true, onPressed: addPlayer),
                  );
                }
                final player = players[index];
                final other = teams[1 - team].contains(player.id);
                final selected = teams[team].contains(player.id);
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: index == players.length - 1 ? 0 : 10),
                  child: _PadelSelectionRow(
                      player: player,
                      current: widget.league.myPlayer == player.id,
                      selected: selected,
                      disabled: other,
                      disabledLabel: other
                          ? 'Già nella coppia ${team == 0 ? 'B' : 'A'}'
                          : null,
                      onTap: other
                          ? null
                          : () => setState(() {
                                if (selected) {
                                  teams[team].remove(player.id);
                                  presetIds[team] = null;
                                } else if (teams[team].length < 2) {
                                  teams[team].add(player.id);
                                  presetIds[team] = null;
                                }
                              })),
                );
              }))
    ]);
  }

  Widget summaryBody() => ListView(
        key: const ValueKey('padel-match-summary'),
        padding: const EdgeInsets.all(24),
        children: [
          _PadelField(label: 'Formula partita', value: formulaLabel(bestOf)),
          const SizedBox(height: 10),
          _PadelField(label: 'Punteggio game', value: gameRuleLabel(gameRule)),
          const SizedBox(height: 10),
          _PadelField(
              label: 'Set decisivo', value: decidingSetLabel(decidingSet)),
          const SizedBox(height: 10),
          for (var team = 0; team < 2; team++) ...[
            _PadelColorField(
                label: teamTitle(team),
                value: teamPlayers(team),
                color: colors[team]),
            const SizedBox(height: 10),
          ],
          _PadelField(label: 'Data e ora', value: scheduledLabel),
          const SizedBox(height: 10),
          _PadelField(
              label: 'Campo · facoltativo',
              value: venue.text.trim().isEmpty
                  ? 'Non indicato'
                  : venue.text.trim()),
          const SizedBox(height: 10),
          AccountButton('Programma partita', onPressed: createMatch),
        ],
      );

  void goBack() {
    if (step == 0) {
      Navigator.pop(context);
      return;
    }
    search.clear();
    searchFocus.unfocus();
    setState(() => step--);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          centerTitle: false,
          leading:
              IconButton(onPressed: goBack, icon: const Icon(Icons.arrow_back)),
          title: Text(step == 0
              ? 'Nuova partita'
              : step == 1
                  ? teamTitle(0)
                  : step == 2
                      ? teamTitle(1)
                      : 'Riepilogo partita'),
        ),
        body: step == 0
            ? setupBody()
            : step == 1 || step == 2
                ? selectionBody(step - 1)
                : summaryBody(),
      );
}

class _PadelField extends StatelessWidget {
  const _PadelField({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: HaykoColors.padelAccent.withValues(alpha: .36))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        maxLines: 1,
                        style: const TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.5)),
                  ]),
            ),
          ),
        ),
      );
}

class _PadelColorField extends StatelessWidget {
  const _PadelColorField(
      {required this.label,
      required this.value,
      required this.color,
      this.onTap});
  final String label;
  final String value;
  final int color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: HaykoColors.padelAccent.withValues(alpha: .36))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label,
                          maxLines: 1,
                          style: const TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, height: 1.5)),
                    ])),
                CircleAvatar(radius: 18, backgroundColor: Color(color)),
              ]),
            ),
          ),
        ),
      );
}

class _PadelDropdownField<T> extends StatelessWidget {
  const _PadelDropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.itemLabel,
      required this.onChanged});
  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: HaykoColors.padelAccent.withValues(alpha: .36))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600)),
              SizedBox(
                height: 32,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                      value: value,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      items: items
                          .map((item) => DropdownMenuItem<T>(
                              value: item, child: Text(itemLabel(item))))
                          .toList(),
                      onChanged: (item) {
                        if (item != null || items.contains(null)) {
                          onChanged(item as T);
                        }
                      }),
                ),
              ),
            ]),
      );
}

class _PadelTextField extends StatelessWidget {
  const _PadelTextField(
      {required this.label, required this.controller, required this.hint});
  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: HaykoColors.padelAccent.withValues(alpha: .36))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600)),
              SizedBox(
                height: 32,
                child: TextField(
                  controller: controller,
                  maxLength: 120,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                      hintText: hint,
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero),
                ),
              ),
            ]),
      );
}

class _PadelSearchField extends StatelessWidget {
  const _PadelSearchField(
      {required this.controller,
      required this.focusNode,
      required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: HaykoColors.padelAccent.withValues(alpha: .5))),
        child: Row(children: [
          const Icon(Icons.search, size: 22, color: HaykoColors.mutedText),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: const InputDecoration(
                hintText: 'Cerca giocatore',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none),
          )),
        ]),
      );
}

class _PadelSelectionRow extends StatelessWidget {
  const _PadelSelectionRow(
      {required this.player,
      required this.current,
      required this.selected,
      required this.disabled,
      required this.disabledLabel,
      required this.onTap});
  final Player player;
  final bool current;
  final bool selected;
  final bool disabled;
  final String? disabledLabel;
  final VoidCallback? onTap;

  String get initials => player.name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: disabled ? .48 : 1,
        child: Material(
          color: selected ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: selected
                  ? const BorderSide(color: HaykoColors.padelAccent)
                  : BorderSide.none),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(player.color),
                      child: Text(initials,
                          style: TextStyle(
                              color: contrastColor(player.color),
                              fontSize: 12,
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
                            disabledLabel ??
                                (selected ? 'Selezionato' : 'Disponibile'),
                            style: const TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w600)),
                      ])),
                  SizedBox(
                      width: 64,
                      child: selected
                          ? const Text('✓',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.w600))
                          : null),
                ]),
              ),
            ),
          ),
        ),
      );
}
