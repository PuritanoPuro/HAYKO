import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/competitions/competition_roster_editor.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

Future<Player?> addLeaguePlayer(
    BuildContext context, League l, Save? save) async {
  var name = '';
  var color = l.primaryColor;
  final player = await showDialog<Player>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
                  title: const Text('Aggiungi giocatore'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        maxLength: 60,
                        decoration:
                            const InputDecoration(labelText: 'Nome giocatore'),
                        onChanged: (v) => name = v),
                    ColorChoice(
                        label: 'Colore giocatore',
                        color: color,
                        changed: (v) => set(() => color = v)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Annulla')),
                    FilledButton(
                        onPressed: () {
                          final value = name.trim();
                          if (value.isEmpty ||
                              l.players.any((p) =>
                                  p.name.toLowerCase() ==
                                  value.toLowerCase())) {
                            showError(
                                c, 'Inserisci un nome nuovo e non vuoto.');
                            return;
                          }
                          Navigator.pop(
                              c, Player(newId(), value, color: color));
                        },
                        child: const Text('Aggiungi'))
                  ])));
  if (player == null) return null;
  l.players.add(player);
  try {
    await save?.call();
    return player;
  } catch (e) {
    l.players.remove(player);
    if (context.mounted) showError(context, e);
    return null;
  }
}

class TeamEditor extends StatefulWidget {
  final League league;
  final Save save;
  final int? initialFormat;
  final TeamPreset? team;
  final Competition? competition;
  const TeamEditor(
      {super.key,
      required this.league,
      required this.save,
      this.initialFormat,
      this.team,
      this.competition});
  @override
  State<TeamEditor> createState() => _TeamEditorState();
}

class _TeamEditorState extends State<TeamEditor> {
  String name = '';
  int color = 0xff8ebcff, format = 5;
  bool busy = false;
  final selected = <String>[];
  final numbers = <String, int>{};
  bool get competitive => widget.league.type == 'competition';
  @override
  void initState() {
    super.initState();
    format = widget.initialFormat ?? 5;
    color = widget.league.primaryColor;
    if (widget.team != null) {
      name = widget.team!.name;
      color = widget.team!.color;
      selected.addAll(widget.team!.players);
      numbers.addAll(widget.team!.numbers);
      for (final id in selected) {
        if (!numbers.containsKey(id)) {
          var n = 1;
          while (numbers.values.contains(n) && n < 99) {
            n++;
          }
          numbers[id] = n;
        }
      }
    }
  }

  Future<void> add() async {
    if (!competitive && selected.length >= format) {
      showError(context, 'La squadra ha già $format giocatori.');
      return;
    }
    setState(() => busy = true);
    final player = await addLeaguePlayer(context, widget.league, widget.save);
    if (mounted) {
      setState(() {
        if (player != null && !selected.contains(player.id)) {
          selected.add(player.id);
        }
        busy = false;
      });
    }
  }

  Future<void> submit() async {
    final l = widget.league;
    if (name.trim().isEmpty ||
        l.presets.any((p) =>
            !p.archived &&
            p.id != widget.team?.id &&
            p.name.toLowerCase() == name.trim().toLowerCase())) {
      showError(context, 'Inserisci un nome di squadra nuovo e non vuoto.');
      return;
    }
    if (competitive &&
        (selected.any((id) => !numbers.containsKey(id)) ||
            numbers.values.toSet().length != selected.length)) {
      showError(
          context, 'Assegna un numero di maglia diverso a ogni giocatore.');
      return;
    }
    final team = TeamPreset(
        widget.team?.id ?? newId(), name.trim(), [...selected],
        color: color, numbers: Map<String, int>.from(numbers));
    final index = widget.team == null ? -1 : l.presets.indexOf(widget.team!);
    final before = widget.team;
    setState(() => busy = true);
    if (index < 0) {
      l.presets.add(team);
    } else {
      l.presets[index] = team;
    }
    final enrolled = widget.competition != null &&
        !widget.competition!.teamIds.contains(team.id);
    if (enrolled) widget.competition!.teamIds.add(team.id);
    try {
      await widget.save();
      if (mounted) Navigator.pop(context, team);
    } catch (e) {
      if (index < 0) {
        l.presets.remove(team);
      } else {
        l.presets[index] = before!;
      }
      if (enrolled) widget.competition!.teamIds.remove(team.id);
      if (mounted) {
        showError(context, e);
        setState(() => busy = false);
      }
    }
  }

