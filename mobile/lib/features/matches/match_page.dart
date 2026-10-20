import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/settings_page.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/goal_page.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'dart:async';

class MatchPage extends StatefulWidget {
  final League league;
  final Match match;
  final Save save;
  final Save? reload;
  const MatchPage(
      {super.key,
      required this.league,
      required this.match,
      required this.save,
      this.reload});
  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  Match get m => widget.match;
  bool saving = false;
  Timer? ticker;
  Timer? poll;
  bool refreshing = false;
  Future<void>? refreshJob;
  String? connectionWarning;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && m.status == 'live') setState(() {});
    });
    if (widget.reload != null && !widget.league.canRecord(m)) {
      poll = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    poll?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (saving || refreshing || widget.reload == null) return;
    setState(() => refreshing = true);
    refreshJob = () async {
      try {
        await widget.reload!();
        connectionWarning = null;
        final fresh = widget.league.matches.firstWhere((x) => x.id == m.id);
        m.status = fresh.status;
        m.startedAt = fresh.startedAt;
        m.finishedAt = fresh.finishedAt;
        if (!identical(m, fresh)) {
          m.goals
            ..clear()
            ..addAll(fresh.goals);
        }
      } catch (_) {
        connectionWarning =
            'Aggiornamento non riuscito: stai vedendo gli ultimi dati ricevuti.';
      }
    }();
    await refreshJob;
    refreshJob = null;
    if (mounted) setState(() => refreshing = false);
  }

  Future<void> startMatch() async {
    final rotation = widget.league.type != 'competition' &&
        !m.competitionRules &&
        m.keepers.any((k) => k.mode == 'rotation' && (k.sound || k.vibration));
    if (rotation || Theme.of(context).platform == TargetPlatform.android) {
      try {
        await RotationAlerts.instance.requestPermission(rotation: rotation);
      } catch (_) {
        RotationAlerts.instance.warning = 'Impossibile attivare gli avvisi.';
      }
    }
    if (widget.league.type == 'competition' || m.competitionRules) {
      await mutate(() {
        for (var side = 0; side < 2; side++) {
          final presets =
              widget.league.presets.where((p) => p.id == m.presetIds[side]);
          if (presets.isEmpty || presets.first.players.length < m.format) {
            throw StateError(
                'Completa la rosa della squadra prima di avviare la partita.');
          }
          m.teams[side] = [...presets.first.players];
          m.names[side] = presets.first.name;
          m.teamColors[side] = presets.first.color;
        }
        if (m.teams.expand((t) => t).toSet().length !=
            m.teams.expand((t) => t).length) {
          throw StateError(
              'Un giocatore non può appartenere a entrambe le squadre della partita.');
        }
        m.start();
      });
    } else {
      await mutate(m.start);
    }
  }

  Future<void> editEvent() async {
    var date = m.scheduledAt == null
        ? DateTime.now()
        : DateTime.parse(m.scheduledAt!).toLocal();
    final location = TextEditingController(text: m.venue);
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => HaykoDialog(
                    title: 'Modifica dettagli partita',
                    content: Material(
                      color: Colors.transparent,
                      child: SingleChildScrollView(
                          child: EventDetailsFields(
                              date: date,
                              venue: location,
                              changed: (v) => set(() => date = v))),
                    ),
                    actions: [
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Salva')),
                      OutlinedButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Annulla')),
                    ])));
    final value = location.text;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    location.dispose();
    if (ok == true && mounted) await mutate(() => m.editDetails(date, value));
  }

  Future<void> finishMatch() async {
    String? winner;
    if (m.knockoutRound != null && m.score(0) == m.score(1)) {
      winner = await showDialog<String>(
          context: context,
          builder: (c) => HaykoDialog(
                  title: 'Chi passa il turno?',
                  content: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Seleziona la squadra che accede alla fase successiva.',
                        style: TextStyle(
                            color: HaykoColors.mutedText,
                            fontSize: 14,
                            height: 20 / 14)),
                  ),
                  actions: [
                    for (var t = 0; t < 2; t++)
                      OutlinedButton(
                          onPressed: () => Navigator.pop(c, m.presetIds[t]),
                          child: Text(m.names[t]))
                  ]));
      if (winner == null) return;
    }
    if (!mounted) return;
    if (await confirm(context, 'Terminare la partita?',
        'Il risultato aggiornerà statistiche e competizione.')) {
      await mutate(() => m.finish(winner: winner));
    }
  }

  List<Widget> keeperCards() {
    if (widget.league.type == 'competition' || m.competitionRules) return [];
    final now = m.finishedAt == null
        ? DateTime.now().toUtc()
        : DateTime.parse(m.finishedAt!);
    final start = m.startedAt == null ? now : DateTime.parse(m.startedAt!);
    return [
      for (var t = 0; t < 2; t++)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${m.names[t]} · ${m.keepers[t].mode == 'fixed' ? 'portiere fisso' : m.keepers[t].mode == 'rotation' ? 'giro portiere' : 'portiere a scelta'}'),
                      if (m.keepers[t].mode == 'fixed')
                        Text(widget.league.playerName(m.keepers[t].fixed)),
                      if (m.keepers[t].mode == 'rotation') ...[
                        Text(
                            'In porta: ${widget.league.playerName(m.keepers[t].at(start, now))}',
                            style: const TextStyle(fontSize: 20)),
                        if (m.status != 'finished')
                          Text(
                              'Successivo: ${widget.league.playerName(m.keepers[t].at(start, m.keepers[t].nextChange(start, now)))}'),
                        if (m.status == 'live')
                          Text(
                              clockText(m.keepers[t]
                                  .nextChange(start, now)
                                  .difference(now)),
                              key: ValueKey('keeper-countdown-$t'),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ])))
    ];
  }

  Future<void> mutate(void Function() change) async {
    if (saving) return;
    if (refreshJob != null) await refreshJob;
    if (!mounted) return;
    final backup = Match.fromJson(m.toJson()).toJson();
    setState(() => saving = true);
    try {
      change();
      await widget.save();
    } catch (e) {
      final old = Match.fromJson(backup);
      m.status = old.status;
      m.startedAt = old.startedAt;
      m.finishedAt = old.finishedAt;
      m.scheduledAt = old.scheduledAt;
      m.venue = old.venue;
      m.qualifiedTeamId = old.qualifiedTeamId;
      m.teams[0] = old.teams[0];
      m.teams[1] = old.teams[1];
      m.names
        ..clear()
        ..addAll(old.names);
      m.teamColors
        ..clear()
        ..addAll(old.teamColors);
      m.goals
        ..clear()
        ..addAll(old.goals);
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> goal() async {
    final g = await Navigator.push<Goal>(
        context,
        MaterialPageRoute(
            builder: (_) => GoalPage(league: widget.league, match: m)));
    if (g != null) await mutate(() => m.add(g));
  }

  Future<void> voidGoal(Goal g) async {
    if (await confirm(context, 'Annullare questo gol?',
        'Il punteggio e le statistiche verranno ricalcolati.')) {
      await mutate(() => m.undo(g.id));
    }
  }

  String get scheduledDetails {
    if (m.scheduledAt == null) {
      return 'Data e ora non indicate\n${statusName(m.status)}';
    }
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    final date = DateTime.parse(m.scheduledAt!).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final first =
        '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
    final second = [
      if (m.venue.isNotEmpty) m.venue,
      statusName(m.status),
    ].join(' · ');
    return '$first\n$second';
  }

  Widget scheduledBody() => ListView(
        key: const ValueKey('scheduled-match'),
        padding: const EdgeInsets.all(24),
        children: [
          _MatchScorePanel(match: m, details: scheduledDetails),
          const SizedBox(height: 12),
          Text(
              'Tempo partita · ${clockText(matchElapsed(m, DateTime.now().toUtc()))}',
              key: const ValueKey('match-clock'),
              style: const TextStyle(
                  fontSize: 20, height: 1.3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (widget.league.canRecord(m)) ...[
            AccountButton('Modifica data, ora e luogo',
                outline: true,
                onPressed: (saving || refreshing) ? null : editEvent),
            const SizedBox(height: 12),
            AccountButton('Inizia partita',
                onPressed: (saving || refreshing) ? null : startMatch),
            const SizedBox(height: 12),
          ],
          if (connectionWarning != null) ...[
            Text(connectionWarning!,
                style: const TextStyle(color: HaykoColors.mutedText)),
            const SizedBox(height: 12),
          ],
          const SyncNotice(),
        ],
      );

  String get liveDetails {
    if (m.scheduledAt == null) return statusName(m.status);
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    final date = DateTime.parse(m.scheduledAt!).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute · ${statusName(m.status)}';
  }

  Widget liveBody() {
    final now = DateTime.now().toUtc();
    final start = m.startedAt == null ? now : DateTime.parse(m.startedAt!);
    return ListView(
      key: const ValueKey('live-match'),
      padding: const EdgeInsets.all(24),
      children: [
        _MatchScorePanel(match: m, details: liveDetails),
        const SizedBox(height: 12),
        Text(clockText(matchElapsed(m, now)),
            key: const ValueKey('match-clock'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 48, height: 56 / 48, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (widget.league.canRecord(m)) ...[
          AccountButton('GOL', onPressed: (saving || refreshing) ? null : goal),
          const SizedBox(height: 12),
          AccountButton('Termina partita',
              outline: true,
              onPressed: (saving || refreshing) ? null : finishMatch),
          const SizedBox(height: 12),
        ],
        if (connectionWarning != null) ...[
          Text(connectionWarning!,
              style: const TextStyle(color: HaykoColors.mutedText)),
          const SizedBox(height: 12),
        ],
        const SyncNotice(),
        if (widget.league.type != 'competition' && !m.competitionRules) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var team = 0; team < 2; team++) ...[
                Expanded(
                    child: _LiveKeeperCard(
                        league: widget.league,
                        match: m,
                        team: team,
                        start: start,
                        now: now)),
                if (team == 0) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        const Text('Registro gol',
            style: TextStyle(
                fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
        if (m.goals.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('Nessun gol registrato.',
              style: TextStyle(
                  color: HaykoColors.mutedText, fontSize: 16, height: 1.5)),
        ],
        for (final g in m.goals.reversed) ...[
          const SizedBox(height: 12),
          _LiveGoalRow(
              league: widget.league,
              match: m,
              goal: g,
              enabled: !g.voided && widget.league.canRecord(m),
              onUndo: () => voidGoal(g)),
        ],
      ],
    );
  }

  String get finishedDetails {
    if (m.scheduledAt == null) return statusName(m.status);
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    final date = DateTime.parse(m.scheduledAt!).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute · ${statusName(m.status)}';
  }

  Widget finishedBody() {
    final end = m.finishedAt == null
        ? DateTime.now().toUtc()
        : DateTime.parse(m.finishedAt!);
    return ListView(
      key: const ValueKey('finished-match'),
      padding: const EdgeInsets.all(24),
      children: [
        _MatchScorePanel(match: m, details: finishedDetails),
        const SizedBox(height: 12),
        Text('Tempo partita · ${clockText(matchElapsed(m, end))}',
            key: const ValueKey('match-clock'),
            style: const TextStyle(
                fontSize: 20, height: 1.3, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (m.qualifiedTeamId != null) ...[
          Text(
              'Passa il turno: ${m.names[m.presetIds.indexOf(m.qualifiedTeamId)]}',
              style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 12),
        ],
        const Text('Registro gol',
            style: TextStyle(
                fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
        if (m.goals.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('Nessun gol registrato.',
              style: TextStyle(
                  color: HaykoColors.mutedText, fontSize: 16, height: 1.5)),
        ],
        for (final g in m.goals.reversed) ...[
          const SizedBox(height: 12),
          _LiveGoalRow(
              league: widget.league,
              match: m,
              goal: g,
              enabled: false,
              onUndo: () {}),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, widget.league),
      child: Scaffold(
          appBar:
              AppBar(toolbarHeight: 64, title: const Text('Partita'), actions: [
            if (widget.reload != null)
              IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh))
          ]),
          body: m.status == 'scheduled'
              ? scheduledBody()
              : m.status == 'live'
                  ? liveBody()
                  : m.status == 'finished'
                      ? finishedBody()
                      : ListView(padding: const EdgeInsets.all(20), children: [
                          Text(dateLabel(m.scheduledAt),
                              textAlign: TextAlign.center),
                          if (m.venue.isNotEmpty)
                            Text(m.venue, textAlign: TextAlign.center),
                          if (m.status == 'scheduled' &&
                              widget.league.canRecord(m))
                            TextButton.icon(
                                onPressed:
                                    (saving || refreshing) ? null : editEvent,
                                icon: const Icon(Icons.edit_calendar),
                                label:
                                    const Text('Modifica data, ora e luogo')),
                          Text(statusName(m.status),
                              textAlign: TextAlign.center),
                          if (connectionWarning != null)
                            Text(connectionWarning!),
                          const SyncNotice(),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var t = 0; t < 2; t++)
                                  Expanded(
                                      child: Column(children: [
                                    CircleAvatar(
                                        radius: 9,
                                        backgroundColor:
                                            Color(m.teamColors[t])),
                                    Text(m.names[t],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 22))
                                  ]))
                              ]),
                          Text('${m.score(0)} – ${m.score(1)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 72, fontWeight: FontWeight.bold)),
                          const Text('Tempo partita',
                              textAlign: TextAlign.center),
                          Text(
                              clockText(
                                  matchElapsed(m, DateTime.now().toUtc())),
                              key: const ValueKey('match-clock'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold)),
                          if (m.status == 'scheduled' &&
                              widget.league.canRecord(m))
                            FilledButton(
                                onPressed:
                                    (saving || refreshing) ? null : startMatch,
                                child: const Text('Inizia partita')),
                          if (m.status == 'live' &&
                              widget.league.canRecord(m)) ...[
                            FilledButton.icon(
                                onPressed: (saving || refreshing) ? null : goal,
                                icon: const Icon(Icons.sports_soccer),
                                label: const Text('GOL')),
                            TextButton(
                                onPressed:
                                    (saving || refreshing) ? null : finishMatch,
                                child: const Text('Termina partita')),
                          ],
                          if (m.qualifiedTeamId != null)
                            Text(
                                'Passa il turno: ${m.names[m.presetIds.indexOf(m.qualifiedTeamId)]}',
                                textAlign: TextAlign.center),
                          ...keeperCards(),
                          if (widget.league.type != 'competition' &&
                              m.status == 'live' &&
                              m.keepers.any((k) => k.mode == 'rotation'))
                            TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await RotationAlerts.instance
                                        .testNotification();
                                  } catch (e) {
                                    if (context.mounted) showError(context, e);
                                  }
                                  if (mounted) setState(() {});
                                },
                                icon: const Icon(Icons.notifications_active),
                                label: const Text('Prova avviso')),
                          if (RotationAlerts.instance.warning != null)
                            Text(RotationAlerts.instance.warning!),
                          if (widget.league.type != 'competition' &&
                              m.status == 'live' &&
                              m.keepers.any((k) => k.mode == 'rotation') &&
                              RotationAlerts.instance.scheduleInfo != null)
                            Text(RotationAlerts.instance.scheduleInfo!),
                          const SizedBox(height: 20),
                          const Text('Registro gol',
                              style: TextStyle(fontSize: 24)),
                          ...m.goals.reversed.map((g) => Card(
                              child: ListTile(
                                  title: Text(
                                      '${g.voided ? 'Annullato · ' : ''}${g.ownGoal ? 'Autogol' : 'Gol'} ${m.names[g.team]} · ${widget.league.playerName(g.scorer)}'),
                                  subtitle: Text(
                                      'Assist: ${widget.league.playerName(g.assist)}${widget.league.type == 'competition' || m.competitionRules ? '' : '\nIn porta: ${widget.league.playerName(g.keeper)}'}'),
                                  trailing: m.status == 'live' &&
                                          !g.voided &&
                                          widget.league.canRecord(m)
                                      ? IconButton(
                                          tooltip: 'Annulla gol',
                                          onPressed: (saving || refreshing)
                                              ? null
                                              : () => voidGoal(g),
                                          icon: const Icon(Icons.undo))
                                      : null))),
                        ])));
}

class _MatchScorePanel extends StatelessWidget {
  const _MatchScorePanel({required this.match, required this.details});

  final Match match;
  final String details;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('match-score-panel'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: _ScoreTeam(
                    name: match.names[0], color: match.teamColors[0])),
            SizedBox(
                width: 42,
                child: Text('${match.score(0)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w800))),
            const SizedBox(
                width: 12,
                child: Text('–',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: HaykoColors.mutedText,
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w700))),
            SizedBox(
                width: 42,
                child: Text('${match.score(1)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w800))),
            Expanded(
                child: _ScoreTeam(
                    name: match.names[1], color: match.teamColors[1])),
          ]),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: Text(details,
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 14,
                      height: 20 / 14))),
        ]),
      );
}

class _ScoreTeam extends StatelessWidget {
  const _ScoreTeam({required this.name, required this.color});

  final String name;
  final int color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(width: 56, height: 6, color: Color(color)),
      ]);
}

