import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelCoupleEditPage extends StatefulWidget {
  const PadelCoupleEditPage(
      {super.key, required this.league, required this.save, this.couple});

  final League league;
  final Save save;
  final TeamPreset? couple;

  @override
  State<PadelCoupleEditPage> createState() => _PadelCoupleEditPageState();
}

class _PadelCoupleEditPageState extends State<PadelCoupleEditPage> {
  late final TextEditingController name;
  late int color;
  late final Set<String> selected;
  bool busy = false;

  bool get creating => widget.couple == null;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.couple?.name ?? '');
    color = widget.couple?.color ?? HaykoColors.padelAccent.toARGB32();
    selected = {...?widget.couple?.players};
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  String get colorHex =>
      '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void toggle(String id) {
    if (busy) return;
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else if (selected.length < 2) {
        selected.add(id);
      } else {
        showError(context, 'Una coppia Padel è composta da due giocatori.');
      }
    });
  }

  Future<void> save() async {
    final value = name.text.trim();
    if (value.isEmpty) {
      showError(context, 'Inserisci il nome della coppia.');
      return;
    }
    if (selected.length != 2) {
      showError(context, 'Seleziona esattamente due giocatori.');
      return;
    }
    final duplicateName = widget.league.presets.any((preset) =>
        preset.id != widget.couple?.id &&
        !preset.archived &&
        preset.name.toLowerCase() == value.toLowerCase());
    final duplicatePlayers = widget.league.presets.any((preset) =>
        preset.id != widget.couple?.id &&
        !preset.archived &&
        preset.players.toSet().containsAll(selected) &&
        selected.containsAll(preset.players));
    if (duplicateName || duplicatePlayers) {
      showError(context, 'Questa coppia è già stata salvata.');
      return;
    }

    setState(() => busy = true);
    final oldName = widget.couple?.name;
    final oldColor = widget.couple?.color;
    final oldPlayers = widget.couple == null
        ? <String>[]
        : List<String>.from(widget.couple!.players);
    final couple = widget.couple ?? TeamPreset(newId(), value, []);
    if (creating) widget.league.presets.add(couple);
    couple.name = value;
    couple.color = color;
    couple.players
      ..clear()
      ..addAll(selected);
    try {
      await widget.save();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (creating) {
        widget.league.presets.remove(couple);
      } else {
        couple.name = oldName!;
        couple.color = oldColor!;
        couple.players
          ..clear()
          ..addAll(oldPlayers);
      }
      if (mounted) {
        setState(() => busy = false);
        showError(context, error);
      }
    }
  }

  Future<void> delete() async {
    final couple = widget.couple;
    if (couple == null || busy) return;
    final used = widget.league.matches.any((match) =>
        match.presetIds.contains(couple.id) ||
        match.teams.any((team) => couple.players.toSet().containsAll(team)));
    if (used) {
      showError(context,
          'Questa coppia è presente nello storico e non può essere eliminata.');
      return;
    }
    if (!await confirm(context, 'Elimina coppia',
        'Vuoi eliminare ${couple.name} dalle coppie salvate?')) {
      return;
    }
    setState(() => busy = true);
    final index = widget.league.presets.indexOf(couple);
    widget.league.presets.remove(couple);
    try {
      await widget.save();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      widget.league.presets.insert(index, couple);
      if (mounted) {
        setState(() => busy = false);
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.league.players]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
          toolbarHeight: 64,
          centerTitle: false,
          title: Text(creating ? 'Nuova coppia' : 'Modifica coppia')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AccountField('Nome coppia',
              controller: name,
              borderColor: HaykoColors.padelAccent.withValues(alpha: .4)),
          const SizedBox(height: 12),
          Material(
            color: HaykoColors.fieldSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: HaykoColors.padelAccent.withValues(alpha: .4))),
            child: InkWell(
              key: const ValueKey('padel-couple-color'),
              borderRadius: BorderRadius.circular(12),
              onTap: busy
                  ? null
                  : () async {
                      final value = await chooseColor(context, color);
                      if (value != null && mounted) {
                        setState(() => color = value);
                      }
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
                          const Text('Colore coppia',
                              style: TextStyle(
                                  color: HaykoColors.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(colorHex),
                        ])),
                    CircleAvatar(radius: 18, backgroundColor: Color(color)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (creating) ...[
            const Text('Giocatori della coppia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          for (final player
              in players.where((player) => selected.contains(player.id))) ...[
            _CouplePlayerRow(
                player: player,
                current: widget.league.myPlayer == player.id,
                selected: true,
                onTap: () => toggle(player.id)),
            const SizedBox(height: 12),
          ],
          if (creating || selected.length < 2)
            for (final player in players
                .where((player) => !selected.contains(player.id))) ...[
              _CouplePlayerRow(
                  player: player,
                  current: widget.league.myPlayer == player.id,
                  selected: false,
                  onTap: () => toggle(player.id)),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          AccountButton(creating ? 'Salva coppia' : 'Salva coppia',
              onPressed: busy ? null : save),
          if (!creating) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                  onPressed: busy ? null : delete,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffffb4ab),
                      side: const BorderSide(color: Color(0xffffb4ab)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Elimina coppia')),
            ),
          ],
        ],
      ),
    );
  }
}

class _CouplePlayerRow extends StatelessWidget {
  const _CouplePlayerRow(
      {required this.player,
      required this.current,
      required this.selected,
      required this.onTap});

  final Player player;
  final bool current;
  final bool selected;
  final VoidCallback onTap;

  String get initials => player.name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: HaykoColors.padelAccent.withValues(alpha: .22))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
                border: current ? Border.all(color: HaykoColors.chalk) : null,
                borderRadius: BorderRadius.circular(12)),
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
                                fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(current ? '${player.name} · Tu' : player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 16, height: 1.5)),
                          Text(
                              selected
                                  ? 'Nella coppia'
                                  : 'Aggiungi alla coppia',
                              style: const TextStyle(
                                  color: HaykoColors.mutedText,
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ]),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                    tooltip: selected
                        ? 'Rimuovi dalla coppia'
                        : 'Aggiungi alla coppia',
                    onPressed: onTap,
                    icon: Icon(selected ? Icons.remove : Icons.add,
                        color: selected
                            ? const Color(0xffffb4ab)
                            : HaykoColors.padelAccent)),
              )
            ]),
          ),
        ),
      );
}
