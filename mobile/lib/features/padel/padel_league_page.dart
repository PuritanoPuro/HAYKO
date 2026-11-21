import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/core/domain/padel_scoring.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/account/settings_page.dart';
import 'package:calcetto_mvp/features/leagues/player_edit_page.dart';
import 'package:calcetto_mvp/features/leagues/league_settings.dart';
import 'package:calcetto_mvp/features/matches/match_page.dart';
import 'package:calcetto_mvp/features/padel/padel_couples_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_players_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_scheduled_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_live_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_round_complete_page.dart';
import 'package:calcetto_mvp/features/padel/padel_americano_standings_page.dart';
import 'package:calcetto_mvp/features/padel/padel_live_match_page.dart';
import 'package:calcetto_mvp/features/padel/padel_match_stats_page.dart';
import 'package:calcetto_mvp/features/padel/padel_match_creation_page.dart';
import 'package:calcetto_mvp/features/padel/padel_statistics_section.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/shared/presentation.dart';
import 'package:calcetto_mvp/shared/ui.dart';

class PadelLeaguePage extends StatefulWidget {
  const PadelLeaguePage({
    super.key,
    required this.league,
    required this.save,
    this.reload,
    this.updateOwnPlayer,
    this.onDelete,
  });

  final League league;
  final Save save;
  final Save? reload;
  final Future<void> Function(String name, int color)? updateOwnPlayer;
  final Save? onDelete;

  @override
  State<PadelLeaguePage> createState() => _PadelLeaguePageState();
}

class _PadelLeaguePageState extends State<PadelLeaguePage> {
  int tab = 0;
  String matchStatus = 'scheduled';
  Timer? listClock;