class _LiveKeeperCard extends StatelessWidget {
  const _LiveKeeperCard(
      {required this.league,
      required this.match,
      required this.team,
      required this.start,
      required this.now});

  final League league;
  final Match match;
  final int team;
  final DateTime start;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final plan = match.keepers[team];
    final current = plan.mode == 'fixed' ? plan.fixed : plan.at(start, now);
    final next = plan.mode == 'rotation'
        ? plan.at(start, plan.nextChange(start, now))
        : null;
    final countdown = plan.mode == 'rotation'
        ? clockText(plan.nextChange(start, now).difference(now))
        : null;
    return Container(
      constraints: const BoxConstraints(minHeight: 144),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: HaykoColors.fieldSurface,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(match.names[team],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Color(match.teamColors[team]),
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('In porta',
                style: TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(current == null ? 'Da scegliere' : league.playerName(current),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 20, height: 1.3, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                next == null
                    ? plan.mode == 'fixed'
                        ? 'Portiere fisso'
                        : 'Portiere a scelta'
                    : 'Successivo: ${league.playerName(next)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HaykoColors.mutedText,
                    fontSize: 14,
                    height: 20 / 14)),
            if (countdown != null) ...[
              const SizedBox(height: 4),
              Text(countdown,
                  key: ValueKey('keeper-countdown-$team'),
                  style: const TextStyle(
                      fontSize: 20, height: 1.3, fontWeight: FontWeight.w700)),
            ],
          ]),
    );
  }
}