  Future<void> removeTeam() async {
    final team = widget.team;
    if (team == null) return;
    if (widget.league.competitions
        .any((competition) => competition.teamIds.contains(team.id))) {
      showError(context,
          'La squadra partecipa a una competizione e non può essere eliminata.');
      return;
    }
    if (!await confirm(context, 'Eliminare ${team.name}?',
        'La squadra non sarà più selezionabile. Le partite e le statistiche già registrate resteranno conservate.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    team.archived = true;
    try {
      await widget.save();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      team.archived = false;
      if (mounted) {
        showError(context, error);
        setState(() => busy = false);
      }
    }
  }

  Future<void> number(String id) async {
    var value = '${numbers[id] ?? 1}';
    final result = await showDialog<int>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('Numero di ${widget.league.playerName(id)}'),
                content: TextFormField(
                    initialValue: value,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    onChanged: (v) => value = v),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Annulla')),
                  FilledButton(
                      onPressed: () {
                        final n = int.tryParse(value);
                        if (n == null ||
                            n < 0 ||
                            n > 99 ||
                            numbers.entries
                                .any((e) => e.key != id && e.value == n)) {
                          showError(c, 'Scegli un numero libero da 0 a 99.');
                          return;
                        }
                        Navigator.pop(c, n);
                      },
                      child: const Text('Salva'))
                ]));
    if (mounted && result != null) setState(() => numbers[id] = result);
  }

  void select(Player p, bool value) {
    if (value &&
        ((competitive && selected.length < 60) ||
            (!competitive && selected.length < format))) {
      selected.add(p.id);
      var n = 1;
      while (numbers.values.contains(n) && n < 99) {
        n++;
      }
      numbers[p.id] = n;
    } else if (!value) {
      selected.remove(p.id);
      numbers.remove(p.id);
    }
  }

  Widget teamNameField() => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HaykoColors.fieldLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nome squadra',
              style: TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: TextFormField(
                initialValue: name,
                maxLength: 60,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero),
                onChanged: (value) => name = value),
          ),
        ]),
      );

  Widget formatField() => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HaykoColors.fieldLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tipologia partita',
              style: TextStyle(
                  color: HaykoColors.mutedText,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                  isExpanded: true,
                  value: format,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    for (var value = 2; value <= 11; value++)
                      DropdownMenuItem(
                          value: value, child: Text('${value}v$value'))
                  ],
                  onChanged: busy || widget.initialFormat != null
                      ? null
                      : (value) => setState(() {
                            format = value!;
                            selected.clear();
                          })),
            ),
          ),
        ]),
      );

  Widget colorField() => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: busy
              ? null
              : () async {
                  final value = await chooseColor(context, color);
                  if (value != null && mounted) setState(() => color = value);
                },
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
                        const Text('Colore squadra',
                            style: TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                            style: const TextStyle(fontSize: 16, height: 1.5)),
                      ]),
                ),
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Color(color), shape: BoxShape.circle)),
              ]),
            ),
          ),
        ),
      );

  Widget savedTeamEditor(List<Player> players) {
    final members = players.where((player) => selected.contains(player.id));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        teamNameField(),
        const SizedBox(height: 12),
        formatField(),
        const SizedBox(height: 12),
        colorField(),
        const SizedBox(height: 12),
        AccountButton('+ Giocatore',
            outline: true, onPressed: busy ? null : add),
        const SizedBox(height: 12),
        for (final player in members) ...[
          _TeamMemberRow(
              player: player,
              current: widget.league.myPlayer == player.id,
              onRemove:
                  busy ? null : () => setState(() => select(player, false))),
          const SizedBox(height: 12),
        ],
        AccountButton('Salva squadra',
            onPressed: busy || selected.length != format ? null : submit),
        const SizedBox(height: 12),
        _DangerButton(
            label: 'Elimina squadra', onPressed: busy ? null : removeTeam),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (competitive) {
      return CompetitionRosterEditor(
          league: widget.league,
          save: widget.save,
          team: widget.team,
          competition: widget.competition);
    }
    final players = [...widget.league.players]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 64,
            title: Text(
                widget.team == null ? 'Nuova squadra' : 'Modifica squadra',
                style: const TextStyle(
                    fontSize: 20, height: 1.3, fontWeight: FontWeight.w700))),
        body: widget.team != null
            ? savedTeamEditor(players)
            : Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      TextFormField(
                          initialValue: name,
                          maxLength: 60,
                          decoration:
                              const InputDecoration(labelText: 'Nome squadra'),
                          onChanged: (v) => name = v),
                      ColorChoice(
                          label: 'Colore squadra',
                          color: color,
                          changed: (v) => setState(() => color = v)),
                      DropdownButton<int>(
                          isExpanded: true,
                          value: format,
                          items: [
                            for (var n = 2; n <= 11; n++)
                              DropdownMenuItem(
                                  value: n, child: Text('$n giocatori'))
                          ],
                          onChanged: busy || widget.initialFormat != null
                              ? null
                              : (v) => setState(() {
                                    format = v!;
                                    selected.clear();
                                  })),
                      Row(children: [
                        Expanded(
                            child: Text(competitive
                                ? '${selected.length} giocatori · minimo $format'
                                : '${selected.length} / $format selezionati')),
                        FilledButton(
                            onPressed: busy ||
                                    (competitive
                                        ? selected.length < format
                                        : selected.length != format)
                                ? null
                                : submit,
                            child: const Text('Salva squadra'))
                      ]),
                      TextButton.icon(
                          onPressed: busy ? null : add,
                          icon: const Icon(Icons.person_add),
                          label: const Text('+ Giocatore')),
                    ])),
                Expanded(
                    child: ListView(
                        children: players
                            .map((p) => Card(
                                color: selected.contains(p.id)
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                                child: Row(children: [
                                  Expanded(
                                      child: CheckboxListTile(
                                          title: Text(p.name),
                                          secondary: CircleAvatar(
                                              radius: 9,
                                              backgroundColor: Color(p.color)),
                                          value: selected.contains(p.id),
                                          onChanged: busy
                                              ? null
                                              : (v) => setState(
                                                  () => select(p, v!)))),
                                  if (competitive && selected.contains(p.id))
                                    TextButton(
                                        onPressed:
                                            busy ? null : () => number(p.id),
                                        child:
                                            Text('#${numbers[p.id] ?? '—'}')),
                                ])))
                            .toList())),
              ]));
  }
}

class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow(
      {required this.player, required this.current, required this.onRemove});
  final Player player;
  final bool current;
  final VoidCallback? onRemove;

  String get initials {
    final words = player.name.trim().split(RegExp(r'\s+'));
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: current ? Border.all(color: HaykoColors.chalk) : null),
        child: Row(children: [
          Expanded(
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
                        const Text('Nella squadra',
                            style: TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ]),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
                tooltip: 'Rimuovi dalla squadra',
                onPressed: onRemove,
                color: const Color(0xffffb4ab),
                icon: const Icon(Icons.delete, size: 24)),
          ),
        ]),
      );
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xffffb4ab),
              backgroundColor: HaykoColors.fieldSurface,
              side: const BorderSide(color: Color(0xffffb4ab)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontFamily: 'BricolageGrotesque',
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700)),
          child: Text(label),
        ),
      );
}
