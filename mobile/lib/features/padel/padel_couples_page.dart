import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/padel/padel_couple_edit_page.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelCouplesPage extends StatefulWidget {
  const PadelCouplesPage({super.key, required this.league, required this.save});

  final League league;
  final Save save;

  @override
  State<PadelCouplesPage> createState() => _PadelCouplesPageState();
}

class _PadelCouplesPageState extends State<PadelCouplesPage> {
  Future<void> edit([TeamPreset? couple]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PadelCoupleEditPage(
                league: widget.league, save: widget.save, couple: couple)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final couples = widget.league.presets
        .where((preset) => !preset.archived && preset.players.length == 2)
        .toList();
    return Scaffold(
      appBar: AppBar(
          toolbarHeight: 64,
          centerTitle: false,
          title: const Text('Coppie salvate')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.league.manage)
            AccountButton('+ Coppia', onPressed: () => edit()),
          if (widget.league.manage) const SizedBox(height: 12),
          if (couples.isEmpty)
            const Text('Nessuna coppia salvata.',
                style: TextStyle(color: HaykoColors.mutedText)),
          for (var index = 0; index < couples.length; index++) ...[
            _CoupleRow(
                league: widget.league,
                couple: couples[index],
                onTap:
                    widget.league.manage ? () => edit(couples[index]) : null),
            if (index != couples.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CoupleRow extends StatelessWidget {
  const _CoupleRow(
      {required this.league, required this.couple, required this.onTap});

  final League league;
  final TeamPreset couple;
  final VoidCallback? onTap;

  String get initials => couple.name
      .trim()
      .split(RegExp(r'\s+|/'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final names = couple.players
        .map((id) => league.players.where((player) => player.id == id))
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first.name)
        .join(' · ');
    return Material(
      color: HaykoColors.fieldSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(couple.color),
                  child: Text(initials.isEmpty ? '?' : initials,
                      style: TextStyle(
                          color: contrastColor(couple.color),
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(couple.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.5)),
                    Text(names,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ])),
              if (onTap != null) const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
    );
  }
}
