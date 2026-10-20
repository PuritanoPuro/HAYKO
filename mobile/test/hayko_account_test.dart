import 'dart:async';
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
