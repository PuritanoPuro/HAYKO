import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class GoalEditResult {
  const GoalEditResult.saved(this.goal) : deleted = false;
  const GoalEditResult.deleted()
      : goal = null,
        deleted = true;

  final Goal? goal;
  final bool deleted;
}

class GoalEditPage extends StatefulWidget {
  const GoalEditPage(
      {super.key,
      required this.league,
      required this.match,
      required this.goal});

  final League league;
  final Match match;
  final Goal goal;

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  late bool ownGoal;
  late String? scorer;
  late String? assist;
  late String? keeper;

  bool get competitive =>
      widget.league.type == 'competition' || widget.match.competitionRules;
  int get scoringTeam => widget.goal.team;
  List<String> get scorerOptions =>
      widget.match.teams[ownGoal ? 1 - scoringTeam : scoringTeam];
  List<String> get assistOptions => widget.match.teams[scoringTeam]
      .where((player) => player != scorer)
      .toList();
  List<String> get keeperOptions {
    final plan = widget.match.keepers[1 - scoringTeam];
    if (plan.mode == 'fixed' && plan.fixed != null) return [plan.fixed!];
    return widget.match.teams[1 - scoringTeam];
  }

  @override
  void initState() {
    super.initState();
    ownGoal = widget.goal.ownGoal;
    scorer = widget.goal.scorer;
    assist = widget.goal.assist;
    keeper = widget.goal.keeper;
  }

  int playerColor(String id) {
    final players = widget.league.players.where((player) => player.id == id);
    return players.isEmpty
        ? widget.match.teamColors[scoringTeam]
        : players.first.color;
  }

  Future<String?> choosePlayer(
      String title, List<String> players, String? selected,
      {bool allowNone = true}) async {
    return showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => SafeArea(
              child: Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.72),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: const BoxDecoration(
                    color: HaykoColors.fieldSurface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 22,
                              height: 28 / 22,
                              fontWeight: FontWeight.w800))),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final id in players) ...[
                          _GoalPlayerChoice(
                              name: widget.league.playerName(id),
                              color: playerColor(id),
                              selected: selected == id,
                              onTap: () => Navigator.pop(context, id)),
                          const SizedBox(height: 8),
                        ],
                        if (allowNone)
                          _GoalPlayerChoice(
                              name: 'Non indicato',
                              color: HaykoColors.mutedText.toARGB32(),
                              selected: selected == null,
                              onTap: () => Navigator.pop(context, '__none__')),
                      ],
                    ),
                  ),
                ]),
              ),
            ));
  }

  Future<void> selectScorer() async {
    final value = await choosePlayer('Marcatore', scorerOptions, scorer);
    if (value != null && mounted) {
      setState(() {
        scorer = value == '__none__' ? null : value;
        if (assist == scorer) assist = null;
      });
    }
  }

  Future<void> selectAssist() async {
    final value = await choosePlayer('Assistman', assistOptions, assist);
    if (value != null && mounted) {
      setState(() => assist = value == '__none__' ? null : value);
    }
  }

  Future<void> selectKeeper() async {
    final value = await choosePlayer('Portiere', keeperOptions, keeper);
    if (value != null && mounted) {
      setState(() => keeper = value == '__none__' ? null : value);
    }
  }

  void save() => Navigator.pop(
      context,
      GoalEditResult.saved(Goal(
          id: widget.goal.id,
          team: widget.goal.team,
          scorer: scorer,
          assist: ownGoal ? null : assist,
          keeper: competitive ? null : keeper,
          ownGoal: ownGoal,
          time: widget.goal.time)));

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => HaykoDialog(
                    title: 'Elimina gol',
                    content: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Il gol verrà rimosso dal risultato e tutte le statistiche saranno ricalcolate.',
                            style: TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 14,
                                height: 20 / 14))),
                    actions: [
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Elimina gol')),
                      OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annulla')),
                    ])) ??
        false;
    if (confirmed && mounted) {
      Navigator.pop(context, const GoalEditResult.deleted());
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: leagueTheme(context, widget.league),
        child: Scaffold(
          appBar: AppBar(
              toolbarHeight: 64,
              title: const Text('Modifica gol',
                  style: TextStyle(
                      fontSize: 20, height: 1.3, fontWeight: FontWeight.w700))),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: HaykoColors.fieldSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                          left: BorderSide(
                              color: Color(
                                  widget.match.teamColors[widget.goal.team]),
                              width: 4))),
                  child: Text('Gol per ${widget.match.names[widget.goal.team]}',
                      style: const TextStyle(
                          fontSize: 18,
                          height: 24 / 18,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Material(
                  color: HaykoColors.fieldSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: HaykoColors.fieldLine)),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    key: const ValueKey('goal-own-goal-field'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: const Text('Autogol',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    subtitle: const Text('Il punto resta alla stessa squadra',
                        style: TextStyle(
                            color: HaykoColors.mutedText, fontSize: 12)),
                    value: ownGoal,
                    onChanged: (value) => setState(() {
                      ownGoal = value;
                      scorer = null;
                      assist = null;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _GoalEditField(
                    key: const ValueKey('goal-scorer-field'),
                    label: ownGoal ? 'Autore autogol' : 'Marcatore',
                    value: widget.league.playerName(scorer),
                    onTap: selectScorer),
                if (!ownGoal) ...[
                  const SizedBox(height: 12),
                  _GoalEditField(
                      key: const ValueKey('goal-assist-field'),
                      label: 'Assistman',
                      value: widget.league.playerName(assist),
                      onTap: selectAssist),
                ],
                if (!competitive) ...[
                  const SizedBox(height: 12),
                  _GoalEditField(
                      key: const ValueKey('goal-keeper-field'),
                      label: 'Portiere',
                      value: widget.league.playerName(keeper),
                      onTap: selectKeeper),
                ],
                const SizedBox(height: 12),
                AccountButton('Salva modifiche', onPressed: save),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    key: const ValueKey('delete-goal-button'),
                    onPressed: delete,
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
                    child: const Text('Elimina gol'),
                  ),
                ),
                const SizedBox(height: 12),
                AccountButton('Annulla',
                    outline: true, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      );
}

class _GoalEditField extends StatelessWidget {
  const _GoalEditField(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 76,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: HaykoColors.fieldLine),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
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
              const Icon(Icons.expand_more, color: HaykoColors.mutedText),
            ]),
          ),
        ),
      );
}

class _GoalPlayerChoice extends StatelessWidget {
  const _GoalPlayerChoice(
      {required this.name,
      required this.color,
      required this.selected,
      required this.onTap});

  final String name;
  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? HaykoColors.fieldLine : HaykoColors.fieldBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Color(color), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700))),
                if (selected) const Icon(Icons.check),
              ]),
            ),
          ),
        ),
      );
}
