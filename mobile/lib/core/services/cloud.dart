import 'package:calcetto_mvp/features/leagues/invite_code_dialog.dart';
import 'dart:async';
import 'package:calcetto_mvp/core/config/hayko_config.dart';
import 'package:calcetto_mvp/features/account/league_store.dart';
import 'package:calcetto_mvp/features/account/profile_service.dart';
import 'package:calcetto_mvp/features/account/invite_codes.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/features/leagues/league_page.dart' show LeaguePage;

class Cloud {
  static bool ready = false;
  static const url = HaykoConfig.url;
  static const key = HaykoConfig.key;
  static Future<void> initialize() async {
    if (url.isEmpty || key.isEmpty) return;
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static LeagueStore? _store;
  static LeagueStore get store {
    final id = client.auth.currentUser!.id;
    if (_store?.userId != id) {
      _store = LeagueStore(id, (name, params) async {
        if (client.auth.currentUser?.id != id) {
          throw StateError('Account cambiato.');
        }
        return await client.rpc(name, params: params);
      });
    }
    return _store!;
  }

  static League decode(Map<String, dynamic> result) {
    final l = League.fromJson(Map<String, dynamic>.from(result['state']));
    l.shared = true;
    l.revision = result['revision'];
    l.currentUser = client.auth.currentUser!.id;
    l.myRole = result['role'];
    l.myPlayer = result['player_id'];
    for (final m in result['members'] as List) {
      if (m['player_id'] != null) l.roles[m['player_id']] = m['role'];
    }
    return l;
  }

  static Future<List<League>> list() async {
    final id = client.auth.currentUser!.id;
    final rows = await store.list();
    if (client.auth.currentUser?.id != id) {
      throw StateError('Account cambiato.');
    }
    return rows.map(decode).toList();
  }

  static Future<void> refresh(League l) async {
    final fresh = decode(await store.get(l.id));
    l.type = fresh.type;
    l.name = fresh.name;
    l.primaryColor = fresh.primaryColor;
    l.secondaryColor = fresh.secondaryColor;
    l.presets
      ..clear()
      ..addAll(fresh.presets);
    l.competitions
      ..clear()
      ..addAll(fresh.competitions);
    l.players
      ..clear()
      ..addAll(fresh.players);
    final stable = <Match>[];
    for (final updated in fresh.matches) {
      final existing = l.matches.where((m) => m.id == updated.id);
      if (existing.isEmpty) {
        stable.add(updated);
      } else {
        final m = existing.first;
        m.status = updated.status;
        m.startedAt = updated.startedAt;
        m.finishedAt = updated.finishedAt;
        m.scheduledAt = updated.scheduledAt;
        m.venue = updated.venue;
        m.qualifiedTeamId = updated.qualifiedTeamId;
        m.teamColors
          ..clear()
          ..addAll(updated.teamColors);
        if (updated.status == 'scheduled') {
          m.teams[0] = [...updated.teams[0]];
          m.teams[1] = [...updated.teams[1]];
          m.names
            ..clear()
            ..addAll(updated.names);
        }
        m.goals
          ..clear()
          ..addAll(updated.goals);
        stable.add(m);
      }
    }
    l.matches
      ..clear()
      ..addAll(stable);
    l.revision = fresh.revision;
    l.myRole = fresh.myRole;
    l.myPlayer = fresh.myPlayer;
    l.roles = fresh.roles;
    await RotationAlerts.instance.sync([l]);
  }

  static Future<void> save(League l) async {
    final cache = store;
    await cache.initialize();
    final previous = cache.rows.where((r) => r['state']['id'] == l.id);
    if (previous.isNotEmpty) l.revision = previous.first['revision'] as int;
    await cache.queue({
      'state': l.toJson(),
      'revision': l.revision,
      'role': l.myRole,
      'player_id': l.myPlayer,
      'members': [
        for (final e in l.roles.entries) {'player_id': e.key, 'role': e.value}
      ],
    });
    unawaited(cache.flush());
    await RotationAlerts.instance.sync([l]);
  }

  static Future<void> identify(BuildContext context, League l) async {
    String? chosen;
    final available = [...l.players]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    chosen = await showDialog<String>(
        context: context,
        builder: (c) =>
            SimpleDialog(title: const Text('Quale giocatore sei?'), children: [
              for (final p in available)
                SimpleDialogOption(
                    onPressed: l.roles.containsKey(p.id) && l.myPlayer != p.id
                        ? null
                        : () => Navigator.pop(c, p.id),
                    child: Text(
                        '${p.name}${l.roles.containsKey(p.id) && l.myPlayer != p.id ? ' · già associato' : ''}')),
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, '__new__'),
                  child: const Text('Il mio nome non è presente · aggiungimi')),
            ]));
    if (chosen == null || !context.mounted) return;
    String? name;
    if (chosen == '__new__') {
      final profile = await ProfileService.load();
      if (!context.mounted) return;
      name = await askText(context, 'Il tuo nome', initial: profile.firstName);
      if (name == null) return;
    }
    if (!context.mounted) return;
    final label = chosen == '__new__' ? name! : l.playerName(chosen);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Confermi il tuo giocatore?'),
              content: Text('Nella lega sarai $label.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Modifica')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Conferma'))
              ],
            ));
    if (confirmed != true) return;
    await client.rpc('bc_claim', params: {
      'p_id': l.id,
      'p_player': chosen == '__new__' ? null : chosen,
      'p_name': name
    });
    await refresh(l);
  }
}

