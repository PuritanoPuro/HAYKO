import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/customization.dart';

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

  @override
  Widget build(BuildContext context) {
    final presets = widget.league.presets.where((p) => !p.archived).toList();
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 64,
            title: const Text('Squadre salvate',
                style: TextStyle(
                    fontSize: 20, height: 1.3, fontWeight: FontWeight.w700))),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          if (widget.league.manage)
            AccountButton('+ Squadra', onPressed: busy ? null : () => edit()),
          if (widget.league.manage && presets.isNotEmpty)
            const SizedBox(height: 12),
          if (presets.isEmpty)
            const Text('Nessuna squadra salvata.',
                style: TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 14,
                    height: 20 / 14)),
          for (var index = 0; index < presets.length; index++) ...[
            _SavedTeamRow(
                team: presets[index],
                enabled: widget.league.manage && !busy,
                onTap: () => edit(presets[index])),
            if (index != presets.length - 1) const SizedBox(height: 12),
          ],
        ]));
  }
}

class _SavedTeamRow extends StatelessWidget {
  const _SavedTeamRow(
      {required this.team, required this.enabled, required this.onTap});
  final TeamPreset team;
  final bool enabled;
  final VoidCallback onTap;

  String get initials {
    final words = team.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(team.color),
                    child: Text(initials,
                        style: TextStyle(
                            color: contrastColor(team.color),
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w400)),
                        Text(
                            '${team.players.length}v${team.players.length} · ${team.players.length} ${team.players.length == 1 ? 'giocatore' : 'giocatori'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
                if (enabled)
                  const SizedBox(
                      width: 64,
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.chevron_right, size: 24))),
              ]),
            ),
          ),
        ),
      );
}
