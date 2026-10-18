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
    final chosen = await Navigator.push<String>(context,
        MaterialPageRoute(builder: (_) => _IdentifyPlayerPage(league: l)));
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

class _IdentifyPlayerPage extends StatelessWidget {
  const _IdentifyPlayerPage({required this.league});
  final League league;

  @override
  Widget build(BuildContext context) {
    final players = [...league.players]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AccountScaffold(
      title: 'Quale giocatore sei?',
      toolbarHeight: 64,
      children: [
        for (final player in players)
          _MemberRow(
            name: player.name,
            role: league.roles.containsKey(player.id) &&
                    league.myPlayer != player.id
                ? 'Già associato'
                : 'Disponibile',
            color: Color(player.color),
            current: false,
            onTap: league.roles.containsKey(player.id) &&
                    league.myPlayer != player.id
                ? null
                : () => Navigator.pop(context, player.id),
          ),
        AccountButton('Il mio nome non è presente',
            outline: true, onPressed: () => Navigator.pop(context, '__new__')),
      ],
    );
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
        const rank = {'president': 0, 'admin': 1, 'member': 2};
        members.sort(
            (a, b) => (rank[a['role']] ?? 3).compareTo(rank[b['role']] ?? 3));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> invite() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _ShareInvitePage(league: widget.league)));
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

  List<Map<String, dynamic>> get _manageableMembers => members
      .where((m) =>
          m['role'] != 'president' &&
          m['user_id'] != l.currentUser &&
          (l.president || m['role'] == 'member'))
      .toList();

  Color memberColor(Map<String, dynamic> member) {
    final playerId = member['player_id'];
    final found = l.players.where((p) => p.id == playerId).toList();
    return found.isEmpty ? Color(l.primaryColor) : Color(found.first.color);
  }

  Future<void> changeRole(Map<String, dynamic> member, String role) async {
    final admin = role == 'admin';
    if (!await confirm(
        context,
        admin ? 'Rendere questo membro admin?' : 'Rendere questo admin membro?',
        admin
            ? '${member['name']} potrà gestire inviti, richieste e membri della lega.'
            : '${member['name']} non potrà più gestire inviti, richieste e membri.')) {
      return;
    }
    await run(() async {
      await Cloud.client.rpc('bc_role', params: {
        'p_id': l.id,
        'p_player': member['player_id'],
        'p_role': role,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      title: 'Membri e inviti',
      toolbarHeight: 64,
      children: [
        if (l.myPlayer == null)
          AccountButton('Associa il tuo giocatore',
              onPressed:
                  busy ? null : () => run(() => Cloud.identify(context, l))),
        if (l.manage) ...[
          AccountButton('Crea o copia invito', onPressed: busy ? null : invite),
          for (final request in requests)
            _JoinRequestCard(
              request: request,
              busy: busy,
              review: (accept) => run(() async {
                await Cloud.client.rpc('hayko_review_request', params: {
                  'p_id': l.id,
                  'p_user': request['user_id'],
                  'p_accept': accept,
                });
              }),
            ),
          for (final member in members)
            _MemberRow(
              name:
                  '${member['name']}${member['user_id'] == l.currentUser ? ' · Tu' : ''}',
              role: _socialRoleName(member['role'] as String?),
              color: memberColor(member),
              current: member['user_id'] == l.currentUser,
              menu: member['role'] == 'president' ||
                      member['user_id'] == l.currentUser ||
                      (!l.president && !_manageableMembers.contains(member))
                  ? null
                  : _MemberActions(
                      canEdit: l.president && member['player_id'] != null,
                      canRemove: _manageableMembers.contains(member),
                      busy: busy,
                      edit: () => changeRole(member,
                          member['role'] == 'admin' ? 'member' : 'admin'),
                      remove: () => remove(member),
                    ),
            ),
        ] else
          for (final player
              in l.players.where((p) => l.roles.containsKey(p.id)))
            _MemberRow(
                name: '${player.name}${player.id == l.myPlayer ? ' · Tu' : ''}',
                role: _socialRoleName(l.roles[player.id]),
                color: Color(player.color),
                current: player.id == l.myPlayer),
      ],
    );
  }
}

class _ShareInvitePage extends StatefulWidget {
  const _ShareInvitePage({required this.league});
  final League league;

  @override
  State<_ShareInvitePage> createState() => _ShareInvitePageState();
}

class _ShareInvitePageState extends State<_ShareInvitePage> {
  bool busy = false;

  Future<void> copyInvite(String kind) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Cloud.store.flush();
      if (Cloud.store.pending > 0) {
        throw StateError('Completa prima la sincronizzazione.');
      }
      final token = await Cloud.client.rpc(
          kind == 'code' ? 'hayko_invite_short' : 'bc_invite',
          params: {'p_id': widget.league.id});
      await Clipboard.setData(ClipboardData(
          text: kind == 'code' ? '$token' : 'hayko://join?invite=$token'));
      if (!mounted) return;
      if (kind == 'code') {
        await showInviteCodeDialog(context, '$token');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Link invito copiato')));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
        title: 'Condividi invito',
        children: [
          Text(widget.league.name,
              style: const TextStyle(
                  fontSize: 24, height: 1.25, fontWeight: FontWeight.w800)),
          AccountButton('Copia link invito',
              onPressed: busy ? null : () => copyInvite('link')),
          AccountButton('Copia codice invito',
              outline: true, onPressed: busy ? null : () => copyInvite('code')),
        ],
      );
}

String _socialRoleName(String? role) => role == 'president'
    ? 'Presidente'
    : role == 'admin'
        ? 'Admin'
        : 'Membro';

String _initials(String name) {
  final words = name.split('·').first.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'H';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(
      {required this.name,
      required this.role,
      required this.color,
      required this.current,
      this.menu,
      this.onTap});
  final String name, role;
  final Color color;
  final bool current;
  final Widget? menu;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: current
                ? const BorderSide(color: HaykoColors.chalk)
                : BorderSide.none),
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
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Text(_initials(name),
                      style: const TextStyle(
                          color: HaykoColors.fieldBackground,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, height: 1.5)),
                      Text(role,
                          style: const TextStyle(
                              color: HaykoColors.mutedText,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                SizedBox(
                    width: menu is _MemberActions ? 80 : 64,
                    child:
                        Align(alignment: Alignment.centerRight, child: menu)),
              ]),
            ),
          ),
        ),
      );
}

