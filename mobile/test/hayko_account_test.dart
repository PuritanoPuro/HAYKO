import 'dart:async';
import 'dart:convert';
import 'package:calcetto_mvp/features/account/auth_pages.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/account/invite_links.dart';
import 'package:calcetto_mvp/features/account/league_store.dart';
import 'package:calcetto_mvp/features/account/profile_page.dart';
import 'package:calcetto_mvp/features/account/profile_service.dart';
import 'package:calcetto_mvp/features/account/settings_page.dart';
import 'package:calcetto_mvp/design_system/hayko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> row(String status) => {
      'state': {
        'id': 'league',
        'matches': [
          <String, dynamic>{'id': 'match', 'status': status}
        ]
      },
      'revision': 0,
      'role': 'president',
      'player_id': 'p',
      'members': [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('dati obbligatori e profilo privato separato dal nome in lega', () {
    expect(requiredName('   '), isNotNull);
    expect(validEmail('test@example.com'), isNull);
    expect(validEmail('nome senza email'), isNotNull);
    expect(validPassword('1234567'), isNotNull);
    const p = HaykoProfile('Filippo', 'Fuschini', 'Fusch');
    expect(p.complete, isTrue);
    expect(p.firstName, 'Filippo');
    expect(HaykoProfile.fromJson(p.toJson()).nickname, 'Fusch');
  });
  test('link accetta solo inviti HAYKO validi', () {
    final token = List.filled(64, 'a').join();
    expect(inviteCode(Uri.parse('hayko://join?invite=$token')), token);
    expect(inviteCode(Uri.parse('bordocampo://join?invite=$token')), token);
    expect(inviteCode(Uri.parse('https://altro.example/join?invite=$token')),
        isNull);
    expect(inviteCode(Uri.parse('hayko://join?invite=breve')), isNull);
  });
  testWidgets(
      'accesso e registrazione mostrano campi distinti e conservano email',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: buildHaykoTheme(), home: const AuthPage()));
    expect(find.text('Accedi a HAYKO'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).first, 'filippo@example.com');
    await tester.tap(find.text('Crea un account'));
    await tester.pumpAndSettle();
    expect(find.text('Crea il tuo account'), findsOneWidget);
    expect(find.text('Nickname'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(3))
            .controller!
            .text,
        'filippo@example.com');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Torna all’accesso'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'filippo@example.com');
  });
  testWidgets(
      'profilo salva nome cognome nickname e mantiene email non modificabile',
      (tester) async {
    HaykoProfile? saved;
    await tester.pumpWidget(MaterialApp(
        theme: buildHaykoTheme(),
        home: ProfilePage(
          initial: const HaykoProfile('Filippo', 'Fuschini', 'Fusch'),
          email: 'filippo@example.com',
          saveProfile: (first, last, nickname) async {
            saved = HaykoProfile(first, last, nickname);
            return saved!;
          },
        )));
    final email =
        tester.widgetList<AccountField>(find.byType(AccountField)).last;
    expect(email.readOnly, isTrue);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .style
            .fontFamily,
        'BricolageGrotesque');
    await tester.enterText(find.byType(TextFormField).at(2), 'Fil');
    await tester.scrollUntilVisible(find.text('Salva profilo'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Salva profilo'));
    await tester.pumpAndSettle();
    expect(saved!.nickname, 'Fil');
    expect(saved!.firstName, 'Filippo');
    expect(saved!.lastName, 'Fuschini');
    expect(find.text('Profilo salvato'), findsOneWidget);
  });
  testWidgets('impostazioni non duplicano il collegamento al profilo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    expect(find.text('Profilo'), findsNothing);
    expect(find.text('Impostazioni notifiche'), findsOneWidget);
  });
  test(
      'offline conserva sequenza avvio gol chiusura e riprende dopo riapertura',
      () async {
    final offline = LeagueStore(
        'userA', (name, params) async => throw StateError('offline'));
    final started = row('live');
    started['state']['matches'][0]['goals'] = <Map<String, dynamic>>[];
    final scored = row('live');
    scored['state']['matches'][0]['goals'] = [
      {'id': 'goal-1', 'team': 0, 'scorer': 'p'}
    ];
    final finished = row('finished');
    finished['state']['matches'][0]['goals'] =
        scored['state']['matches'][0]['goals'];
    await offline.queue(started);
    await offline.queue(scored);
    await offline.queue(finished);
    await offline.flush();
    expect(offline.pending, 3);
    final states = <String>[], revisions = <int>[], goalCounts = <int>[];
    final online = LeagueStore('userA', (name, params) async {
      states.add(params['p_state']['matches'][0]['status'] as String);
      revisions.add(params['p_revision'] as int);
      goalCounts.add((params['p_state']['matches'][0]['goals'] as List).length);
      return revisions.length;
    });
    await online.initialize();
    expect(online.pending, 3);
    await online.flush();
    expect(states, ['live', 'live', 'finished']);
    expect(goalCounts, [0, 1, 1]);
    expect(revisions, [0, 1, 2]);
    expect(online.pending, 0);
  });
  test('una richiesta lenta non blocca un nuovo salvataggio locale', () async {
    final response = Completer<int>();
    var calls = 0;
    final store = LeagueStore(
        'userA', (name, params) async => calls++ == 0 ? response.future : 2);
    await store.queue(row('live'));
    final flushing = store.flush();
    await Future<void>.delayed(Duration.zero);
    await store.queue(row('finished')).timeout(const Duration(seconds: 1));
    expect(store.pending, 2);
    response.complete(1);
    await flushing;
    expect(store.pending, 0);
  });
  test('un conflitto unisce modifiche locali e remote non sovrapposte',
      () async {
    final initial = row('scheduled');
    initial['state']['name'] = 'Lega iniziale';
    initial['state']['primaryColor'] = 1;
    initial['revision'] = 1;
    var saveAttempts = 0;
    Map<String, dynamic>? savedState;
    final store = LeagueStore('userA', (name, params) async {
      if (name == 'bc_list') return [initial];
      if (name == 'bc_get') {
        final remote = row('scheduled');
        remote['state']['name'] = 'Nome dal secondo dispositivo';
        remote['state']['primaryColor'] = 1;
        remote['revision'] = 2;
        return remote;
      }
      if (name == 'bc_save') {
        saveAttempts++;
        if (saveAttempts == 1) throw StateError('REVISION_CONFLICT');
        expect(params['p_revision'], 2);
        savedState = Map<String, dynamic>.from(params['p_state'] as Map);
        return 3;
      }
      throw StateError('RPC inattesa: $name');
    });

    await store.list();
    final local = row('scheduled');
    local['state']['name'] = 'Lega iniziale';
    local['state']['primaryColor'] = 42;
    local['revision'] = 1;
    await store.queue(local);
    await store.flush();

    expect(store.pending, 0);
    expect(savedState!['name'], 'Nome dal secondo dispositivo');
    expect(savedState!['primaryColor'], 42);
    expect(store.problem, isNull);
  });

  test('colore lega sincronizzato è visibile da un secondo dispositivo',
      () async {
    var remote = row('scheduled');
    remote['state']['primaryColor'] = 0xff63c7f2;
    Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
      if (name == 'bc_list') return [remote];
      if (name == 'bc_save') {
        expect(params['p_revision'], remote['revision']);
        remote = {
          ...remote,
          'state': params['p_state'],
          'revision': (remote['revision'] as int) + 1,
        };
        return remote['revision'];
      }
      throw StateError('RPC inattesa: $name');
    }

    final firstDevice = LeagueStore('first-device', rpc);
    final secondDevice = LeagueStore('second-device', rpc);
    await firstDevice.list();
    final local = row('scheduled');
    local['state']['primaryColor'] = 0xffe35b82;

    await firstDevice.queue(local);
    await firstDevice.flush();

    expect(firstDevice.pending, 0);
    expect(firstDevice.problem, isNull);
    expect((await secondDevice.list()).single['state']['primaryColor'],
        0xffe35b82);
  });

  test('colore lega non modifica partite Padel terminate legacy', () async {
    final old = row('finished');
    old['state']['sport'] = 'padel';
    old['state']['primaryColor'] = 0xff63c7f2;
    final updated = row('finished');
    updated['state']['sport'] = 'padel';
    updated['state']['primaryColor'] = 0xffe35b82;
    updated['state']['matches'][0]['padelPointTotals'] = [0, 0];
    updated['state']['matches'][0]['padelSetDurationsSeconds'] = [];
    updated['state']['matches'][0]['padelSetStartedAt'] = null;
    updated['state']['matches'][0]['padelFirstServerId'] = null;
    final store = LeagueStore('padel-color', (name, params) async {
      if (name == 'bc_list') return [old];
      if (name == 'bc_save') {
        final match = params['p_state']['matches'][0] as Map;
        expect(match.containsKey('padelPointTotals'), isFalse);
        expect(match.containsKey('padelSetDurationsSeconds'), isFalse);
        expect(match.containsKey('padelSetStartedAt'), isFalse);
        expect(match.containsKey('padelFirstServerId'), isFalse);
        return 1;
      }
      throw StateError('RPC inattesa: $name');
    });
    await store.list();
    await store.queue(updated);
    await store.flush();
    expect(store.pending, 0);
    expect(store.problem, isNull);
  });

  test('coda legacy viene riparata dopo MATCH_FINISHED', () async {
    final old = row('finished');
    old['state']['sport'] = 'padel';
    final updated = row('finished');
    updated['state']['sport'] = 'padel';
    updated['state']['primaryColor'] = 0xffe35b82;
    updated['state']['matches'][0]['padelPointTotals'] = [0, 0];
    updated['state']['matches'][0]['padelSetDurationsSeconds'] = [];
    updated['state']['matches'][0]['padelSetStartedAt'] = null;
    updated['state']['matches'][0]['padelFirstServerId'] = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'hayko.leagues.legacy',
        jsonEncode({
          'rows': [updated],
          'operations': [
            {
              'id': 'league',
              'revision': 0,
              'state': updated['state'],
              'base_state': old['state'],
            }
          ],
        }));
    var attempts = 0;
    final store = LeagueStore('legacy', (name, params) async {
      attempts++;
      final match = params['p_state']['matches'][0] as Map;
      if (match.containsKey('padelPointTotals') ||
          match.containsKey('padelSetStartedAt')) {
        throw StateError('MATCH_FINISHED');
      }
      return 1;
    });
    await store.flush();
    expect(attempts, 2);
    expect(store.pending, 0);
    expect(store.problem, isNull);
  });

  test('un conflitto sullo stesso dato non sovrascrive il server', () async {
    final initial = row('scheduled');
    initial['state']['name'] = 'Lega iniziale';
    initial['revision'] = 1;
    var saveAttempts = 0;
    final store = LeagueStore('userA', (name, params) async {
      if (name == 'bc_list') return [initial];
      if (name == 'bc_get') {
        final remote = row('scheduled');
        remote['state']['name'] = 'Nome remoto';
        remote['revision'] = 2;
        return remote;
      }
      if (name == 'bc_save') {
        saveAttempts++;
        throw StateError('REVISION_CONFLICT');
      }
      throw StateError('RPC inattesa: $name');
    });

    await store.list();
    final local = row('scheduled');
    local['state']['name'] = 'Nome locale';
    local['revision'] = 1;
    await store.queue(local);
    await store.flush();

    expect(saveAttempts, 1);
    expect(store.pending, 1);
    expect(store.problem, contains('altro dispositivo'));
  });
  test('piu richieste di sincronizzazione attendono lo stesso invio', () async {
    final response = Completer<int>();
    final store = LeagueStore('userA', (name, params) async => response.future);
    await store.queue(row('live'));

    final first = store.flush();
    await Future<void>.delayed(Duration.zero);
    final second = store.flush();
    var secondCompleted = false;
    second.whenComplete(() => secondCompleted = true);

    await Future<void>.delayed(Duration.zero);
    expect(secondCompleted, isFalse);
    expect(store.pending, 1);

    response.complete(1);
    await Future.wait([first, second]);
    expect(secondCompleted, isTrue);
    expect(store.pending, 0);
  });
  test('un salvataggio negato non blocca le modifiche successive', () async {
    final calls = <String>[];
    final store = LeagueStore('userA', (name, params) async {
      calls.add(params['p_id'] as String);
      if (calls.length == 1) {
        throw StateError('PRESIDENT_REQUIRED');
      }
      return 1;
    });
    await store.queue(row('live'));
    final second = row('finished');
    second['state']['id'] = 'another-league';
    await store.queue(second);

    await store.flush();

    expect(calls, ['league', 'another-league']);
    expect(store.pending, 0);
    expect(store.problem, contains('non consentita'));
    final reopened = LeagueStore('userA', (name, params) async => 0);
    await reopened.initialize();
    expect(reopened.pending, 0);
  });
  test('cache e modifiche offline sono separate per account', () async {
    final a = LeagueStore('userA', (name, params) async => 0);
    await a.queue(row('live'));
    final b = LeagueStore('userB', (name, params) async => []);
    await b.initialize();
    expect(b.rows, isEmpty);
    expect(b.pending, 0);
    final reopened = LeagueStore('userA', (name, params) async => 0);
    await reopened.initialize();
    expect(reopened.pending, 1);
  });
}