  @override
  void initState() {
    super.initState();
    matchStatus = widget.league.matches
                .any((match) => match.status == 'live') ||
            widget.league.competitions.any((competition) =>
                competition.kind == 'americano' &&
                ['live', 'paused'].contains(competition.americanoTurnStatus))
        ? 'live'
        : 'scheduled';
    listClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.league.matches.any((match) => match.status == 'live')) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    listClock?.cancel();
    super.dispose();
  }

  Future<void> newMatch() async {
    final match = await Navigator.push<Match>(
        context,
        MaterialPageRoute(
            builder: (_) => PadelMatchCreationPage(
                league: widget.league, save: widget.save)));
    if (match == null) return;
    widget.league.matches.add(match);
    matchStatus = 'scheduled';
    try {
      await widget.save();
    } catch (error) {
      widget.league.matches.remove(match);
      if (mounted) showError(context, error);
    }
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
                unavailableNames: widget.league.players
                    .map((player) => player.name)
                    .toList())));
    if (result == null || result.deleted) return;
    final player = Player(newId(), result.name, color: result.color);
    widget.league.players.add(player);
    try {
      await widget.save();
    } catch (error) {
      widget.league.players.remove(player);
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() {});
  }

  Future<void> editPlayer(Player player) async {
    final linkedAccount = widget.league.myPlayer == player.id ||
        widget.league.roles.containsKey(player.id);
    final used = widget.league.presets
            .any((couple) => couple.players.contains(player.id)) ||
        widget.league.competitions.any((competition) =>
            competition.americanoPlayerIds.contains(player.id)) ||
        widget.league.matches.any(
            (match) => match.teams.any((team) => team.contains(player.id)));
    final result = await Navigator.push<PlayerEditResult>(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerEditPage(
                name: player.name,
                color: player.color,
                padel: true,
                unavailableNames: widget.league.players
                    .where((candidate) => candidate.id != player.id)
                    .map((candidate) => candidate.name)
                    .toList(),
                deletionBlockedReason: linkedAccount
                    ? 'Questo giocatore è associato a un account e non può essere eliminato da qui.'
                    : used
                        ? 'Questo giocatore è presente in partite o coppie salvate e non può essere eliminato.'
                        : null)));
    if (result == null) return;
    if (result.deleted) {
      final index = widget.league.players.indexOf(player);
      widget.league.players.remove(player);
      try {
        await widget.save();
      } catch (error) {
        widget.league.players.insert(index, player);
        if (mounted) showError(context, error);
      }
    } else {
      final oldName = player.name;
      final oldColor = player.color;
      player.name = result.name;
      player.color = result.color;
      try {
        if (widget.league.shared &&
            widget.league.myPlayer == player.id &&
            widget.updateOwnPlayer != null) {
          await widget.updateOwnPlayer!(result.name, result.color);
        } else {
          await widget.save();
        }
      } catch (error) {
        player.name = oldName;
        player.color = oldColor;
        if (mounted) showError(context, error);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> openCouples() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                PadelCouplesPage(league: widget.league, save: widget.save)));
    if (mounted) setState(() {});
  }

  Future<void> openAmericanoPlayers() async {
    final competitions = widget.league.competitions
        .where((competition) => competition.kind == 'americano')
        .toList();
    if (competitions.isEmpty) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PadelAmericanoPlayersPage(
          league: widget.league,
          competition: competitions.first,
          save: widget.save,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> openMembers() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => LeagueSocial(league: widget.league)));
    if (mounted) setState(() {});
  }

  Future<void> reloadLeague() async {
    try {
      await widget.reload?.call();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> openLeagueSettings() async {
    final deleted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => LeagueSettingsPage(
                league: widget.league,
                save: widget.save,
                delete: widget.onDelete)));
    if (!mounted) return;
    if (deleted == true) {
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          leading: IconButton(
              tooltip: 'Le tue leghe',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_outlined)),
          title: Text(widget.league.name),
          actions: [
            if (widget.league.manage)
              IconButton(
                  tooltip: 'Impostazioni lega',
                  onPressed: openLeagueSettings,
                  icon: const Icon(Icons.tune)),
            IconButton(
                tooltip: 'Impostazioni app',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage())),
                icon: const Icon(Icons.settings)),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: reloadLeague,
          child: SafeArea(
            top: false,
            child: IndexedStack(
              index: tab,
              children: [
                _PadelMatchesSection(
                    league: widget.league,
                    status: matchStatus,
                    onStatusChanged: (value) =>
                        setState(() => matchStatus = value),
                    save: widget.save,
                    reload: widget.reload),
                _PlayersSection(
                    league: widget.league,
                    openCouples: openCouples,
                    openAmericanoPlayers: openAmericanoPlayers,
                    openMembers: openMembers,
                    addPlayer: addPlayer,
                    editPlayer: editPlayer),
                PadelStatisticsSection(
                    league: widget.league, save: widget.save),
              ],
            ),
          ),
        ),
        floatingActionButton: !widget.league.manage
            ? null
            : tab == 0
                ? _CompactPadelFab(label: '+ Partita', onPressed: newMatch)
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
            onDestinationSelected: (value) => setState(() => tab = value),
            destinations: [
              NavigationDestination(
                  icon: SvgPicture.asset('assets/icons/sport_padel.svg',
                      width: 34, height: 34),
                  selectedIcon: SvgPicture.asset('assets/icons/sport_padel.svg',
                      width: 34, height: 34),
                  label: 'Partite'),
              const NavigationDestination(
                  icon: Icon(Icons.group), label: 'Giocatori'),
              const NavigationDestination(
                  icon: Icon(Icons.bar_chart), label: 'Statistiche'),
            ],
          ),
        ),
      );
}

class _PadelMatchesSection extends StatelessWidget {
  const _PadelMatchesSection(
      {required this.league,
      required this.status,
      required this.onStatusChanged,
      required this.save,
      this.reload});

  final League league;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final Save save;
  final Save? reload;

  Color statusColor(String value) => value == 'live'
      ? const Color(0xffa8e86b)
      : value == 'scheduled'
          ? HaykoColors.padelAccent
          : const Color(0xffbcb6c9);

  String statusLabel(String value) => value == 'scheduled'
      ? 'Programmate'
      : value == 'live'
          ? 'In corso'
          : 'Terminate';

