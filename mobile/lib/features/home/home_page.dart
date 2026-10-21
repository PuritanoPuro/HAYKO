import 'package:calcetto_mvp/features/matches/match_page.dart';
import 'dart:convert';
import 'package:calcetto_mvp/design_system/hayko_home.dart';
import 'package:flutter/material.dart';
import 'package:calcetto_mvp/features/account/invite_links.dart';
import 'package:calcetto_mvp/features/account/profile_page.dart';
import 'package:calcetto_mvp/features/account/profile_service.dart';
import 'package:calcetto_mvp/features/account/settings_page.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/features/leagues/league_creation.dart';
import 'dart:async';

import 'package:calcetto_mvp/features/leagues/league_page.dart';

Set<String> newPendingRequests(Set<String>? previous, Set<String> current) =>
    previous == null ? <String>{} : current.difference(previous);

Set<String> newlyApprovedRequests(
        Map<String, String>? previous, Map<String, String> current) =>
    previous == null
        ? <String>{}
        : current.entries
            .where((entry) =>
                entry.value == 'approved' && previous[entry.key] != 'approved')
            .map((entry) => entry.key)
            .toSet();

class HomeNavigationGate {
  bool active = false;

  Future<void> run(Future<void> Function() action) async {
    if (active) return;
    active = true;
    try {
      await action();
    } finally {
      active = false;
    }
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  List<League> leagues = [];
  bool busy = true;
  final navigationGate = HomeNavigationGate();
  String? error;
  Timer? syncTimer;
  Timer? socialTimer;
  Set<String>? pendingRequestSnapshot;
  Map<String, String>? ownRequestSnapshot;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RotationAlerts.instance.openMatch.addListener(notificationSelected);
    InviteLinks.pending.addListener(openPendingInvite);
    final cache = Cloud.store;
    syncTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => unawaited(cache.flush()));
    socialTimer = Timer.periodic(const Duration(seconds: 15),
        (_) => unawaited(refreshSocialNotifications()));
    load();
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    socialTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    RotationAlerts.instance.openMatch.removeListener(notificationSelected);
    InviteLinks.pending.removeListener(openPendingInvite);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(Cloud.store.flush());
      unawaited(RotationAlerts.instance.sync(leagues));
      unawaited(refreshSocialNotifications());
    }
  }

  Future<void> load() async {
    try {
      final found = await Cloud.list();
      if (!mounted) return;
      leagues = found;
      RotationAlerts.instance.sources.clear();
      await RotationAlerts.instance.sync(leagues);
      if (mounted) {
        setState(() {
          busy = false;
          error = null;
        });
      }
      await refreshSocialNotifications(initialize: true);
      notificationSelected();
      openPendingInvite();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Impossibile caricare le leghe. Controlla la connessione e riprova.';
        });
      }
    }
  }

  Future<void> refreshSocialNotifications({bool initialize = false}) async {
    if (!mounted || busy || error != null) return;
    try {
      final pending = <String>{};
      final labels = <String, String>{};
      for (final league in leagues.where((league) => league.manage)) {
        final rows = await Cloud.client
            .rpc('hayko_requests', params: {'p_id': league.id}) as List;
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          final key = '${league.id}|${row['user_id']}';
          pending.add(key);
          labels[key] = '${row['name'] ?? 'Un giocatore'}';
        }
      }
      final ownRows = await Cloud.client.rpc('hayko_requests') as List;
      final own = <String, String>{};
      final ownLabels = <String, String>{};
      for (final raw in ownRows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final key = '${row['league_id']}';
        own[key] = '${row['status']}';
        ownLabels[key] = '${row['league_name'] ?? 'la lega'}';
      }
      if (!initialize) {
        for (final key in newPendingRequests(pendingRequestSnapshot, pending)) {
          final league = leagues.firstWhere((l) => key.startsWith('${l.id}|'));
          await RotationAlerts.instance.showSocialNotification(
              title: 'Nuova richiesta di accesso',
              body: '${labels[key]} vuole entrare in ${league.name}.');
        }
      }
      if (!initialize) {
        for (final key in newlyApprovedRequests(ownRequestSnapshot, own)) {
          await RotationAlerts.instance.showSocialNotification(
              title: 'Richiesta approvata',
              body: 'Ora puoi accedere a ${ownLabels[key]}.');
        }
      }
      pendingRequestSnapshot = pending;
      ownRequestSnapshot = own;
    } catch (_) {
      // Il controllo viene ripetuto al prossimo intervallo o alla riapertura.
    }
  }

  void notificationSelected() {
    if (busy || error != null || !mounted) return;
    final payload = RotationAlerts.instance.openMatch.value;
    if (payload == null || payload.isEmpty) return;
    RotationAlerts.instance.openMatch.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openNotification(payload));
    });
  }

  Future<void> openNotification(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final found = leagues.where((l) => l.id == data['league']).toList();
      if (found.isEmpty) throw StateError('Lega non disponibile.');
      final l = found.first,
          m = l.matches.firstWhere((m) => m.id == data['match']);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MatchPage(
                  league: l,
                  match: m,
                  save: () => Cloud.save(l),
                  reload: () => Cloud.refresh(l))));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> createLeague() async {
    await openOnce(() async {
      final l = await Navigator.push<League>(
          context, MaterialPageRoute(builder: (_) => const LeagueCreation()));
      if (l == null) return;
      try {
        await Cloud.client.rpc('bc_create', params: {'p_state': l.toJson()});
        await load();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    });
  }

  Future<void> deleteLeague(League l) async {
    await Cloud.store.flush();
    if (Cloud.store.pending > 0) {
      throw StateError('Completa prima la sincronizzazione delle modifiche.');
    }
    await Cloud.client
        .rpc('bc_delete', params: {'p_id': l.id, 'p_name': l.name});
    RotationAlerts.instance.sources.remove(l.id);
    await load();
  }

  Future<void> openLeague(League l) async {
    await openOnce(() async {
      try {
        if (l.myPlayer == null) {
          await Cloud.refresh(l);
          if (!mounted) return;
          await Cloud.identify(context, l);
        }
        if (!mounted || l.myPlayer == null) return;
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LeaguePage(
                    league: l,
                    save: () => Cloud.save(l),
                    reload: () => Cloud.refresh(l),
                    onDelete: () => deleteLeague(l))));
        await load();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    });
  }

  Future<void> openProfile() async {
    await openOnce(() async {
      try {
        final p = await ProfileService.load();
        if (!mounted) return;
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProfilePage(initial: p)));
      } catch (e) {
        if (mounted) showError(context, e);
      }
    });
  }

  void openPendingInvite() {
    if (!mounted || busy || InviteLinks.pending.value == null) return;
    final code = InviteLinks.pending.value!;
    unawaited(InviteLinks.clearPending());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => CloudHome(initialCode: code)));
      }
    });
  }

  Future<void> openShared() async {
    await openOnce(() async {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CloudHome()));
      if (mounted) await load();
    });
  }

  Future<void> openSettings() async {
    await openOnce(() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsPage())));
  }

  Future<void> openOnce(Future<void> Function() action) async {
    await navigationGate.run(action);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: Cloud.store,
      builder: (context, _) => HaykoHome(
            notice: Cloud.store.pending > 0 || Cloud.store.problem != null
                ? SyncNotice(onRetry: load)
                : null,
            leagues: leagues,
            loading: busy,
            error: error,
            onRetry: () {
              setState(() {
                busy = true;
                error = null;
              });
              load();
            },
            onOpenLeague: openLeague,
            onCreateLeague: createLeague,
            onRefresh: load,
            onSharedLeagues: openShared,
            onAccount: openProfile,
            onSettings: openSettings,
          ));
}
