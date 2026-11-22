import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

/// Home HAYKO: presenta i dati e delega tutte le azioni alla home esistente.
class HaykoHome extends StatefulWidget {
  const HaykoHome({
    super.key,
    required this.leagues,
    required this.loading,
    this.actionLoading = false,
    required this.error,
    required this.onRetry,
    required this.onOpenLeague,
    required this.onCreateLeague,
    required this.onSharedLeagues,
    required this.onAccount,
    required this.onSettings,
    this.onRefresh,
    this.notice,
  });

  final List<League> leagues;
  final bool loading;
  final bool actionLoading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<League> onOpenLeague;
  final ValueChanged<String> onCreateLeague;
  final VoidCallback onSharedLeagues;
  final VoidCallback onAccount;
  final VoidCallback onSettings;
  final Future<void> Function()? onRefresh;
  final Widget? notice;

  @override
  State<HaykoHome> createState() => _HaykoHomeState();
}

class _HaykoHomeState extends State<HaykoHome> {
  static const tennis = 'tennis';
  String sport = LeagueSport.football;

  static const _heading = TextStyle(
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );
  static const _button = TextStyle(
    fontFamily: 'BricolageGrotesque',
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final leagues =
        widget.leagues.where((league) => league.sport == sport).toList();
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Scaffold(
      bottomNavigationBar: widget.notice,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 24,
        title: const Text('HAYKO',
            style: TextStyle(
                fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800)),
        actions: [
          HaykoIconAction(
            tooltip: 'Profilo e account',
            icon: Icons.person,
            onPressed: widget.onAccount,
          ),
          const SizedBox(width: 12),
          HaykoIconAction(
            tooltip: 'Impostazioni',
            icon: Icons.settings,
            onPressed: widget.onSettings,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(children: [
        RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async {},
            child: SafeArea(
              top: false,
              child: widget.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: 'Caricamento leghe'))
                  : widget.error != null
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.error!,
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  TextButton(
                                      onPressed: widget.onRetry,
                                      child: const Text('Riprova')),
                                ]),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight),
                                  child: IntrinsicHeight(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          24, 20, 24, 24),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text('Le tue leghe',
                                                style: _heading),
                                            const SizedBox(height: 12),
                                            _SportSwitcher(
                                              sport: sport,
                                              onChanged: (value) =>
                                                  setState(() => sport = value),
                                            ),
                                            const SizedBox(height: 12),
                                            Text('LEGHE RECENTI',
                                                style: TextStyle(
                                                    color: sport ==
                                                            LeagueSport.padel
                                                        ? HaykoColors
                                                            .padelAccent
                                                        : HaykoColors.mutedText,
                                                    fontSize: 12,
                                                    height: 16 / 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(height: 12),
                                            if (leagues.isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12),
                                                child: Text(sport ==
                                                        LeagueSport.padel
                                                    ? 'Nessuna lega Padel. Crea la prima lega per iniziare.'
                                                    : 'Crea una lega, aggiungi i giocatori e organizza la prima partita.'),
                                              ),
                                            for (var index = 0;
                                                index < leagues.length;
                                                index++) ...[
                                              _LeagueCard(
                                                  league: leagues[index],
                                                  onTap: () =>
                                                      widget.onOpenLeague(
                                                          leagues[index])),
                                              if (index != leagues.length - 1)
                                                const SizedBox(height: 12),
                                            ],
                                            const Spacer(),
                                            const SizedBox(height: 24),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    HaykoColors.chalk,
                                                foregroundColor:
                                                    HaykoColors.fieldBackground,
                                                minimumSize: const Size(0, 52),
                                                padding:
                                                    const EdgeInsets.all(12),
                                                textStyle: _button,
                                                shape: shape,
                                              ),
                                              onPressed: () {
                                                if (sport == tennis) {
                                                  ScaffoldMessenger.of(context)
                                                    ..hideCurrentSnackBar()
                                                    ..showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Le leghe Tennis saranno disponibili prossimamente.')));
                                                  return;
                                                }
                                                widget.onCreateLeague(sport);
                                              },
                                              child: const Text('+ NUOVA LEGA'),
                                            ),
                                            const SizedBox(height: 12),
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    HaykoColors.chalk,
                                                backgroundColor:
                                                    HaykoColors.fieldSurface,
                                                side: const BorderSide(
                                                    color:
                                                        HaykoColors.fieldLine),
                                                minimumSize: const Size(0, 52),
                                                padding:
                                                    const EdgeInsets.all(12),
                                                textStyle: _button,
                                                shape: shape,
                                              ),
                                              onPressed: widget.onSharedLeagues,
                                              child: const Text(
                                                  'ACCEDI CON CODICE'),
                                            ),
                                          ]),
                                    ),
                                  ),
                                ),
                              )),
            )),
        if (widget.actionLoading)
          const Positioned.fill(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ModalBarrier(
                  dismissible: false,
                  color: Color(0x730E2B22),
                ),
                CircularProgressIndicator(
                  color: HaykoColors.chalk,
                  semanticsLabel: 'Operazione in corso',
                ),
              ],
            ),
          ),
      ]),
    );
  }
}

class _SportSwitcher extends StatelessWidget {
  const _SportSwitcher({required this.sport, required this.onChanged});

  final String sport;
  final ValueChanged<String> onChanged;