  @override
  Widget build(BuildContext context) {
    final matches = league.matches.reversed
        .where((match) => match.status == status)
        .toList();
    final hasLiveMatch =
        league.matches.any((match) => match.status == 'live') ||
            league.competitions.any((competition) =>
                competition.kind == 'americano' &&
                ['live', 'paused'].contains(competition.americanoTurnStatus));
    final americanos = league.competitions
        .where((competition) =>
            competition.kind == 'americano' &&
            competition.americanoSchedule.isNotEmpty &&
            (competition.americanoTurnStatus == status ||
                (status == 'live' &&
                    competition.americanoTurnStatus == 'paused') ||
                (status == 'scheduled' &&
                    competition.americanoTurnStatus == 'completed')))
        .toList();
    final color = statusColor(status);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Row(children: [
          for (final value in ['scheduled', 'live', 'finished']) ...[
            if (value != 'scheduled') const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                selected: status == value,
                button: true,
                child: InkWell(
                  key: ValueKey('padel-match-tab-$value'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onStatusChanged(value),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                        color: status == value
                            ? HaykoColors.fieldLine
                            : HaykoColors.fieldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor(value))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: Text(statusLabel(value),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: TextStyle(
                                      color: statusColor(value),
                                      fontSize: 12,
                                      height: 16 / 12,
                                      fontWeight: FontWeight.w600))),
                          if (value == 'live' && hasLiveMatch) ...[
                            const SizedBox(width: 4),
                            Container(
                                key: const ValueKey('padel-live-dot'),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: statusColor(value),
                                    shape: BoxShape.circle)),
                          ]
                        ]),
                  ),
                ),
              ),
            ),
          ]
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'Partite ${status == 'scheduled' ? 'programmate' : status == 'live' ? 'in corso' : 'terminate'}',
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w800)),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 92),
          children: [
            if (matches.isEmpty && americanos.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Nessuna partita ${status == 'scheduled' ? 'programmata' : status == 'live' ? 'in corso' : 'terminata'}.')),
            for (final competition in americanos) ...[
              InkWell(
                key: ValueKey('americano-open-${competition.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => switch (competition.americanoTurnStatus) {
                        'live' || 'paused' => PadelAmericanoLivePage(
                            league: league,
                            competition: competition,
                            save: save,
                          ),
                        'finished' => PadelAmericanoStandingsPage(
                            league: league,
                            competition: competition,
                            save: save,
                          ),
                        'completed' => PadelAmericanoRoundCompletePage(
                            league: league,
                            competition: competition,
                            save: save,
                          ),
                        _ => PadelAmericanoScheduledPage(
                            league: league,
                            competition: competition,
                            save: save,
                          ),
                      },
                    ),
                  );
                  onStatusChanged(switch (competition.americanoTurnStatus) {
                    'live' || 'paused' => 'live',
                    'completed' => 'scheduled',
                    _ => competition.americanoTurnStatus,
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HaykoColors.fieldSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: .5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(competition.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          'Americano · Turno ${competition.americanoCurrentRound + 1} '
                          'di ${competition.americanoRounds}',
                          style: const TextStyle(
                              color: HaykoColors.mutedText, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final match in matches) ...[
              _PadelMatchCard(
                  league: league,
                  match: match,
                  borderColor: color,
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => match.status == 'finished'
                                ? PadelMatchStatsPage(
                                    league: league, match: match)
                                : match.status == 'live'
                                    ? PadelLiveMatchPage(
                                        league: league,
                                        match: match,
                                        save: save,
                                        reload: reload)
                                    : MatchPage(
                                        league: league,
                                        match: match,
                                        save: save,
                                        reload: reload)));
                    onStatusChanged(match.status);
                  }),
              const SizedBox(height: 12),
            ]
          ],
        ),
      )
    ]);
  }
}

class _PadelMatchCard extends StatelessWidget {
  const _PadelMatchCard(
      {required this.league,
      required this.match,
      required this.borderColor,
      required this.onTap});

  final League league;
  final Match match;
  final Color borderColor;
  final VoidCallback? onTap;

  String get dateText {
    final raw = match.scheduledAt ?? match.startedAt ?? match.finishedAt;
    if (raw == null) return 'Data da definire';
    final date = DateTime.parse(raw).toLocal();
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
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
  }

  String get details {
    final values = <String>[dateText, 'Meglio di ${match.padelBestOf} set'];
    if (match.status == 'live') {
      values.add(
          'Tempo partita: ${clockText(matchElapsed(match, DateTime.now().toUtc()))}');
    }
    if (match.venue.trim().isNotEmpty) values.add(match.venue.trim());
    values
        .add(match.padelGameRule == 'advantages' ? 'Vantaggi' : 'Golden Point');
    return values.join(' · ');
  }

