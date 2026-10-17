import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

class LeagueSettingsPage extends StatefulWidget {
  final League league;
  final Save save;
  final Save? delete;
  const LeagueSettingsPage(
      {super.key, required this.league, required this.save, this.delete});
  @override
  State<LeagueSettingsPage> createState() => _LeagueSettingsPageState();
}

class _LeagueSettingsPageState extends State<LeagueSettingsPage> {
  League get l => widget.league;
  bool busy = false;
  Future<void> edit() async {
    final change = await editIdentity(
        context, 'Personalizza lega', l.name, l.primaryColor,
        secondary: l.secondaryColor);
    if (change == null) return;
    final name = l.name, primary = l.primaryColor, secondary = l.secondaryColor;
    setState(() => busy = true);
    l.name = change.name;
    l.primaryColor = change.color;
    l.secondaryColor = change.secondary!;
    try {
      await widget.save();
    } catch (e) {
      l.name = name;
      l.primaryColor = primary;
      l.secondaryColor = secondary;
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> preset(TeamPreset p) async {
    final change =
        await editIdentity(context, 'Personalizza squadra', p.name, p.color);
    if (change == null) return;
    if (l.presets.any((other) =>
        other.id != p.id &&
        other.name.toLowerCase() == change.name.toLowerCase())) {
      if (mounted) {
        showError(context, 'Esiste già una squadra con questo nome.');
      }
      return;
    }
    final name = p.name, color = p.color;
    p.name = change.name;
    p.color = change.color;
    setState(() => busy = true);
    try {
      await widget.save();
    } catch (e) {
      p.name = name;
      p.color = color;
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> remove() async {
    if (!await confirm(context, 'Eliminare ${l.name}?',
        'Verranno eliminate la lega, le partite, le competizioni e le statistiche contenute.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.delete!();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, l),
      child: Scaffold(
          appBar: AppBar(title: const Text('Impostazioni lega')),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            Text(l.name, style: const TextStyle(fontSize: 26)),
            Row(children: [
              CircleAvatar(backgroundColor: Color(l.primaryColor)),
              const SizedBox(width: 12),
              CircleAvatar(backgroundColor: Color(l.secondaryColor))
            ]),
            if (l.manage)
              FilledButton.icon(
                  onPressed: busy ? null : edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Nome e colori della lega')),
            const SizedBox(height: 24),
            const Text('Squadre salvate', style: TextStyle(fontSize: 22)),
            if (l.presets.isEmpty)
              const Text(
                  'Puoi salvare una squadra come preset nel riepilogo della formazione.'),
            ...l.presets.where((p) => !p.archived).map((p) => ListTile(
                leading: CircleAvatar(
                    backgroundColor: Color(p.color),
                    child: Icon(Icons.groups, color: contrastColor(p.color))),
                title: Text(p.name),
                subtitle: Text('${p.players.length} giocatori'),
                trailing: l.manage
                    ? IconButton(
                        tooltip: 'Modifica squadra',
                        onPressed: busy ? null : () => preset(p),
                        icon: const Icon(Icons.edit))
                    : null)),
            if (widget.delete != null && l.president) ...[
              const Divider(height: 40),
              TextButton.icon(
                  onPressed: busy ? null : remove,
                  icon: const Icon(Icons.delete_outline,
                      color: HaykoColors.danger),
                  label: const Text('Elimina lega',
                      style: TextStyle(color: HaykoColors.danger)))
            ],
          ])));
}
