import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/customization.dart';

class GoalPage extends StatefulWidget {
  final League league;
  final Match match;
  const GoalPage({super.key, required this.league, required this.match});
  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  String stage = 'team';
  int team = 0;
  bool own = false;
  String? scorer, assist, keeper;
  DateTime? occurred;
  bool get competitive =>
      widget.league.type == 'competition' || widget.match.competitionRules;
  List<String> get steps => competitive
      ? ['team', 'scorer', if (!own) 'assist', 'review']
      : goalSteps(widget.match, team, own);
  void next() => setState(() {
        if (!competitive && widget.match.keepers[1 - team].mode == 'fixed') {
          keeper = widget.match.keepers[1 - team].fixed;
        }
        stage = steps[steps.indexOf(stage) + 1];
      });
  @override
  Widget build(BuildContext context) {
    final m = widget.match, l = widget.league;
    final roster = stage == 'scorer'
        ? m.teams[own ? 1 - team : team]
        : stage == 'assist'
            ? m.teams[team]
            : m.teams[1 - team];
    final sorted = [...roster]..sort((a, b) =>
        l.playerName(a).toLowerCase().compareTo(l.playerName(b).toLowerCase()));
    final plan = m.keepers[1 - team];
    final suggested = m.startedAt == null
        ? null
        : plan.at(
            DateTime.parse(m.startedAt!), occurred ?? DateTime.now().toUtc());
    if (stage == 'keeper' && suggested != null && sorted.remove(suggested)) {
      sorted.insert(0, suggested);
    }
    const titles = {
      'team': 'Squadra che guadagna il punto',
      'scorer': 'Marcatore',
      'assist': 'Assist',
      'keeper': 'Chi era in porta?',
      'review': 'Conferma gol'
    };
    return Theme(
        data: leagueTheme(context, l),
        child: Scaffold(
            appBar: AppBar(
                toolbarHeight: stage == 'team' ? 88 : null,
                title: Text(titles[stage]!),
                leading:
                    stage == 'scorer' || stage == 'assist' || stage == 'keeper'
                        ? IconButton(
                            tooltip: 'Passaggio precedente',
                            onPressed: () => setState(
                                () => stage = steps[steps.indexOf(stage) - 1]),
                            icon: const Icon(Icons.arrow_back))
                        : null,
                actions: stage == 'team' ||
                        stage == 'scorer' ||
                        stage == 'assist' ||
                        stage == 'keeper'
                    ? null
                    : [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annulla'))
                      ]),
            body: ListView(
                padding: EdgeInsets.all(stage == 'team' ||
                        stage == 'scorer' ||
                        stage == 'assist' ||
                        stage == 'keeper'
                    ? 24
                    : 20),
                children: [
                  if (stage != 'team' &&
                      stage != 'scorer' &&
                      stage != 'assist' &&
                      stage != 'keeper')
                    TextButton(
                        onPressed: () => setState(
                            () => stage = steps[steps.indexOf(stage) - 1]),
                        child: const Text('Passaggio precedente')),
                  if (stage == 'team') ...[
                    const Text(
                        'Per un autogol seleziona la squadra che guadagna il punto.',
                        style: TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 16,
                            height: 24 / 16)),
                    const SizedBox(height: 12),
                    for (var n = 0; n < 2; n++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalTeamOption(
                            name: m.names[n],
                            team: n,
                            color: m.teamColors[n],
                            onTap: () {
                              team = n;
                              scorer = assist = keeper = null;
                              occurred = DateTime.now().toUtc();
                              next();
                            }),
                      ),
                    _GoalCancelButton(onPressed: () => Navigator.pop(context)),
                  ],
                  if (stage == 'scorer') ...[
                    _OwnGoalToggle(
                        value: own,
                        onChanged: (value) => setState(() {
                              own = value;
                              scorer = assist = null;
                            })),
                    const SizedBox(height: 12),
                    for (final id in sorted) ...[
                      _GoalPlayerOption(
                          label: competitive
                              ? competitionPlayerLabel(
                                  l, m, own ? 1 - team : team, id)
                              : l.playerName(id),
                          subtitle: m.names[own ? 1 - team : team],
                          color: competitive
                              ? m.teamColors[own ? 1 - team : team]
                              : l.players
                                  .firstWhere((player) => player.id == id)
                                  .color,
                          onTap: () {
                            scorer = id;
                            assist = null;
                            next();
                          }),
                      const SizedBox(height: 12),
                    ],
                    _GoalCancelButton(
                        label: 'Non indicato',
                        onPressed: () {
                          scorer = assist = null;
                          next();
                        }),
                  ],
                  if (stage == 'assist') ...[
                    for (final id in sorted.where((id) => id != scorer)) ...[
                      _GoalPlayerOption(
                          label: competitive
                              ? competitionPlayerLabel(l, m, team, id)
                              : l.playerName(id),
                          subtitle: m.names[team],
                          color: competitive
                              ? m.teamColors[team]
                              : l.players
                                  .firstWhere((player) => player.id == id)
                                  .color,
                          onTap: () {
                            assist = id;
                            next();
                          }),
                      const SizedBox(height: 12),
                    ],
                    _GoalPrimaryButton(
                        label: 'Nessun assist',
                        onPressed: () {
                          assist = null;
                          next();
                        }),
                  ],
                  if (stage == 'keeper') ...[
                    for (final id in sorted) ...[
                      _GoalPlayerOption(
                          playerId: id,
                          label: competitive
                              ? competitionPlayerLabel(l, m, 1 - team, id)
                              : l.playerName(id),
                          subtitle: id == suggested
                              ? 'Turno previsto'
                              : m.names[1 - team],
                          color: competitive
                              ? m.teamColors[1 - team]
                              : l.players
                                  .firstWhere((player) => player.id == id)
                                  .color,
                          highlighted: id == suggested,
                          onTap: () {
                            keeper = id;
                            next();
                          }),
                      const SizedBox(height: 12),
                    ],
                    _GoalCancelButton(
                        label: 'Non indicato',
                        onPressed: () {
                          keeper = null;
                          next();
                        }),
                  ],
                  if (stage == 'review') ...[
                    Text(
                        '${own ? 'Autogol a favore di' : 'Gol per'} ${m.names[team]}',
                        style: const TextStyle(fontSize: 26)),
                    Text(
                        'Autore: ${l.playerName(scorer)}${own ? '' : '\nAssist: ${l.playerName(assist)}'}${competitive ? '' : '\nPortiere: ${l.playerName(keeper)}'}',
                        style: const TextStyle(fontSize: 20)),
                    if (!competitive && plan.mode == 'fixed')
                      const Text('Portiere fisso attribuito automaticamente.'),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            context,
                            Goal(
                                id: newId(),
                                team: team,
                                scorer: scorer,
                                assist: own ? null : assist,
                                keeper: keeper,
                                ownGoal: own,
                                time: (occurred ?? DateTime.now().toUtc())
                                    .toIso8601String())),
                        child: const Text('Conferma gol')),
                  ],
                ])));
  }
}

