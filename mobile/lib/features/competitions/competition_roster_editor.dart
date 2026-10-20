import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

class RosterEntry {
  final String id;
  final String name;
  final int number;
  RosterEntry(this.id, this.name, this.number);
}

class CompetitionRosterEditor extends StatefulWidget {
  final League league;
  final Save save;
  final TeamPreset? team;
  final Competition? competition;
  const CompetitionRosterEditor(
      {super.key,
      required this.league,
      required this.save,
      this.team,
      this.competition});
  @override
  State<CompetitionRosterEditor> createState() =>
      _CompetitionRosterEditorState();
}

class _CompetitionRosterEditorState extends State<CompetitionRosterEditor> {
  String name = '';
  int color = 0xff8ebcff;
  bool busy = false;
  final roster = <RosterEntry>[];
  @override
  void initState() {
    super.initState();
    name = widget.team?.name ?? '';
    color = widget.team?.color ?? widget.league.primaryColor;
    if (widget.team != null) {
      for (final id in widget.team!.players) {
        var number = widget.team!.numbers[id] ?? 1;
        while (roster.any((p) => p.number == number)) {
          number++;
        }
        roster.add(RosterEntry(id, widget.league.playerName(id), number));
      }
    }
  }

  Future<void> player([RosterEntry? entry]) async {
    if (busy || (entry == null && roster.length >= 60)) return;
    if (entry == null) {
      final result = await Navigator.push<RosterEntry>(
        context,
        MaterialPageRoute(
          builder: (_) => _CompetitionPlayerEditor(
            teamName: name.trim().isEmpty ? 'Nuova squadra' : name.trim(),
            roster: List.unmodifiable(roster),
          ),
        ),
      );
      if (!mounted || result == null) return;
      setState(() => roster.add(result));
      return;
    }
    final result = await Navigator.push<RosterEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => _CompetitionPlayerEditor(
          teamName: name.trim().isEmpty ? 'Squadra' : name.trim(),
          roster: List.unmodifiable(roster),
          initialEntry: entry,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.number == -1) {
      await remove(entry);
      return;
    }
    setState(() => roster[roster.indexOf(entry)] = result);
  }

  Widget teamField() => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Squadra',
                    style: TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: TextFormField(
                    key: const ValueKey('competition-team-name'),
                    initialValue: name,
                    maxLength: 60,
                    style: const TextStyle(fontSize: 16, height: 24 / 16),
                    decoration: const InputDecoration(
                      hintText: 'Nome squadra',
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (value) => name = value,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Cambia colore squadra',
            child: InkWell(
              key: const ValueKey('competition-team-color'),
              customBorder: const CircleBorder(),
              onTap: busy
                  ? null
                  : () async {
                      final value = await chooseColor(context, color);
                      if (value != null && mounted) {
                        setState(() => color = value);
                      }
                    },
              child: Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: Color(color), shape: BoxShape.circle),
              ),
            ),
          ),
        ]),
      );

  Widget rosterRow(RosterEntry entry) {
    final current = widget.league.myPlayer == entry.id;
    return Container(
      key: ValueKey('competition-roster-${entry.id}'),
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        border: current ? Border.all(color: HaykoColors.chalk) : null,
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color(color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('${entry.number}',
              style: TextStyle(
                  color: contrastColor(color),
                  fontSize: 24,
                  height: 28 / 24,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('${entry.name}${current ? ' · Tu' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, height: 24 / 16)),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: 'Modifica giocatore',
            onPressed: busy ? null : () => player(entry),
            icon: const Icon(Icons.edit, size: 24),
          ),
        ),
      ]),
    );
  }

  Future<void> remove(RosterEntry p) async {
    if (await confirm(context, 'Rimuovere ${p.name}?',
        'Verrà rimosso dalla rosa. I risultati delle partite già iniziate resteranno conservati.')) {
      if (mounted) setState(() => roster.remove(p));
    }
  }

  Future<void> submit() async {
    final l = widget.league;
    if (name.trim().isEmpty ||
        l.presets.any((p) =>
            p.id != widget.team?.id &&
            p.name.toLowerCase() == name.trim().toLowerCase())) {
      showError(context, 'Inserisci un nome di squadra nuovo e non vuoto.');
      return;
    }
    final team = TeamPreset(widget.team?.id ?? newId(), name.trim(),
        roster.map((p) => p.id).toList(),
        color: color, numbers: {for (final p in roster) p.id: p.number});
    final beforePlayers = [...l.players],
        oldDetails = {
          for (final p in l.players) p.id: [p.name, p.color]
        };
    final index = widget.team == null ? -1 : l.presets.indexOf(widget.team!);
    final c = widget.competition;
    final enrolled = c != null && !c.teamIds.contains(team.id);
    final snapshots = <Match, Map<String, dynamic>>{};
    setState(() => busy = true);
    for (final entry in roster) {
      final existing = l.players.where((p) => p.id == entry.id);
      if (existing.isEmpty) {
        l.players.add(Player(entry.id, entry.name, color: color));
      } else {
        existing.first.name = entry.name;
        existing.first.color = color;
      }
    }
    if (index < 0) {
      l.presets.add(team);
    } else {
      l.presets[index] = team;
    }
    if (c != null && enrolled) c.teamIds.add(team.id);
    // Aggiorna le partite programmate, conserva le rose delle partite iniziate.
    for (final m in l.matches.where((m) =>
        m.competitionRules &&
        m.status == 'scheduled' &&
        l.canRecord(m) &&
        m.presetIds.contains(team.id))) {
      final side = m.presetIds.indexOf(team.id),
          other = m.teams[1 - m.presetIds.indexOf(team.id)];
      if (team.players.length < m.format || team.players.any(other.contains)) {
        continue;
      }
      snapshots[m] = Match.fromJson(m.toJson()).toJson();
      m.teams[side] = [...team.players];
      m.names[side] = team.name;
      m.teamColors[side] = team.color;
    }
    try {
      await widget.save();
      if (mounted) Navigator.pop(context, team);
    } catch (e) {
      l.players
        ..clear()
        ..addAll(beforePlayers);
      for (final p in l.players) {
        p.name = oldDetails[p.id]![0] as String;
        p.color = oldDetails[p.id]![1] as int;
      }
      if (index < 0) {
        l.presets.remove(team);
      } else {
        l.presets[index] = widget.team!;
      }
      if (c != null && enrolled) c.teamIds.remove(team.id);
      for (final entry in snapshots.entries) {
        final old = Match.fromJson(entry.value);
        entry.key.teams[0] = old.teams[0];
        entry.key.teams[1] = old.teams[1];
        entry.key.names
          ..clear()
          ..addAll(old.names);
        entry.key.teamColors
          ..clear()
          ..addAll(old.teamColors);
      }
      if (mounted) {
        showError(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          toolbarHeight: 64,
          title:
              Text(widget.team == null ? 'Nuova squadra' : 'Modifica squadra')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          teamField(),
          const SizedBox(height: 12),
          AccountButton('+ Giocatore',
              outline: true, onPressed: busy ? null : () => player()),
          const SizedBox(height: 12),
          for (var index = 0; index < roster.length; index++) ...[
            rosterRow(roster[index]),
            const SizedBox(height: 12),
          ],
          AccountButton('Salva squadra', onPressed: busy ? null : submit),
        ],
      ));
}

