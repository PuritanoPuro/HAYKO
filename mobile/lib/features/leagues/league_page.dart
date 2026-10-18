import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/features/statistics/statistics_page.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/leagues/league_settings.dart';
import 'package:calcetto_mvp/features/competitions/competition_hub.dart';
import 'package:calcetto_mvp/features/teams/team_presets_page.dart';
import 'dart:async';

import 'package:calcetto_mvp/features/matches/match_page.dart';

class LeaguePage extends StatefulWidget {
  final League league;
  final Save save;
  final Save? reload;
  final Save? onDelete;
  const LeaguePage(
      {super.key,
      required this.league,
      required this.save,
      this.reload,
      this.onDelete});
  @override
  State<LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<LeaguePage> {
  int tab = 0;
  String matchStatus = 'scheduled';
  Timer? listClock;
  Timer? requestsClock;
  bool hasPendingRequests = false;
  bool checkingRequests = false;
  League get l => widget.league;
  @override
  void initState() {
    super.initState();
    listClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && l.matches.any((m) => m.status == 'live')) setState(() {});
    });
    if (l.shared && l.manage) {
      unawaited(refreshPendingRequests());
      requestsClock = Timer.periodic(const Duration(seconds: 15),
          (_) => unawaited(refreshPendingRequests()));
    }
    if (l.matches.any((m) => m.status == 'live')) {
      matchStatus = 'live';
    } else if (!l.matches.any((m) => m.status == 'scheduled') &&
        l.matches.any((m) => m.status == 'finished')) {
      matchStatus = 'finished';
    }
  }

  @override
  void dispose() {
    listClock?.cancel();
    requestsClock?.cancel();
    super.dispose();
  }

  Future<void> refreshPendingRequests() async {
    if (!l.shared || !l.manage || checkingRequests) return;
    checkingRequests = true;
    try {
      final pending =
          await Cloud.client.rpc('hayko_requests', params: {'p_id': l.id});
      final visible = (pending as List).isNotEmpty;
      if (mounted && visible != hasPendingRequests) {
        setState(() => hasPendingRequests = visible);
      }
    } catch (_) {
      // The league remains usable offline; the dot is refreshed on retry.
    } finally {
      checkingRequests = false;
    }
  }

  Color statusColor(String status) => status == 'live'
      ? const Color(0xffa8e86b)
      : status == 'scheduled'
          ? const Color(0xff8ebcff)
          : const Color(0xffbcb6c9);
  Widget matchesBody() {
    final color = statusColor(matchStatus);
    final matches =
        l.matches.reversed.where((m) => m.status == matchStatus).toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            for (final status in ['scheduled', 'live', 'finished'])
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                          selected: matchStatus == status,
                          button: true,
                          child: InkWell(
                            key: ValueKey('match-tab-$status'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => matchStatus = status),
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 3),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: matchStatus == status
                                        ? statusColor(status)
                                            .withValues(alpha: 0.18)
                                        : null,
                                    border: Border.all(
                                        color: matchStatus == status
                                            ? statusColor(status)
                                            : Theme.of(context).dividerColor)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                          child: Text(
                                              status == 'scheduled'
                                                  ? 'Programmate'
                                                  : status == 'live'
                                                      ? 'In corso'
                                                      : 'Terminate',
                                              maxLines: 1,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: statusColor(status)))),
                                      if (status == 'live' &&
                                          l.matches.any(
                                              (m) => m.status == 'live')) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                            key: const ValueKey(
                                                'live-match-dot'),
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                                color: statusColor(status),
                                                shape: BoxShape.circle)),
                                      ],
                                    ])),
                          )))),
          ])),
      Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(
                matchStatus == 'live'
                    ? Icons.play_circle
                    : matchStatus == 'scheduled'
                        ? Icons.calendar_today
                        : Icons.check_circle,
                color: color),
            const SizedBox(width: 8),
            Text(
                'Partite ${matchStatus == 'live' ? 'in corso' : matchStatus == 'scheduled' ? 'programmate' : 'terminate'}',
                style: TextStyle(fontSize: 22, color: color)),
          ])),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
            if (matches.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Nessuna partita ${matchStatus == 'live' ? 'in corso' : matchStatus == 'scheduled' ? 'programmata' : 'terminata'}.')),
            ...matches.map((m) => Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color)),
                child: ListTile(
                    title: Text(
                        '${m.names[0]} ${m.score(0)} – ${m.score(1)} ${m.names[1]}'),
                    subtitle: Text(
                        '${m.competitionId == null ? '' : '${l.type == 'competition' && m.competitionId != null ? competitionRoundLabel(l, m) : competitionLabel(l, m)}\n'}${m.format} vs ${m.format} · ${statusName(m.status)}\n${dateLabel(m.scheduledAt)}${m.venue.isEmpty ? '' : ' · ${m.venue}'}${m.status == 'live' ? '\nTempo partita: ${clockText(matchElapsed(m, DateTime.now().toUtc()))}' : ''}'),
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                          radius: 8, backgroundColor: Color(m.teamColors[0])),
                      const SizedBox(width: 4),
                      CircleAvatar(
                          radius: 8, backgroundColor: Color(m.teamColors[1]))
                    ]),
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MatchPage(
                                  league: l,
                                  match: m,
                                  save: widget.save,
                                  reload: widget.reload)));
                      if (mounted) setState(() => matchStatus = m.status);
                    }))),
          ])),
    ]);
  }

  Future<void> addPlayer() async {
    final name = await askText(context, 'Nome giocatore');
    if (name == null) return;
    final p = Player(newId(), name);
    l.players.add(p);
    try {
      await widget.save();
    } catch (e) {
      l.players.remove(p);
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() {});
  }

  Future<void> rename(Player p) async {
    final change =
        await editIdentity(context, 'Modifica giocatore', p.name, p.color);
    if (change == null) return;
    final name = p.name, color = p.color;
    p.name = change.name;
    p.color = change.color;
    try {
      await widget.save();
    } catch (e) {
      p.name = name;
      p.color = color;
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() {});
  }

  Future<void> newMatch() async {
    if (l.type == 'competition') {
      setState(() => tab = 3);
      return;
    }
    final m = await Navigator.push<Match>(
        context,
        MaterialPageRoute(
            builder: (_) => NewMatchPage(
                league: l,
                save: widget.save,
                initialCompetition:
                    l.type == 'competition' && l.competitions.isNotEmpty
                        ? l.competitions.first.id
                        : null)));
    if (m == null) return;
    try {
      validateCompetitionMatch(l, m);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    l.matches.add(m);
    matchStatus = 'scheduled';
    try {
      await widget.save();
    } catch (e) {
      l.matches.remove(m);
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, l),
      child: Scaffold(
          appBar: AppBar(title: Text(l.name), actions: [
            IconButton(
                tooltip: 'Impostazioni lega',
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final deleted = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LeagueSettingsPage(
                              league: l,
                              save: widget.save,
                              delete: widget.onDelete)));
                  if (!context.mounted) return;
                  if (deleted == true) {
                    Navigator.pop(context);
                  } else {
                    setState(() {});
                  }
                }),
            if (l.shared)
              IconButton(
                  tooltip: 'Aggiorna',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    try {
                      await widget.reload?.call();
                      await refreshPendingRequests();
                      if (mounted) setState(() {});
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  }),
            if (l.shared)
              IconButton(
                  tooltip: 'Giocatori e inviti',
                  icon: Stack(clipBehavior: Clip.none, children: [
                    const Icon(Icons.group_add),
                    if (hasPendingRequests)
                      Positioned(
                        key: const ValueKey('member-request-dot'),
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                              color: Color(0xffff7a3d), shape: BoxShape.circle),
                        ),
                      ),
                  ]),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LeagueSocial(league: l)));
                    await refreshPendingRequests();
                    if (mounted) setState(() {});
                  }),
          ]),
          body: tab == 3 && l.type == 'competition'
              ? CompetitionCalendar(
                  league: l, save: widget.save, changed: () => setState(() {}))
              : tab == 2
                  ? (l.type == 'competition'
                      ? CompetitionStatistics(league: l)
                      : StatisticsPage(league: l))
                  : tab == 0
                      ? matchesBody()
                      : l.type == 'competition'
                          ? CompetitionTeams(
                              league: l,
                              save: widget.save,
                              changed: () => setState(() {}))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                  OutlinedButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => TeamPresetsPage(
                                                    league: l,
                                                    save: widget.save)));
                                        if (mounted) setState(() {});
                                      },
                                      icon: const Icon(Icons.groups),
                                      label: const Text('Squadre salvate')),
                                  const Text('Giocatori della lega',
                                      style: TextStyle(fontSize: 24)),
                                  ...(List<Player>.from(l.players)
                                        ..sort((a, b) => a.name
                                            .toLowerCase()
                                            .compareTo(b.name.toLowerCase())))
                                      .map((p) => ListTile(
                                          leading: CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Color(p.color),
                                              child: Icon(Icons.person,
                                                  color: contrastColor(p.color),
                                                  size: 18)),
                                          title: Text(p.name),
                                          subtitle: l.shared &&
                                                  l.roles[p.id] != null
                                              ? Text(roleName(l.roles[p.id]))
                                              : null,
                                          trailing:
                                              l.manage || (l.type == 'amateur' && l.myPlayer == p.id)
                                                  ? IconButton(
                                                      tooltip: 'Modifica nome',
                                                      icon: const Icon(Icons.edit),
                                                      onPressed: () => rename(p))
                                                  : null)),
                                ]),
          floatingActionButton:
              tab >= 2 || !l.manage || (tab == 1 && l.type == 'competition')
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: tab == 1 ? addPlayer : newMatch,
                      icon: const Icon(Icons.add),
                      label: Text(tab == 1 ? 'Giocatore' : 'Partita')),
          bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.sports_soccer), label: 'Partite'),
                NavigationDestination(
                    icon: const Icon(Icons.groups),
                    label: l.type == 'competition' ? 'Squadre' : 'Giocatori'),
                const NavigationDestination(
                    icon: Icon(Icons.bar_chart), label: 'Statistiche'),
                if (l.type == 'competition')
                  const NavigationDestination(
                      icon: Icon(Icons.calendar_month), label: 'Calendario')
              ])));
}
