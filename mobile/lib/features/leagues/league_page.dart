import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/features/matches/formation.dart';
import 'package:calcetto_mvp/features/statistics/statistics_page.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/features/leagues/league_settings.dart';
import 'package:calcetto_mvp/features/leagues/player_edit_page.dart';
import 'package:calcetto_mvp/features/competitions/competition_hub.dart';
import 'package:calcetto_mvp/features/teams/team_presets_page.dart';
import 'package:calcetto_mvp/features/account/settings_page.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'dart:async';

import 'package:calcetto_mvp/features/matches/match_page.dart';

class LeaguePage extends StatefulWidget {
  final League league;
  final Save save;
  final Save? reload;
  final Save? onDelete;
  final int initialTab;
  final bool openPlayersAndInvites;
  const LeaguePage(
      {super.key,
      required this.league,
      required this.save,
      this.reload,
      this.onDelete,
      this.initialTab = 0,
      this.openPlayersAndInvites = false});
  @override
  State<LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<LeaguePage> with WidgetsBindingObserver {
  int tab = 0;
  String matchStatus = 'scheduled';
  String finishedPeriod = 'all';
  int finishedVisible = 10;
  Timer? listClock;
  Timer? remoteClock;
  Timer? requestsClock;
  bool hasPendingRequests = false;
  bool checkingRequests = false;
  bool refreshingLeague = false;
  League get l => widget.league;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.reload != null) unawaited(refreshInitialLeague());
      if (mounted && widget.openPlayersAndInvites) {
        unawaited(openLeagueSocial());
      }
    });
    listClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && l.matches.any((m) => m.status == 'live')) setState(() {});
    });
    if (widget.reload != null) {
      remoteClock = Timer.periodic(
          const Duration(seconds: 5), (_) => unawaited(refreshLeagueState()));
    }
    if (l.shared && l.manage) {
      unawaited(refreshPendingRequests());
      requestsClock = Timer.periodic(const Duration(seconds: 15),
          (_) => unawaited(refreshPendingRequests()));
    }
    matchStatus = initialMatchStatus(l);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshLeagueState());
    }
  }

  Future<void> refreshInitialLeague() async {
    try {
      await widget.reload?.call();
      await refreshPendingRequests();
      if (mounted) setState(() => matchStatus = initialMatchStatus(l));
    } catch (_) {
      // L'apertura usa i dati locali e il prossimo aggiornamento ritenta.
    }
  }

  Future<void> refreshLeagueState() async {
    if (refreshingLeague || widget.reload == null) return;
    refreshingLeague = true;
    final previous = {for (final match in l.matches) match.id: match.status};
    try {
      await widget.reload!.call();
      if (!mounted) return;
      final started = l.matches.any(
          (match) => match.status == 'live' && previous[match.id] != 'live');
      final finished = l.matches.any((match) =>
          match.status == 'finished' && previous[match.id] == 'live');
      setState(() {
        if (started) {
          matchStatus = 'live';
        } else if (finished &&
            !l.matches.any((match) => match.status == 'live')) {
          matchStatus = 'finished';
        }
      });
    } catch (_) {
      // La pagina continua a mostrare l'ultimo stato disponibile e ritenta.
    } finally {
      refreshingLeague = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    listClock?.cancel();
    remoteClock?.cancel();
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
    final statusMatches =
        l.matches.reversed.where((m) => m.status == matchStatus).toList();
    final finishedYears = statusMatches
        .map(_matchHistoryYear)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final hasUndated =
        statusMatches.any((match) => _matchHistoryYear(match) == null);
    final validPeriods = <String>{
      'all',
      ...finishedYears.map((year) => '$year'),
      if (hasUndated) 'undated',
    };
    final activePeriod =
        validPeriods.contains(finishedPeriod) ? finishedPeriod : 'all';
    final filteredMatches = matchStatus != 'finished' || activePeriod == 'all'
        ? statusMatches
        : statusMatches.where((match) {
            final year = _matchHistoryYear(match);
            return activePeriod == 'undated'
                ? year == null
                : year?.toString() == activePeriod;
          }).toList();
    final matches = matchStatus == 'finished'
        ? filteredMatches.take(finishedVisible).toList()
        : filteredMatches;
    final hiddenFinished = filteredMatches.length - matches.length;
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
                  onTap: () => setState(() {
                    matchStatus = status;
                    if (status == 'finished') finishedVisible = 10;
                  }),
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
      if (matchStatus == 'finished')
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: HaykoColors.fieldSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaykoColors.fieldLine),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_month,
                  size: 22, color: HaykoColors.mutedText),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Periodo',
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('finished-period-filter'),
                  value: activePeriod,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Tutte')),
                    for (final year in finishedYears)
                      DropdownMenuItem(value: '$year', child: Text('$year')),
                    if (hasUndated)
                      const DropdownMenuItem(
                          value: 'undated', child: Text('Senza data')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      finishedPeriod = value;
                      finishedVisible = 10;
                    });
                  },
                ),
              ),
            ]),
          ),
        ),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
              children: [
            if (matches.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Nessuna partita ${matchStatus == 'live' ? 'in corso' : matchStatus == 'scheduled' ? 'programmata' : 'terminata'}.')),
            for (final match in matches) ...[
              _MatchScoreCard(
                  league: l,
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
            if (hiddenFinished > 0) ...[
              _LeagueOutlineButton(
                label: 'Mostra altre (${hiddenFinished.clamp(0, 10)})',
                onPressed: () => setState(() => finishedVisible += 10),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${matches.length} di ${filteredMatches.length} partite',
                  style: const TextStyle(
                      color: HaykoColors.mutedText,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ])),
    ]);
  }

  Future<void> addPlayer() async {
    final result = await Navigator.push<PlayerEditResult>(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerEditPage(
                name: '',
                color: l.primaryColor,
                creating: true,
                unavailableNames: l.players.map((p) => p.name).toList())));
    if (result == null) return;
    final name = result.name.trim();
    if (name.isEmpty ||
        l.players
            .any((player) => player.name.toLowerCase() == name.toLowerCase())) {
      if (mounted) showError(context, 'Inserisci un nome nuovo e non vuoto.');
      return;
    }
    final p = Player(newId(), name, color: result.color);
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
    final usedInMatches = l.matches.any((match) =>
        match.teams.any((team) => team.contains(p.id)) ||
        match.goals.any((goal) =>
            goal.scorer == p.id || goal.assist == p.id || goal.keeper == p.id));
    final usedInTeams = l.presets.any((team) => team.players.contains(p.id));
    final linkedAccount = l.myPlayer == p.id || l.roles.containsKey(p.id);
    final blockedReason = linkedAccount
        ? 'Questo giocatore è associato a un account. Rimuovi prima il giocatore da Giocatori e inviti.'
        : usedInMatches || usedInTeams
            ? 'Questo giocatore è presente in partite o squadre salvate e non può essere eliminato.'
            : null;
    final change = await Navigator.push<PlayerEditResult>(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerEditPage(
                name: p.name,
                color: p.color,
                deletionBlockedReason: blockedReason)));
    if (change == null) return;
    if (change.deleted) {
      final index = l.players.indexOf(p);
      l.players.remove(p);
      try {
        await widget.save();
      } catch (e) {
        l.players.insert(index, p);
        if (mounted) showError(context, e);
      }
      if (mounted) setState(() {});
      return;
    }
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

  Future<void> openSavedTeams() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TeamPresetsPage(league: l, save: widget.save)));
    if (mounted) setState(() {});
  }

  Widget playersBody() {
    final players = List<Player>.from(l.players)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ListView(
      // Keeps the final edit action clear of the 48 px floating button and
      // its Scaffold margin at every scroll position.
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 88),
      children: [
        _LeagueOutlineButton(
            label: 'Squadre salvate', onPressed: openSavedTeams),
        if (l.shared) ...[
          const SizedBox(height: 12),
          _LeagueOutlineButton(
              label: 'Giocatori e inviti',
              showNotification: hasPendingRequests,
              onPressed: openLeagueSocial),
        ],
        const SizedBox(height: 12),
        const Text('Giocatori della lega',
            style: TextStyle(
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: HaykoColors.chalk)),
        const SizedBox(height: 12),
        for (var index = 0; index < players.length; index++) ...[
          _LeaguePlayerRow(
            player: players[index],
            subtitle: l.shared && l.roles[players[index].id] != null
                ? roleName(l.roles[players[index].id])
                : 'Giocatore',
            isCurrent: l.shared && l.myPlayer == players[index].id,
            canEdit: l.manage ||
                (l.type == 'amateur' && l.myPlayer == players[index].id),
            onEdit: () => rename(players[index]),
          ),
          if (index != players.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, l),
      child: Scaffold(
          appBar: AppBar(
              toolbarHeight: 64,
              leading: IconButton(
                  tooltip: 'Le tue leghe',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home_outlined)),
              title: Text(l.name),
              actions: [
                if (l.manage)
                  IconButton(
                      tooltip: 'Impostazioni lega',
                      onPressed: openLeagueSettings,
                      icon: const Icon(Icons.tune)),
                IconButton(
                    tooltip: 'Impostazioni app',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage())),
                    icon: const Icon(Icons.settings)),
                const SizedBox(width: 8),
              ]),
          body: RefreshIndicator(
              onRefresh: reloadLeague,
              child: tab == 3 && l.type == 'competition'
                  ? CompetitionCalendar(
                      league: l,
                      save: widget.save,
                      changed: () => setState(() {}))
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
                              : playersBody()),
          floatingActionButton: !l.manage
              ? null
              : tab == 0
                  ? _CompactLeagueFab(label: '+ Partita', onPressed: newMatch)
                  : tab == 1 && l.type == 'amateur'
                      ? _CompactLeagueFab(
                          label: '+ Giocatore', onPressed: addPlayer)
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
                      icon: Stack(clipBehavior: Clip.none, children: [
                        const Icon(Icons.groups),
                        if (hasPendingRequests)
                          Positioned(
                            key: const ValueKey('players-footer-request-dot'),
                            right: -5,
                            top: -4,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xffff7a3d),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ]),
                      label: l.type == 'competition' ? 'Squadre' : 'Giocatori'),
                  const NavigationDestination(
                      icon: Icon(Icons.bar_chart), label: 'Statistiche'),
                  if (l.type == 'competition')
                    const NavigationDestination(
                        icon: Icon(Icons.calendar_month), label: 'Calendario')
                ]),
          )));
}