class _LiveGoalRow extends StatelessWidget {
  const _LiveGoalRow(
      {required this.league,
      required this.match,
      required this.goal,
      required this.enabled,
      required this.onUndo});

  final League league;
  final Match match;
  final Goal goal;
  final bool enabled;
  final VoidCallback onUndo;

  Widget detail(IconData icon, String label, String value, {Key? key}) => Row(
        key: key,
        children: [
          Icon(icon, size: 16, color: HaykoColors.mutedText),
          const SizedBox(width: 6),
          Expanded(
              child: Text('$label: $value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600))),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
                left: BorderSide(
                    color: Color(match.teamColors[goal.team]), width: 4))),
        child: Row(children: [
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    goal.voided
                        ? 'Annullato · ${match.names[goal.team]}'
                        : match.names[goal.team],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                detail(
                    goal.ownGoal ? Icons.sync_problem : Icons.sports_soccer,
                    goal.ownGoal ? 'Autogol' : 'Marcatore',
                    league.playerName(goal.scorer),
                    key: const ValueKey('goal-scorer-detail')),
                if (!goal.ownGoal) ...[
                  const SizedBox(height: 4),
                  detail(Icons.directions_run, 'Assistman',
                      league.playerName(goal.assist),
                      key: const ValueKey('goal-assist-detail')),
                ],
                if (league.type != 'competition' &&
                    !match.competitionRules) ...[
                  const SizedBox(height: 4),
                  detail(Icons.sports_handball, 'Portiere',
                      league.playerName(goal.keeper),
                      key: const ValueKey('goal-keeper-detail')),
                ],
              ])),
          if (enabled)
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                  tooltip: 'Annulla gol',
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo, color: Color(0xffffb4ab))),
            ),
        ]),
      );
}