class CloudHome extends StatefulWidget {
  const CloudHome({super.key, this.initialCode});
  final String? initialCode;
  @override
  State<CloudHome> createState() => _CloudHomeState();
}

class _CloudHomeState extends State<CloudHome> {
  final code = TextEditingController();
  final leagueName = TextEditingController();
  bool busy = false;
  List<League> leagues = [];
  List<Map<String, dynamic>> requests = [];
  @override
  void initState() {
    super.initState();
    code.text = widget.initialCode ?? '';
    run(() async {
      await reload();
      if (fromInviteLink) await previewInvite();
    });
  }

  bool get fromInviteLink => widget.initialCode != null;

  @override
  void dispose() {
    code.dispose();
    leagueName.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> reload() async {
    leagues = await Cloud.list();
    requests = (await Cloud.client.rpc('hayko_requests') as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  Future<void> previewInvite() async {
    final value = normalizeInviteCode(code.text);
    if (value == null || value.length != 64) {
      throw StateError('Il link invito non è valido.');
    }
    final result = await Cloud.client
        .rpc('hayko_invite_preview', params: {'p_token': value});
    final message = inviteResultError(result);
    if (message != null) throw StateError(message);
    leagueName.text = '$result';
  }

  Future<void> open(League l) async {
    await Cloud.refresh(l);
    if (!mounted) return;
    if (l.myPlayer == null) await Cloud.identify(context, l);
    if (!mounted || l.myPlayer == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LeaguePage(
                league: l,
                save: () => Cloud.save(l),
                reload: () => Cloud.refresh(l),
                onDelete: () async {
                  await Cloud.store.flush();
                  if (Cloud.store.pending > 0) {
                    throw StateError('Completa prima la sincronizzazione.');
                  }
                  await Cloud.client.rpc('bc_delete',
                      params: {'p_id': l.id, 'p_name': l.name});
                  RotationAlerts.instance.sources.remove(l.id);
                  await RotationAlerts.instance.sync([]);
                })));
    await reload();
  }

  Future<void> join() async {
    final value = normalizeInviteCode(code.text);
    if (value == null) {
      throw StateError(
          'Inserisci un codice di 8 caratteri, ad esempio HK7P-9M4R.');
    }
    final id = await Cloud.client.rpc('bc_join', params: {'p_token': value});
    final message = inviteResultError(id);
    if (message != null) throw StateError(message);
    await reload();
    if (!mounted) return;
    final existing = leagues.where((l) => l.id == id);
    if (existing.isNotEmpty) {
      await open(existing.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Richiesta inviata. Attendi l’approvazione di presidente o admin.')));
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
        title: 'Leghe condivise',
        toolbarHeight: 64,
        children: [
          if (fromInviteLink)
            AccountField('Nome lega', controller: leagueName, readOnly: true)
          else
            AccountField('Codice invito', controller: code),
          AccountButton('Accedi alla lega',
              onPressed: busy || (fromInviteLink && leagueName.text.isEmpty)
                  ? null
                  : () => run(join)),
          for (final r in requests.where((r) => r['status'] != 'approved'))
            _SharedLeagueRow(
                name: r['league_name'] as String,
                detail: r['status'] == 'pending'
                    ? 'In attesa di approvazione'
                    : 'Richiesta non approvata'),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Le tue leghe condivise',
                style: TextStyle(
                    fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
          ),
          ...leagues.map((l) => _SharedLeagueRow(
              name: l.name,
              detail: roleName(l.myRole),
              color: Color(l.primaryColor),
              onTap: busy ? null : () => run(() => open(l)))),
        ],
      );
}

class _SharedLeagueRow extends StatelessWidget {
  const _SharedLeagueRow(
      {required this.name, required this.detail, this.color, this.onTap});
  final String name, detail;
  final Color? color;
  final VoidCallback? onTap;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'H';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: color ?? HaykoColors.fieldLine,
                      shape: BoxShape.circle),
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w700)),
                      Text(detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              color: HaykoColors.mutedText)),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, size: 24),
              ]),
            ),
          ),
        ),
      );
}

