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
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Row(children: [
          for (final status in ['scheduled', 'live', 'finished']) ...[
            if (status != 'scheduled') const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                selected: matchStatus == status,
                button: true,
                child: InkWell(
                  key: ValueKey('match-tab-$status'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => matchStatus = status),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                        color: matchStatus == status
                            ? HaykoColors.fieldLine
                            : HaykoColors.fieldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor(status))),
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
                                    height: 16 / 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor(status))),
                          ),
                          if (status == 'live' &&
                              l.matches.any((m) => m.status == 'live')) ...[
                            const SizedBox(width: 4),
                            Container(
                                key: const ValueKey('live-match-dot'),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: statusColor(status),
                                    shape: BoxShape.circle)),
                          ],
                        ]),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'Partite ${matchStatus == 'live' ? 'in corso' : matchStatus == 'scheduled' ? 'programmate' : 'terminate'}',
              style: TextStyle(
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
      ),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
            if (matches.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Nessuna partita ${matchStatus == 'live' ? 'in corso' : matchStatus == 'scheduled' ? 'programmata' : 'terminata'}.')),
            for (final match in matches) ...[
              _MatchScoreCard(
                  match: match,
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MatchPage(
                                league: l,
                                match: match,
                                save: widget.save,
                                reload: widget.reload)));
                    if (mounted) setState(() => matchStatus = match.status);
                  }),
              const SizedBox(height: 12),
            ],
            if (l.manage)
              AccountButton(l.type == 'amateur' ? '+ Partita' : 'Partita',
                  onPressed: newMatch),
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

  Future<void> openLeagueSettings() async {
    final deleted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => LeagueSettingsPage(
                league: l, save: widget.save, delete: widget.onDelete)));
    if (!mounted) return;
    if (deleted == true) {
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  Future<void> reloadLeague() async {
    try {
      await widget.reload?.call();
      await refreshPendingRequests();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> openLeagueSocial() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => LeagueSocial(league: l)));
    await refreshPendingRequests();
    if (mounted) setState(() {});
  }

  Future<void> selectLeagueAction(String action) async {
    if (action == 'settings') await openLeagueSettings();
    if (action == 'refresh') await reloadLeague();
    if (action == 'social') await openLeagueSocial();
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, l),
      child: Scaffold(
          appBar: AppBar(toolbarHeight: 64, title: Text(l.name), actions: [
            PopupMenuButton<String>(
              tooltip: 'Azioni lega',
              onSelected: selectLeagueAction,
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.more_vert),
                if (hasPendingRequests)
                  Positioned(
                      key: const ValueKey('member-request-dot'),
                      right: -2,
                      top: -2,
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xffff7a3d),
                              shape: BoxShape.circle))),
              ]),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.settings_outlined),
                        title: Text('Impostazioni lega'))),
                if (l.shared)
                  const PopupMenuItem(
                      value: 'refresh',
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.refresh),
                          title: Text('Aggiorna'))),
                if (l.shared)
                  PopupMenuItem(
                      value: 'social',
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Stack(clipBehavior: Clip.none, children: [
                            const Icon(Icons.group_add_outlined),
                            if (hasPendingRequests)
                              Positioned(
                                  right: -3,
                                  top: -3,
                                  child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                          color: Color(0xffff7a3d),
                                          shape: BoxShape.circle))),
                          ]),
                          title: const Text('Giocatori e inviti'))),
              ],
            ),
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
          floatingActionButton: tab == 1 && l.manage && l.type == 'amateur'
              ? FloatingActionButton.extended(
                  onPressed: addPlayer,
                  icon: const Icon(Icons.add),
                  label: const Text('Giocatore'))
              : null,
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarTheme.of(context).copyWith(
                height: 84,
                backgroundColor: HaykoColors.fieldSurface,
                indicatorColor: HaykoColors.fieldLine,
                indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                    TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600,
                        color: states.contains(WidgetState.selected)
                            ? HaykoColors.chalk
                            : HaykoColors.mutedText))),
            child: NavigationBar(
                selectedIndex: tab,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                ]),
          )));
}

class _MatchScoreCard extends StatelessWidget {
  const _MatchScoreCard({required this.match, required this.onTap});
  final Match match;
  final VoidCallback onTap;

  String get details {
    final lines = <String>[
      '${_friendlyDate(match.scheduledAt)} · ${match.format} vs ${match.format}',
      if (match.venue.isNotEmpty) match.venue,
      if (match.status == 'live')
        'Tempo partita: ${clockText(matchElapsed(match, DateTime.now().toUtc()))}',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: _MatchTeam(
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
                    child: _MatchTeam(
                        name: match.names[1], color: match.teamColors[1])),
              ]),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(details,
                      style: const TextStyle(
                          color: HaykoColors.mutedText,
                          fontSize: 14,
                          height: 20 / 14))),
            ]),
          ),
        ),
      );
}

class _MatchTeam extends StatelessWidget {
  const _MatchTeam({required this.name, required this.color});
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

String _friendlyDate(String? value) {
  if (value == null) return 'Data e ora non indicate';
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
  final date = DateTime.parse(value).toLocal();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
}
