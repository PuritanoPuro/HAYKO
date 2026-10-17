import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/settings_page.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/goal_page.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/shared/customization.dart';
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
            builder: (c, set) => AlertDialog(
                    title: const Text('Modifica dettagli partita'),
                    content: SingleChildScrollView(
                        child: EventDetailsFields(
                            date: date,
                            venue: location,
                            changed: (v) => set(() => date = v))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Annulla')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Salva'))
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
          builder: (c) =>
              SimpleDialog(title: const Text('Chi passa il turno?'), children: [
                for (var t = 0; t < 2; t++)
                  SimpleDialogOption(
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

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, widget.league),
      child: Scaffold(
          appBar: AppBar(title: const Text('Partita'), actions: [
            if (widget.reload != null)
              IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh))
          ]),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Text(dateLabel(m.scheduledAt), textAlign: TextAlign.center),
            if (m.venue.isNotEmpty) Text(m.venue, textAlign: TextAlign.center),
            if (m.status == 'scheduled' && widget.league.canRecord(m))
              TextButton.icon(
                  onPressed: (saving || refreshing) ? null : editEvent,
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Modifica data, ora e luogo')),
            Text(statusName(m.status), textAlign: TextAlign.center),
            if (connectionWarning != null) Text(connectionWarning!),
            const SyncNotice(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var t = 0; t < 2; t++)
                Expanded(
                    child: Column(children: [
                  CircleAvatar(
                      radius: 9, backgroundColor: Color(m.teamColors[t])),
                  Text(m.names[t],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22))
                ]))
            ]),
            Text('${m.score(0)} – ${m.score(1)}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 72, fontWeight: FontWeight.bold)),
            const Text('Tempo partita', textAlign: TextAlign.center),
            Text(clockText(matchElapsed(m, DateTime.now().toUtc())),
                key: const ValueKey('match-clock'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            if (m.status == 'scheduled' && widget.league.canRecord(m))
              FilledButton(
                  onPressed: (saving || refreshing) ? null : startMatch,
                  child: const Text('Inizia partita')),
            if (m.status == 'live' && widget.league.canRecord(m)) ...[
              FilledButton.icon(
                  onPressed: (saving || refreshing) ? null : goal,
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('GOL')),
              TextButton(
                  onPressed: (saving || refreshing) ? null : finishMatch,
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
                      await RotationAlerts.instance.testNotification();
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
            const Text('Registro gol', style: TextStyle(fontSize: 24)),
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