String roleName(String? role) => role == 'president'
    ? 'Presidente'
    : role == 'admin'
        ? 'Admin'
        : 'Giocatore';

class LeagueSocial extends StatefulWidget {
  final League league;
  const LeagueSocial({super.key, required this.league});
  @override
  State<LeagueSocial> createState() => _LeagueSocialState();
}

class _LeagueSocialState extends State<LeagueSocial> {
  bool busy = false;
  List<Map<String, dynamic>> requests = [], members = [];
  League get l => widget.league;
  @override
  void initState() {
    super.initState();
    if (l.manage) run(() async {});
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Cloud.store.flush();
      if (Cloud.store.pending > 0) {
        throw StateError('Completa prima la sincronizzazione.');
      }
      await action();
      await Cloud.refresh(l);
      if (l.manage) {
        requests = (await Cloud.client
                .rpc('hayko_requests', params: {'p_id': l.id}) as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        members = (await Cloud.client
                .rpc('hayko_members', params: {'p_id': l.id}) as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> invite() async {
    final kind = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: const Text('Copia codice invito'),
                  onTap: () => Navigator.pop(c, 'code')),
              ListTile(
                  title: const Text('Copia link invito'),
                  onTap: () => Navigator.pop(c, 'link')),
            ]));
    if (kind == null || !mounted) return;
    await run(() async {
      final token = await Cloud.client.rpc(
          kind == 'code' ? 'hayko_invite_short' : 'bc_invite',
          params: {'p_id': l.id});
      await Clipboard.setData(ClipboardData(
          text: kind == 'code' ? '$token' : 'hayko://join?invite=$token'));
      if (!mounted) return;
      if (kind == 'code') {
        await showInviteCodeDialog(context, '$token');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Link invito copiato')));
      }
    });
  }

  Future<void> remove(Map<String, dynamic> member) async {
    if (!await confirm(context, 'Rimuovere l’accesso?',
        '${member['name']} non potrà più accedere alla lega. Il giocatore e le statistiche resteranno.')) {
      return;
    }
    await run(() async {
      await Cloud.client.rpc('hayko_remove_member',
          params: {'p_id': l.id, 'p_user': member['user_id']});
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Membri e inviti')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (busy) const LinearProgressIndicator(),
        if (l.myPlayer == null)
          FilledButton(
              onPressed:
                  busy ? null : () => run(() => Cloud.identify(context, l)),
              child: const Text('Associa il tuo giocatore')),
        if (l.manage) ...[
          FilledButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Crea o copia invito'),
              onPressed: busy ? null : invite),
          for (final r in requests)
            Card(
                child: Column(children: [
              ListTile(
                  title: Text(r['name'] as String),
                  subtitle: const Text('Richiesta di accesso')),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              await Cloud.client.rpc('hayko_review_request',
                                  params: {
                                    'p_id': l.id,
                                    'p_user': r['user_id'],
                                    'p_accept': false
                                  });
                            }),
                    child: const Text('Rifiuta')),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              await Cloud.client.rpc('hayko_review_request',
                                  params: {
                                    'p_id': l.id,
                                    'p_user': r['user_id'],
                                    'p_accept': true
                                  });
                            }),
                    child: const Text('Approva')),
              ]),
            ])),
          for (final m in members)
            Card(
                child: ListTile(
                    title: Text(m['name'] as String),
                    subtitle: Text(roleName(m['role'] as String)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (l.president &&
                          m['player_id'] != null &&
                          m['role'] != 'president')
                        Switch(
                            value: m['role'] == 'admin',
                            onChanged: busy
                                ? null
                                : (value) => run(() async {
                                      await Cloud.client.rpc('bc_role',
                                          params: {
                                            'p_id': l.id,
                                            'p_player': m['player_id'],
                                            'p_role': value ? 'admin' : 'member'
                                          });
                                    })),
                      if (m['role'] != 'president' &&
                          m['user_id'] != l.currentUser &&
                          (l.president || m['role'] == 'member'))
                        IconButton(
                            tooltip: 'Rimuovi accesso',
                            onPressed: busy ? null : () => remove(m),
                            icon: const Icon(Icons.person_remove_outlined)),
                    ]))),
        ] else
          ...l.players.map((p) => ListTile(
              title: Text(p.name), subtitle: Text(roleName(l.roles[p.id])))),
      ]));
}
