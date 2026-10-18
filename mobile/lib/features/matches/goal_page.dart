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
  Widget option(String label, VoidCallback action,
          {int? color, bool highlighted = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: FilledButton.tonal(
              style: highlighted
                  ? FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2))
                  : null,
              onPressed: action,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    if (highlighted) ...[
                      const Icon(Icons.star),
                      const SizedBox(width: 8)
                    ],
                    if (color != null) ...[
                      CircleAvatar(radius: 8, backgroundColor: Color(color)),
                      const SizedBox(width: 8)
                    ],
                    Expanded(child: Text(label))
                  ]))));
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
                actions: stage == 'team'
                    ? null
                    : [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annulla'))
                      ]),
            body: ListView(
                padding: EdgeInsets.all(stage == 'team' ? 24 : 20),
                children: [
                  if (stage != 'team')
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
                  if (stage == 'scorer')
                    SwitchListTile(
                        title: const Text('Autogol'),
                        value: own,
                        onChanged: (v) => setState(() {
                              own = v;
                              scorer = assist = null;
                            })),
                  if (stage == 'keeper' && plan.mode == 'rotation')
                    Text(
                        'Turno previsto: ${l.playerName(suggested)}. Seleziona chi era realmente in porta.'),
                  if (stage == 'scorer' ||
                      stage == 'assist' ||
                      stage == 'keeper') ...[
                    ...sorted
                        .where((id) => stage != 'assist' || id != scorer)
                        .map((id) =>
                            option(
                                '${competitive ? competitionPlayerLabel(l, m, stage == 'scorer' && own ? 1 - team : team, id) : l.playerName(id)}${stage == 'keeper' && id == suggested ? ' · turno previsto' : ''}',
                                () {
                              if (stage == 'scorer') {
                                scorer = id;
                                assist = null;
                              } else if (stage == 'assist') {
                                assist = id;
                              } else {
                                keeper = id;
                              }
                              next();
                            },
                                highlighted:
                                    stage == 'keeper' && id == suggested,
                                color: competitive
                                    ? m.teamColors[stage == 'scorer' && own
                                        ? 1 - team
                                        : team]
                                    : l.players
                                        .firstWhere((p) => p.id == id)
                                        .color)),
                    option(stage == 'assist' ? 'Nessun assist' : 'Non indicato',
                        () {
                      if (stage == 'scorer') {
                        scorer = null;
                        assist = null;
                      } else if (stage == 'assist') {
                        assist = null;
                      } else {
                        keeper = null;
                      }
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

class _GoalCancelButton extends StatelessWidget {
  const _GoalCancelButton({required this.onPressed});
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
          child: const Text('Annulla'),
        ),
      );
}