class _CompetitionPlayerEditor extends StatefulWidget {
  final String teamName;
  final List<RosterEntry> roster;
  final RosterEntry? initialEntry;

  const _CompetitionPlayerEditor({
    required this.teamName,
    required this.roster,
    this.initialEntry,
  });

  @override
  State<_CompetitionPlayerEditor> createState() =>
      _CompetitionPlayerEditorState();
}

class _CompetitionPlayerEditorState extends State<_CompetitionPlayerEditor> {
  final nameController = TextEditingController();
  late final TextEditingController numberController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntry;
    if (initial != null) {
      nameController.text = initial.name;
      numberController = TextEditingController(text: '${initial.number}');
      return;
    }
    var next = 1;
    while (widget.roster.any((player) => player.number == next)) {
      next++;
    }
    numberController = TextEditingController(text: '$next');
  }

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }

  void submit() {
    final name = nameController.text.trim();
    final number = int.tryParse(numberController.text);
    final duplicate = widget.roster.any((player) =>
        player.id != widget.initialEntry?.id &&
        (player.number == number ||
            player.name.toLowerCase() == name.toLowerCase()));
    if (name.isEmpty ||
        number == null ||
        number < 0 ||
        number > 99 ||
        duplicate) {
      showError(context,
          'Inserisci nome e numero da 0 a 99, diversi dagli altri giocatori della squadra.');
      return;
    }
    Navigator.pop(
        context, RosterEntry(widget.initialEntry?.id ?? newId(), name, number));
  }

  Widget field({
    required String label,
    TextEditingController? controller,
    String? value,
    Key? fieldKey,
    TextInputType? keyboardType,
    int? maxLength,
  }) =>
      Container(
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
              child: controller == null
                  ? Text(value ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, height: 24 / 16))
                  : TextField(
                      key: fieldKey,
                      controller: controller,
                      keyboardType: keyboardType,
                      maxLength: maxLength,
                      style: const TextStyle(fontSize: 16, height: 24 / 16),
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          title: Text(widget.initialEntry == null
              ? 'Nuovo giocatore'
              : 'Modifica giocatore'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            field(
              label: 'Nome giocatore',
              controller: nameController,
              fieldKey: const ValueKey('roster-player-name'),
              maxLength: 60,
            ),
            const SizedBox(height: 12),
            field(
              label: 'Numero di maglia',
              controller: numberController,
              fieldKey: const ValueKey('roster-player-number'),
              keyboardType: TextInputType.number,
              maxLength: 2,
            ),
            const SizedBox(height: 12),
            field(label: 'Squadra', value: widget.teamName),
            const SizedBox(height: 12),
            AccountButton(
                widget.initialEntry == null
                    ? 'Aggiungi giocatore'
                    : 'Salva giocatore',
                onPressed: submit),
            if (widget.initialEntry != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                      context, RosterEntry(widget.initialEntry!.id, '', -1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffffb4ab),
                    backgroundColor: HaykoColors.fieldSurface,
                    side: const BorderSide(color: Color(0xffffb4ab)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Rimuovi dalla squadra'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            AccountButton('Annulla',
                outline: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
}