class _MemberActions extends StatelessWidget {
  const _MemberActions(
      {required this.canEdit,
      required this.canRemove,
      required this.busy,
      required this.edit,
      required this.remove});
  final bool canEdit, canRemove, busy;
  final VoidCallback edit, remove;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (canEdit)
            IconButton(
              tooltip: 'Cambia ruolo',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: const EdgeInsets.all(8),
              onPressed: busy ? null : edit,
              icon: const Icon(Icons.edit_outlined, size: 22),
            ),
          if (canRemove)
            IconButton(
              tooltip: 'Rimuovi accesso',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: const EdgeInsets.all(8),
              color: const Color(0xffffb4ab),
              onPressed: busy ? null : remove,
              icon: const Icon(Icons.delete_outline, size: 22),
            ),
        ],
      );
}

class _JoinRequestCard extends StatelessWidget {
  const _JoinRequestCard(
      {required this.request, required this.busy, required this.review});
  final Map<String, dynamic> request;
  final bool busy;
  final ValueChanged<bool> review;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request['name'] as String,
              style: const TextStyle(
                  fontSize: 20, height: 1.3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Richiesta di accesso',
              style: TextStyle(color: HaykoColors.mutedText, fontSize: 14)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: AccountButton('Rifiuta',
                    outline: true,
                    onPressed: busy ? null : () => review(false))),
            const SizedBox(width: 8),
            Expanded(
                child: AccountButton('Approva',
                    onPressed: busy ? null : () => review(true))),
          ]),
        ]),
      );
}