String initialMatchStatus(League league) =>
    league.matches.any((match) => match.status == 'live')
        ? 'live'
        : 'scheduled';

class _MatchScoreCard extends StatelessWidget {
  const _MatchScoreCard(
      {required this.league, required this.match, required this.onTap});
  final League league;
  final Match match;
  final VoidCallback onTap;

  String get details {
    final competition = league.type == 'competition';
    final lines = <String>[
      competition
          ? '${competitionRoundLabel(league, match)} · ${match.format}v${match.format}'
          : '${_friendlyDate(match.scheduledAt)} · ${match.format} vs ${match.format}',
      if (match.status == 'live')
        'Tempo partita: ${clockText(matchElapsed(match, DateTime.now().toUtc()))}'
      else if (competition)
        _friendlyDate(match.scheduledAt),
      if (match.venue.isNotEmpty) match.venue,
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

class _CompactLeagueFab extends StatelessWidget {
  const _CompactLeagueFab({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          elevation: 2,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          label: Text(label,
              style: const TextStyle(
                  fontFamily: 'BricolageGrotesque',
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0)),
        ),
      );
}

class _LeagueOutlineButton extends StatelessWidget {
  const _LeagueOutlineButton(
      {required this.label,
      required this.onPressed,
      this.showNotification = false});
  final String label;
  final VoidCallback onPressed;
  final bool showNotification;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
              backgroundColor: HaykoColors.fieldSurface,
              foregroundColor: HaykoColors.chalk,
              side: const BorderSide(color: HaykoColors.fieldLine),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontFamily: 'BricolageGrotesque',
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label),
            if (showNotification) ...[
              const SizedBox(width: 8),
              Container(
                  key: const ValueKey('players-invite-request-dot'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xffff7a3d), shape: BoxShape.circle)),
            ],
          ]),
        ),
      );
}

class _LeaguePlayerRow extends StatelessWidget {
  const _LeaguePlayerRow(
      {required this.player,
      required this.subtitle,
      required this.isCurrent,
      required this.canEdit,
      required this.onEdit});
  final Player player;
  final String subtitle;
  final bool isCurrent;
  final bool canEdit;
  final VoidCallback onEdit;

  String get initials {
    final words = player.name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12),
            border: isCurrent ? Border.all(color: HaykoColors.chalk) : null),
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
                            height: 16 / 12,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${player.name}${isCurrent ? ' · Tu' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w400)),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: HaykoColors.mutedText,
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ]),
            ),
          ),
          if (canEdit)
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                  tooltip: 'Modifica giocatore',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 24)),
            ),
        ]),
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

int? _matchHistoryYear(Match match) {
  final value = match.finishedAt ?? match.scheduledAt ?? match.startedAt;
  return value == null ? null : DateTime.tryParse(value)?.toLocal().year;
}
