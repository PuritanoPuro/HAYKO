import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';

class TeamPresetsPage extends StatefulWidget {
  final League league;
  final Save save;
  const TeamPresetsPage({super.key, required this.league, required this.save});
  @override
  State<TeamPresetsPage> createState() => _TeamPresetsPageState();
}

class _TeamPresetsPageState extends State<TeamPresetsPage> {
  bool busy = false;
  Future<void> edit([TeamPreset? p]) async {
    await Navigator.push<TeamPreset>(
        context,
        MaterialPageRoute(
            builder: (_) => TeamEditor(
                league: widget.league,
                save: widget.save,
                team: p,
                initialFormat: p?.players.length)));
    if (mounted) setState(() {});
  }

  Future<void> remove(TeamPreset p) async {
    if (widget.league.competitions.any((c) => c.teamIds.contains(p.id))) {
      showError(context,
          'La squadra partecipa a una competizione e non può essere eliminata dai preset.');
      return;
    }
    if (!await confirm(context, 'Eliminare ${p.name}?',
        'Il preset non sarà più selezionabile. Le partite e le statistiche già registrate resteranno conservate.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    p.archived = true;
    try {
      await widget.save();
    } catch (e) {
      p.archived = false;
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.league.presets.where((p) => !p.archived).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Squadre salvate')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          if (widget.league.manage)
            FilledButton.icon(
                onPressed: busy ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Squadra')),
          if (presets.isEmpty) const Text('Nessuna squadra salvata.'),
          ...presets.map((p) => Card(
              child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Color(p.color),
                      child: const Icon(Icons.groups)),
                  title: Text(p.name),
                  subtitle: Text('${p.players.length} giocatori'),
                  trailing: widget.league.manage
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Modifica preset',
                              onPressed: busy ? null : () => edit(p),
                              icon: const Icon(Icons.edit)),
                          IconButton(
                              tooltip: 'Elimina preset',
                              onPressed: busy ? null : () => remove(p),
                              icon: const Icon(Icons.delete_outline))
                        ])
                      : null))),
        ]));
  }
}