  String teamName(int team) => match.teams[team]
      .map((id) => league.playerName(id).trim().split(RegExp(r'\s+')).first)
      .join(' / ');

  String setValue(int team, int set) => set < match.padelSetScores.length
      ? '${match.padelSetScores[set][team]}'
      : '—';

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor.withValues(alpha: .38))),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(builder: (context, constraints) {
                final live = match.status == 'live';
                final setWidth = match.padelBestOf == 5 ? 28.0 : 32.0;
                final pointsWidth = live ? 56.0 : 0.0;
                final nameWidth = constraints.maxWidth -
                    (setWidth * match.padelBestOf) -
                    pointsWidth;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  _PadelScoreHeader(
                      nameWidth: nameWidth,
                      setWidth: setWidth,
                      sets: match.padelBestOf,
                      pointsWidth: pointsWidth),
                  _PadelScoreRow(
                      name: teamName(0),
                      color: match.teamColors[0],
                      dimmedSets: match.status == 'finished'
                          ? {
                              for (var i = 0;
                                  i < match.padelSetScores.length;
                                  i++)
                                if (PadelScoring.setWinner(match, i) == 1) i
                            }
                          : const {},
                      nameWidth: nameWidth,
                      setWidth: setWidth,
                      values: [
                        for (var set = 0; set < match.padelBestOf; set++)
                          setValue(0, set)
                      ],
                      points: live ? match.padelPoints[0] : null,
                      pointsWidth: pointsWidth),
                  Container(height: 1, color: HaykoColors.fieldBackground),
                  _PadelScoreRow(
                      name: teamName(1),
                      color: match.teamColors[1],
                      dimmedSets: match.status == 'finished'
                          ? {
                              for (var i = 0;
                                  i < match.padelSetScores.length;
                                  i++)
                                if (PadelScoring.setWinner(match, i) == 0) i
                            }
                          : const {},
                      nameWidth: nameWidth,
                      setWidth: setWidth,
                      values: [
                        for (var set = 0; set < match.padelBestOf; set++)
                          setValue(1, set)
                      ],
                      points: live ? match.padelPoints[1] : null,
                      pointsWidth: pointsWidth),
                  const SizedBox(height: 4),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(details,
                          style: const TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 18 / 12))),
                ]);
              })),
        ),
      );
}

class _PadelScoreHeader extends StatelessWidget {
  const _PadelScoreHeader(
      {required this.nameWidth,
      required this.setWidth,
      required this.sets,
      required this.pointsWidth});
  final double nameWidth;
  final double setWidth;
  final int sets;
  final double pointsWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 24,
        child: Row(children: [
          SizedBox(width: nameWidth, child: const _PadelHeaderText('COPPIE')),
          for (var set = 1; set <= sets; set++)
            SizedBox(
                key: ValueKey('padel-set-header-$set'),
                width: setWidth,
                child: _PadelHeaderText('$set', centered: true)),
          if (pointsWidth > 0)
            SizedBox(
                key: const ValueKey('padel-points-header'),
                width: pointsWidth,
                child: const _PadelHeaderText('PUNTI', centered: true)),
        ]),
      );
}

class _PadelHeaderText extends StatelessWidget {
  const _PadelHeaderText(this.value, {this.centered = false});
  final String value;
  final bool centered;

  @override
  Widget build(BuildContext context) => Text(value,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      style: const TextStyle(
          color: HaykoColors.mutedText,
          fontSize: 10,
          height: 16 / 10,
          fontWeight: FontWeight.w600));
}

class _PadelScoreRow extends StatelessWidget {
  const _PadelScoreRow(
      {required this.name,
      required this.color,
      required this.dimmedSets,
      required this.nameWidth,
      required this.setWidth,
      required this.values,
      required this.points,
      required this.pointsWidth});
  final String name;
  final int color;
  final Set<int> dimmedSets;
  final double nameWidth;
  final double setWidth;
  final List<String> values;
  final String? points;
  final double pointsWidth;

