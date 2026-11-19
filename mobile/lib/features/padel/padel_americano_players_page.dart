import 'package:flutter/material.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/leagues/player_edit_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_calendar_page.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelAmericanoPlayersPage extends StatefulWidget {
  const PadelAmericanoPlayersPage({
    super.key,
    required this.league,
    required this.competition,
    required this.save,
  });

  final League league;
  final Competition competition;
  final Save save;

  @override
  State<PadelAmericanoPlayersPage> createState() =>
      _PadelAmericanoPlayersPageState();
}

class _PadelAmericanoPlayersPageState extends State<PadelAmericanoPlayersPage> {
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final selected = <String>{};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selected.addAll(widget.competition.americanoPlayerIds);
    search.addListener(refresh);
    searchFocus.addListener(refresh);
  }

  @override
  void dispose() {
    search.removeListener(refresh);
    searchFocus.removeListener(refresh);
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> addPlayer() async {
    final result = await Navigator.push<PlayerEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerEditPage(
          name: '',
          color: widget.league.primaryColor,
          creating: true,
          padel: true,
          unavailableNames: widget.league.players.map((p) => p.name).toList(),
        ),
      ),
    );
    if (result == null || result.deleted || !mounted) return;
    final player = Player(newId(), result.name, color: result.color);
    widget.league.players.add(player);
    try {
      await widget.save();
      if (mounted) setState(() {});
    } catch (error) {
      widget.league.players.remove(player);
      if (mounted) showError(context, error);
    }
  }

  Future<void> confirm() async {
    if (saving || selected.length != widget.competition.americanoPlayerCount) {
      return;
    }
    final previous = [...widget.competition.americanoPlayerIds];
    final previousSchedule = [
      for (final round in widget.competition.americanoSchedule)
        [
          for (final fixture in round) [...fixture]
        ],
    ];
    widget.competition.americanoPlayerIds
      ..clear()
      ..addAll(selected);
    if (previous.toSet().difference(selected).isNotEmpty ||
        selected.difference(previous.toSet()).isNotEmpty) {
      widget.competition.americanoSchedule.clear();
    }
    setState(() => saving = true);
    try {
      await widget.save();
      if (!mounted) return;
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PadelAmericanoCalendarPage(
            league: widget.league,
            competition: widget.competition,
            save: widget.save,
          ),
        ),
      );
      if (mounted && confirmed == true) Navigator.pop(context, true);
    } catch (error) {
      widget.competition.americanoPlayerIds
        ..clear()
        ..addAll(previous);
      widget.competition.americanoSchedule
        ..clear()
        ..addAll(previousSchedule);
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.league.players]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final query = search.text.trim().toLowerCase();
    final visible = players
        .where((player) =>
            query.isEmpty || player.name.toLowerCase().contains(query))
        .toList();
    final active = searchFocus.hasFocus;
    final required = widget.competition.americanoPlayerCount;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        title: const Text('Giocatori Americano'),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            child: Column(children: [
              Container(
                height: 76,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HaykoColors.fieldSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HaykoColors.padelAccent.withValues(alpha: .42),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Partecipanti richiesti',
                        style: TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('$required giocatori',
                        style: const TextStyle(fontSize: 16, height: 24 / 16)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Text('${selected.length} / $required selezionati',
                      key: const ValueKey('americano-selection-counter'),
                      style: const TextStyle(
                          fontSize: 20,
                          height: 26 / 20,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 152,
                  child: AccountButton('Genera turni',
                      key: const ValueKey('americano-generate-rounds'),
                      onPressed: selected.length == required && !saving
                          ? confirm
                          : null),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: HaykoColors.fieldSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HaykoColors.padelAccent.withValues(alpha: .5),
                      ),
                    ),
                    child: Row(children: [
                      const Icon(Icons.search,
                          size: 22, color: HaykoColors.mutedText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('americano-search'),
                          controller: search,
                          focusNode: searchFocus,
                          decoration: const InputDecoration(
                            hintText: 'Cerca giocatore',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: active
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 120,
                            child: AccountButton('+ Giocatore',
                                outline: true, onPressed: addPlayer),
                          ),
                        ),
                ),
              ]),
            ]),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => searchFocus.unfocus(),
              child: ListView.builder(
                key: const ValueKey('americano-player-list'),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: visible.length + (active ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == visible.length) {
                    return AccountButton('+ Giocatore',
                        outline: true, onPressed: addPlayer);
                  }
                  final player = visible[index];
                  final isSelected = selected.contains(player.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AmericanoPlayerRow(
                      player: player,
                      selected: isSelected,
                      current: widget.league.myPlayer == player.id,
                      onTap: () {
                        searchFocus.unfocus();
                        setState(() {
                          if (isSelected) {
                            selected.remove(player.id);
                          } else if (selected.length < required) {
                            selected.add(player.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AmericanoPlayerRow extends StatelessWidget {
  const _AmericanoPlayerRow({
    required this.player,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final Player player;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final words = player.name.trim().split(RegExp(r'\s+'));
    final initials = words.take(2).map((word) => word[0]).join().toUpperCase();
    return Material(
      color: selected ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? HaykoColors.padelAccent : HaykoColors.fieldLine,
        ),
      ),
      child: InkWell(
        key: ValueKey('americano-player-${player.id}'),
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
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (current) ...[
                        Container(
                          width: 4,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: HaykoColors.chalk,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, height: 1.5)),
                      ),
                    ]),
                    Text(selected ? 'Selezionato' : 'Disponibile',
                        style: const TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (selected)
                const SizedBox(
                  width: 64,
                  child: Text('✓', textAlign: TextAlign.right),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
