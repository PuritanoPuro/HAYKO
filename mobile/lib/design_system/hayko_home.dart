import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

/// Home HAYKO: presenta i dati e delega tutte le azioni alla home esistente.
class HaykoHome extends StatelessWidget {
  const HaykoHome({
    super.key,
    required this.leagues,
    required this.loading,
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
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<League> onOpenLeague;
  final VoidCallback onCreateLeague;
  final VoidCallback onSharedLeagues;
  final VoidCallback onAccount;
  final VoidCallback onSettings;
  final Future<void> Function()? onRefresh;
  final Widget? notice;

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
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Scaffold(
      bottomNavigationBar: notice,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 16,
        title: SizedBox(
          width: 72,
          height: 32.488,
          child: Center(
            child: SvgPicture.asset(
              'assets/brand/hayko_falcon_app_v2.svg',
              width: 72,
              height: 32.239,
              semanticsLabel: 'HAYKO',
            ),
          ),
        ),
        actions: [
          HaykoIconAction(
            tooltip: 'Profilo e account',
            icon: Icons.person,
            onPressed: onAccount,
          ),
          const SizedBox(width: 12),
          HaykoIconAction(
            tooltip: 'Impostazioni',
            icon: Icons.settings,
            onPressed: onSettings,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: SafeArea(
            top: false,
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Caricamento leghe'))
                : error != null
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: onRetry,
                                child: const Text('Riprova')),
                          ]),
                        ),
                      )
                    : CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                            const SliverPadding(
                              padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                              sliver: SliverToBoxAdapter(
                                  child: Text('Le tue leghe', style: _heading)),
                            ),
                            if (leagues.isEmpty)
                              const SliverPadding(
                                padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                      'Crea una lega, aggiungi i giocatori e organizza la prima partita.'),
                                ),
                              ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _LeagueCard(
                                      league: leagues[index],
                                      onTap: () => onOpenLeague(leagues[index]),
                                    ),
                                  ),
                                  childCount: leagues.length,
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: HaykoColors.chalk,
                                          foregroundColor:
                                              HaykoColors.fieldBackground,
                                          minimumSize: const Size(0, 52),
                                          padding: const EdgeInsets.all(12),
                                          textStyle: _button,
                                          shape: shape,
                                        ),
                                        onPressed: onCreateLeague,
                                        child: const Text('+ Nuova lega',
                                            textAlign: TextAlign.center),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: HaykoColors.chalk,
                                          side: const BorderSide(
                                              color: HaykoColors.mutedText),
                                          minimumSize: const Size(0, 52),
                                          padding: const EdgeInsets.all(12),
                                          textStyle: _button,
                                          shape: shape,
                                        ),
                                        onPressed: onSharedLeagues,
                                        child: const Text(
                                            'Leghe condivise e inviti',
                                            textAlign: TextAlign.center),
                                      ),
                                    ]),
                              ),
                            ),
                          ]),
          )),
    );
  }
}

/// Bersaglio da 48 px come il componente IconAction in Figma.
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
          fixedSize: const Size(48, 48),
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
    return Material(
      color: HaykoColors.fieldSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Color(league.primaryColor), shape: BoxShape.circle),
                child: Icon(
                  competition ? Icons.emoji_events : Icons.groups,
                  size: 24,
                  color: _iconColor(Color(league.primaryColor)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(league.name,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          )),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          competition
                              ? 'Competizione · ${league.presets.where((team) => !team.archived).length} squadre · ${league.matches.length} partite'
                              : 'Amatoriale · ${league.players.length} giocatori · ${league.matches.length} partite',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600,
                            color: HaykoColors.mutedText,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 64,
                height: 24,
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right, size: 16)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
