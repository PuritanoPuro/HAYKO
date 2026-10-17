import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';

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
    var value = entry?.name ?? '';
    var next = 1;
    while (roster.any((p) => p.number == next)) {
      next++;
    }
    var number = '${entry?.number ?? next}';
    final result = await showDialog<RosterEntry>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(entry == null
                    ? 'Aggiungi giocatore'
                    : 'Modifica giocatore'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      key: const ValueKey('roster-player-name'),
                      initialValue: value,
                      maxLength: 60,
                      decoration:
                          const InputDecoration(labelText: 'Nome giocatore'),
                      onChanged: (v) => value = v),
                  TextFormField(
                      key: const ValueKey('roster-player-number'),
                      initialValue: number,
                      maxLength: 2,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Numero di maglia'),
                      onChanged: (v) => number = v),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Annulla')),
                  FilledButton(
                      onPressed: () {
                        final n = int.tryParse(number), text = value.trim();
                        if (text.isEmpty ||
                            n == null ||
                            n < 0 ||
                            n > 99 ||
                            roster.any((p) =>
                                p.id != entry?.id &&
                                (p.number == n ||
                                    p.name.toLowerCase() ==
                                        text.toLowerCase()))) {
                          showError(c,
                              'Inserisci nome e numero da 0 a 99, diversi dagli altri giocatori della squadra.');
                          return;
                        }
                        Navigator.pop(
                            c, RosterEntry(entry?.id ?? newId(), text, n));
                      },
                      child: Text(entry == null ? 'Aggiungi' : 'Salva'))
                ]));
    if (!mounted || result == null) return;
    setState(() {
      if (entry == null) {
        roster.add(result);
      } else {
        roster[roster.indexOf(entry)] = result;
      }
    });
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
          title:
              Text(widget.team == null ? 'Nuova squadra' : 'Modifica squadra')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              TextFormField(
                  initialValue: name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Nome squadra'),
                  onChanged: (v) => name = v),
              ColorChoice(
                  label: 'Colore squadra e giocatori',
                  color: color,
                  changed: (v) => setState(() => color = v)),
              Row(children: [
                Expanded(child: Text('${roster.length} giocatori')),
                FilledButton(
                    onPressed: busy ? null : submit,
                    child: const Text('Salva squadra'))
              ]),
              TextButton.icon(
                  onPressed: busy ? null : () => player(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Giocatore')),
              const Text(
                  'Aggiungi nome e numero: il giocatore entra direttamente nella rosa.'),
            ])),
        Expanded(
            child: ListView(
                children: roster
                    .map((p) => Card(
                        child: ListTile(
                            leading: CircleAvatar(
                                backgroundColor: Color(color),
                                child: Text('${p.number}',
                                    style: TextStyle(
                                        color: contrastColor(color)))),
                            title: Text(p.name),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  tooltip: 'Modifica giocatore',
                                  onPressed: busy ? null : () => player(p),
                                  icon: const Icon(Icons.edit)),
                              IconButton(
                                  tooltip: 'Rimuovi giocatore',
                                  onPressed: busy ? null : () => remove(p),
                                  icon: const Icon(Icons.delete_outline))
                            ]))))
                    .toList())),
      ]));
}