  Widget score(String value, double width, {Key? key, bool dimmed = false}) =>
      SizedBox(
        key: key,
        width: width,
        child: Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: value == '—' || dimmed
                    ? HaykoColors.mutedText
                    : HaykoColors.chalk,
                fontSize: 16,
                height: 20 / 16,
                fontWeight: value == '—' ? FontWeight.w400 : FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: Row(children: [
          SizedBox(
              width: nameWidth,
              child: Row(children: [
                Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 18 / 14,
                            fontWeight: FontWeight.w600))),
              ])),
          for (var index = 0; index < values.length; index++)
            score(values[index], setWidth,
                dimmed: dimmedSets.contains(index),
                key: ValueKey('padel-set-score-$name-$index')),
          if (points != null) score(points!, pointsWidth),
        ]),
      );
}

class _CompactPadelFab extends StatelessWidget {
  const _CompactPadelFab({required this.label, required this.onPressed});
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
                  fontWeight: FontWeight.w700)),
        ),
      );
}

class _PlayersSection extends StatelessWidget {
  const _PlayersSection(
      {required this.league,
      required this.openCouples,
      required this.openAmericanoPlayers,
      required this.openMembers,
      required this.addPlayer,
      required this.editPlayer});

  final League league;
  final VoidCallback openCouples;
  final VoidCallback openAmericanoPlayers;
  final VoidCallback openMembers;
  final VoidCallback addPlayer;
  final ValueChanged<Player> editPlayer;

  @override
  Widget build(BuildContext context) {
    final players = [...league.players]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 92),
      children: [
        if (league.competitions.any((c) => c.kind == 'americano')) ...[
          AccountButton('Giocatori Americano',
              key: const ValueKey('open-americano-players'),
              outline: true,
              onPressed: league.manage &&
                      league.competitions
                          .where((c) => c.kind == 'americano')
                          .every((c) =>
                              c.americanoTurnStatus == 'scheduled' &&
                              c.americanoCurrentRound == 0 &&
                              !c.americanoResults.any((round) => round.any(
                                  (result) =>
                                      result.points.isNotEmpty ||
                                      result.finished)))
                  ? openAmericanoPlayers
                  : null),
          const SizedBox(height: 8),
        ],
        _PadelOutlineButton(label: 'Coppie salvate', onPressed: openCouples),
        if (league.shared) ...[
          const SizedBox(height: 8),
          AccountButton('Membri e inviti',
              outline: true, onPressed: openMembers),
        ],
        const SizedBox(height: 8),
        const Text('Giocatori della lega',
            style: TextStyle(
                fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (players.isEmpty)
          const Text(
              'Nessun giocatore. Aggiungi almeno quattro giocatori per creare una partita Padel.',
              style: TextStyle(
                  color: HaykoColors.mutedText, fontSize: 14, height: 20 / 14)),
        for (var index = 0; index < players.length; index++) ...[
          _PadelPlayerRow(
              player: players[index],
              current: league.myPlayer == players[index].id,
              editable: league.manage || league.myPlayer == players[index].id,
              onEdit: () => editPlayer(players[index])),
          if (index != players.length - 1) const SizedBox(height: 8),
        ],
        if (players.isNotEmpty) const SizedBox(height: 8),
        if (league.manage) AccountButton('+ Giocatore', onPressed: addPlayer),
      ],
    );
  }
}

class _PadelPlayerRow extends StatelessWidget {
  const _PadelPlayerRow(
      {required this.player,
      required this.current,
      required this.editable,
      required this.onEdit});

  final Player player;
  final bool current;
  final bool editable;
  final VoidCallback onEdit;

  String get initials => player.name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: current ? Border.all(color: HaykoColors.chalk) : null,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(player.color),
                    child: Text(initials.isEmpty ? '?' : initials,
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
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Text('Giocatore',
                          style: TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ])),
              ]),
            ),
          ),
          if (editable)
            IconButton(
                tooltip: 'Modifica giocatore',
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                onPressed: onEdit,
                icon: const Icon(Icons.edit)),
        ]),
      );
}

class _PadelOutlineButton extends StatelessWidget {
  const _PadelOutlineButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
            backgroundColor: HaykoColors.fieldSurface,
            foregroundColor: HaykoColors.chalk,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.all(12),
            side: BorderSide(
                color: HaykoColors.padelAccent.withValues(alpha: .55)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w700)),
        onPressed: onPressed,
        child: Text(label),
      );
}