  int get index => switch (sport) {
        LeagueSport.padel => 1,
        _HaykoHomeState.tennis => 2,
        _ => 0,
      };

  Color get accent => switch (sport) {
        LeagueSport.padel => HaykoColors.padelAccent,
        _HaykoHomeState.tennis => const Color(0xffd97757),
        _ => const Color(0xffbbf568),
      };

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('sport-switcher'),
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(color: HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(16)),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 12) / 3;
          return Stack(children: [
            AnimatedPositioned(
              key: const ValueKey('sport-selection-pill'),
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeInOutCubic,
              left: index * (width + 6),
              top: 1,
              bottom: 1,
              width: width,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(12)),
              ),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _SportTab(
                  label: 'CALCIO',
                  icon: Icons.sports_soccer,
                  selected: sport == LeagueSport.football,
                  onTap: () => onChanged(LeagueSport.football)),
              const SizedBox(width: 6),
              _SportTab(
                  label: 'PADEL',
                  asset: 'assets/icons/sport_padel.svg',
                  iconSize: 29,
                  selected: sport == LeagueSport.padel,
                  onTap: () => onChanged(LeagueSport.padel)),
              const SizedBox(width: 6),
              _SportTab(
                  label: 'TENNIS',
                  asset: 'assets/icons/sport_tennis.svg',
                  selected: sport == _HaykoHomeState.tennis,
                  onTap: () => onChanged(_HaykoHomeState.tennis)),
            ]),
          ]);
        }),
      );
}

class _SportTab extends StatelessWidget {
  const _SportTab(
      {required this.label,
      this.asset,
      this.icon,
      required this.selected,
      this.iconSize = 20,
      this.onTap});

  final String label;
  final String? asset;
  final IconData? icon;
  final bool selected;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox.expand(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      TweenAnimationBuilder<Color?>(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        tween: ColorTween(
                            end: selected
                                ? const Color(0xff081a15)
                                : HaykoColors.chalk),
                        builder: (context, color, child) => icon != null
                            ? Icon(icon, size: iconSize, color: color)
                            : SvgPicture.asset(asset!,
                                width: iconSize,
                                height: iconSize,
                                colorFilter: ColorFilter.mode(
                                    color ?? HaykoColors.chalk,
                                    BlendMode.srcIn)),
                      ),
                      const SizedBox(width: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: selected
                                ? const Color(0xff081a15)
                                : HaykoColors.chalk,
                            fontFamily: 'BricolageGrotesque',
                            fontSize: 11,
                            height: 14 / 11,
                            fontWeight: FontWeight.w700),
                        child: Text(label,
                            maxLines: 1, textAlign: TextAlign.center),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Geometria 42×42 della schermata Home multisport in Figma.
class HaykoIconAction extends StatelessWidget {
  const HaykoIconAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        style: IconButton.styleFrom(
          backgroundColor: HaykoColors.fieldSurface,
          foregroundColor: HaykoColors.chalk,
          fixedSize: const Size(42, 42),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.league, required this.onTap});

  final League league;
  final VoidCallback onTap;

  Color _iconColor(Color background) {
    double contrast(Color foreground) {
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
    }

    return contrast(HaykoColors.fieldBackground) >= contrast(HaykoColors.chalk)
        ? HaykoColors.fieldBackground
        : HaykoColors.chalk;
  }

  @override
  Widget build(BuildContext context) {
    final competition = league.type == 'competition';
    final padel = league.sport == LeagueSport.padel;
    final accent = padel ? HaykoColors.padelAccent : const Color(0xffbbf568);
    final leagueColor = Color(league.primaryColor);
    return Material(
      color: HaykoColors.fieldSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 82),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Container(
                  key: ValueKey('league-accent-${league.id}'),
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                      color: accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Container(
                key: ValueKey('league-icon-${league.id}'),
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(color: leagueColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(competition ? Icons.emoji_events : Icons.groups,
                    size: 24, color: _iconColor(leagueColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(league.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          )),
                      Text(
                          padel
                              ? _padelSubtitle(league)
                              : competition
                                  ? 'Competizione · ${league.presets.where((team) => !team.archived).length} squadre · ${league.matches.length} partite'
                                  : 'Amatoriale · ${league.players.length} giocatori · ${league.matches.length} partite',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w400,
                            color: HaykoColors.mutedText,
                            letterSpacing: 0,
                          )),
                    ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                height: 24,
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right, size: 22, color: accent)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _padelSubtitle(League league) {
    final scheduled = league.matches
        .where(
            (match) => match.status == 'scheduled' && match.scheduledAt != null)
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    if (scheduled.isNotEmpty) {
      final value = DateTime.tryParse(scheduled.first.scheduledAt!);
      if (value != null) {
        final now = DateTime.now();
        final day = DateTime(value.year, value.month, value.day);
        final today = DateTime(now.year, now.month, now.day);
        final label = day == today
            ? 'Oggi'
            : day == today.add(const Duration(days: 1))
                ? 'Domani'
                : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
        return 'Prossima partita · $label, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      }
    }
    final couples = league.presets
        .where((couple) => !couple.archived && couple.players.length == 2)
        .length;
    return league.type == 'competition'
        ? '$couples coppie · ${league.matches.length} partite'
        : '${league.players.length} giocatori · $couples coppie';
  }
}