class _GoalTeamOption extends StatelessWidget {
  const _GoalTeamOption(
      {required this.name,
      required this.team,
      required this.color,
      required this.onTap});

  final String name;
  final int team;
  final int color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('goal-team-$team'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(color),
                  foregroundColor: contrastColor(color),
                  child: RichText(
                    text: TextSpan(
                      text: team == 0 ? 'A' : 'B',
                      style: TextStyle(
                          color: contrastColor(color),
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 16, height: 24 / 16)),
                      Text('Squadra ${team == 0 ? 'A' : 'B'}',
                          style: const TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _OwnGoalToggle extends StatelessWidget {
  const _OwnGoalToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: SwitchListTile(
          key: const ValueKey('own-goal-toggle'),
          value: value,
          onChanged: onChanged,
          title: const Text('Autogol',
              style: TextStyle(fontSize: 16, height: 24 / 16)),
          tileColor: HaykoColors.fieldSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          activeThumbColor: HaykoColors.chalk,
          activeTrackColor: HaykoColors.fieldLine,
          inactiveThumbColor: HaykoColors.mutedText,
          inactiveTrackColor: HaykoColors.fieldLine,
        ),
      );
}

class _GoalPlayerOption extends StatelessWidget {
  const _GoalPlayerOption(
      {this.playerId,
      required this.label,
      required this.subtitle,
      required this.color,
      this.highlighted = false,
      required this.onTap});

  final String? playerId;
  final String label;
  final String subtitle;
  final int color;
  final bool highlighted;
  final VoidCallback onTap;

  String get initials {
    final words = label
        .replaceAll(RegExp(r'[#·].*'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: highlighted ? HaykoColors.fieldLine : HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: highlighted
              ? const BorderSide(color: HaykoColors.chalk, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: playerId == null ? null : ValueKey('goal-player-$playerId'),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(color),
                  foregroundColor: contrastColor(color),
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 16, height: 24 / 16)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (highlighted) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 24, color: HaykoColors.chalk),
                ],
              ]),
            ),
          ),
        ),
      );
}

class _GoalCancelButton extends StatelessWidget {
  const _GoalCancelButton({this.label = 'Annulla', required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: HaykoColors.fieldSurface,
            foregroundColor: HaykoColors.chalk,
            side: const BorderSide(color: HaykoColors.fieldLine),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
}

class _GoalPrimaryButton extends StatelessWidget {
  const _GoalPrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: HaykoColors.chalk,
            foregroundColor: HaykoColors.fieldBackground,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
}
