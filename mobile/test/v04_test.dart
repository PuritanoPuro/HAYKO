import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/main.dart';
import 'package:calcetto_mvp/features/leagues/league_creation.dart';
import 'package:calcetto_mvp/features/leagues/league_settings.dart';
import 'package:calcetto_mvp/features/competitions/competition_hub.dart';
import 'package:calcetto_mvp/features/matches/team_editor.dart';
import 'package:calcetto_mvp/features/padel/padel_league_page.dart';

League league({bool doubleLeg = false}) {
  final l = League('l', 'Coppa',
      [for (var i = 0; i < 8; i++) Player('p$i', 'Giocatore $i')], [],
      type: 'competition',
      presets: [
        for (var i = 0; i < 4; i++)
          TeamPreset('t$i', 'Squadra $i', ['p${i * 2}', 'p${i * 2 + 1}'],
              numbers: {'p${i * 2}': 1, 'p${i * 2 + 1}': 2}),
      ]);
  l.competitions.add(Competition(
      'c', 'Coppa', 'league', 2, ['t0', 't1', 't2', 't3'],
      doubleLeg: doubleLeg));
  return l;
}

void main() {
  test('migrazione distingue leghe con competizioni senza eliminare dati', () {
    final l = league();
    final json = l.toJson()..remove('type');
    final copy = League.fromJson(json);
    expect(copy.type, 'competition');
    expect(copy.presets.length, 4);
    json['competitions'] = [];
    expect(League.fromJson(json).type, 'amateur');
  });
  test('competizione appena creata conserva la configurazione senza squadre',
      () {
    final l = League('l', 'Nuova', [], [],
        type: 'competition',
        competitions: [
          Competition('c', 'Nuova', 'knockout', 5, [], allowDraft: true)
        ]);
    final copy = League.fromJson(l.toJson());
    expect(copy.competitions.single.ready, false);
    expect(tournamentTies(copy, copy.competitions.single), isEmpty);
  });
  test('numeri di maglia persistono per squadra', () {
    final copy = League.fromJson(league().toJson());
    expect(copy.presets.first.numbers, {'p0': 1, 'p1': 2});
  });
  test('andata ritorno genera coppie invertite in giornate distinte', () {
    final l = league(doubleLeg: true), c = l.competitions.single;
    final fixtures = leagueFixtures(l, c);
    expect(fixtures.length, 12);
    expect(fixtures.map((t) => t.round).toSet().length, 6);
    final first = fixtures.first;
    final back = fixtures.singleWhere(
        (t) => t.teams[0] == first.teams[1] && t.teams[1] == first.teams[0]);
    expect(back.round, first.round + 3);
    final m = Match(
        id: 'm',
        format: 2,
        names: ['A', 'B'],
        teams: [
          ['p0', 'p1'],
          ['p6', 'p7']
        ],
        presetIds: [...first.teams],
        competitionId: 'c');
    validateCompetitionMatch(l, m);
    l.matches.add(m);
    expect(
        leagueFixtures(l, c)
            .singleWhere(
                (t) => t.round == first.round && t.teams[0] == first.teams[0])
            .match,
        m);
    expect(
        leagueFixtures(l, c)
            .singleWhere(
                (t) => t.round == back.round && t.teams[0] == back.teams[0])
            .match,
        isNull);
    expect(
        () => validateCompetitionMatch(
            l,
            Match(
                id: 'dup',
                format: 2,
                names: ['A', 'B'],
                teams: m.teams,
                presetIds: m.presetIds,
                competitionId: 'c')),
        throwsStateError);
  });
  testWidgets('footer amatoriale contiene solo tre sezioni', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LeaguePage(
            league: League('l', 'Amici', [], []), save: () async {})));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 3);
    expect(find.text('Giocatori'), findsOneWidget);
    expect(find.text('Calendario'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byTooltip('Impostazioni lega'), findsOneWidget);
    expect(find.byTooltip('Impostazioni app'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('footer competizione mostra squadre e calendario',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LeaguePage(league: league(), save: () async {})));
    expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        4);
    expect(find.text('Squadre'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    await tester.tap(find.text('Squadre'));
    await tester.pumpAndSettle();
    expect(find.text('Squadre partecipanti'), findsOneWidget);
    expect(find.text('+ Squadra'), findsOneWidget);
    expect(
        find.text('Aggiungi almeno due squadre per completare il campionato.'),
        findsOneWidget);
    expect(find.text('2 giocatori'), findsAtLeastNWidgets(3));
    expect(find.text('›'), findsAtLeastNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione lega chiede amatoriale o competizione',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeagueCreation()));
    expect(find.text('Amatoriale'), findsOneWidget);
    await tester.tap(find.text('Competizione'));
    await tester.pumpAndSettle();
    expect(find.text('Campionato'), findsOneWidget);
    expect(find.text('Andata e ritorno'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione Padel mostra formati e Americano', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeagueCreation()));
    await tester.tap(find.text('Padel'));
    await tester.tap(find.text('Competizione'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova competizione'), findsOneWidget);
    expect(find.text('Crea competizione'), findsOneWidget);
    expect(find.text('Campionato a coppie fisse'), findsOneWidget);
    expect(find.text('Formato partita'), findsOneWidget);
    expect(find.text('Meglio di 3 set'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(
        find.text(
            'Dopo la creazione aggiungi le coppie e i giocatori nella sezione Coppie.'),
        findsOneWidget);
    await tester.tap(find.text('Campionato a coppie fisse'));
    await tester.pumpAndSettle();
    expect(find.text('Americano'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'nuova lega Padel replica la schermata 02 senza riselezionare lo sport',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LeagueCreation(initialSport: LeagueSport.padel)));

    expect(find.text('Nuova lega'), findsOneWidget);
    expect(find.text('Sport'), findsNothing);
    expect(find.text('Calcio'), findsNothing);
    expect(find.text('Padel'), findsNothing);
    expect(find.text('Amatoriale'), findsOneWidget);
    expect(find.text('Competizione'), findsOneWidget);
    expect(
        find.text(
            'Partite tra amici, coppie flessibili e statistiche individuali.'),
        findsOneWidget);
    expect(find.text('Crea lega'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione lega Padel restituisce un payload salvabile',
      (tester) async {
    League? created;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async => created = await Navigator.push<League>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeagueCreation(
                            initialSport: LeagueSport.padel))),
                child: const Text('Apri')))));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Padel Test');
    await tester.tap(find.text('Crea lega'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.sport, LeagueSport.padel);
    expect(created!.type, 'amateur');
    expect(created!.primaryColor, 0xff63c7f2);
    expect(created!.competitions, isEmpty);
    expect(created!.toJson()['sport'], LeagueSport.padel);
  });
  testWidgets(
      'creazione competizione Padel restituisce configurazione completa',
      (tester) async {
    League? created;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async => created = await Navigator.push<League>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeagueCreation(
                            initialSport: LeagueSport.padel))),
                child: const Text('Apri')))));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Campionato Padel');
    await tester.tap(find.text('Competizione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crea competizione'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.sport, LeagueSport.padel);
    expect(created!.type, 'competition');
    expect(created!.competitions.single.kind, 'league');
    expect(created!.competitions.single.format, 3);
    expect(created!.competitions.single.doubleLeg, isTrue);
  });
  testWidgets('contenitore Padel è separato dalle schermate calcio',
      (tester) async {
    final padel =
        League('p', 'Padel del giovedì', [], [], sport: LeagueSport.padel);
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: padel, save: () async {})));

    expect(find.text('Partite programmate'), findsOneWidget);
    expect(find.text('Nessuna partita programmata.'), findsOneWidget);
    expect(find.text('Partite'), findsOneWidget);
    expect(find.text('Giocatori'), findsOneWidget);
    expect(find.text('Statistiche'), findsOneWidget);
    expect(find.text('Squadre'), findsNothing);
    expect(find.byTooltip('Le tue leghe'), findsOneWidget);
    expect(find.byTooltip('Impostazioni lega'), findsOneWidget);
    expect(find.byTooltip('Impostazioni app'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.text('+ Partita'), findsOneWidget);
    expect(tester.getSize(find.byType(FloatingActionButton)).height, 48);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('schermate Padel 06 07 e 08 filtrano le partite per stato',
      (tester) async {
    final players = [
      Player('a', 'Filippo'),
      Player('b', 'Andrea'),
      Player('c', 'Luca'),
      Player('d', 'Marco')
    ];
    Match match(String id, String status, {List<Goal>? goals}) => Match(
        id: id,
        format: 2,
        names: const ['Filippo / Andrea', 'Luca / Marco'],
        teams: const [
          ['a', 'b'],
          ['c', 'd']
        ],
        status: status,
        startedAt: status == 'scheduled' ? null : '2026-11-09T20:00:00Z',
        finishedAt: status == 'finished' ? '2026-11-09T21:00:00Z' : null,
        scheduledAt: '2026-11-09T20:00:00Z',
        venue: 'Campo 2',
        teamColors: const [0xff63c7f2, 0xfff29c52],
        goals: goals);
    final padel = League(
        'p',
        'Padel del giovedì',
        players,
        [
          match('scheduled', 'scheduled'),
          match('live', 'live', goals: [
            Goal(id: 'g1', team: 0, scorer: 'a', time: '2026-11-09T20:10:00Z')
          ]),
          match('finished', 'finished', goals: [
            Goal(id: 'g2', team: 0, scorer: 'a', time: '2026-11-09T20:10:00Z'),
            Goal(id: 'g3', team: 0, scorer: 'b', time: '2026-11-09T20:20:00Z'),
            Goal(id: 'g4', team: 1, scorer: 'c', time: '2026-11-09T20:30:00Z')
          ])
        ],
        sport: LeagueSport.padel);
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: padel, save: () async {})));

    expect(find.text('Partite in corso'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('padel-match-tab-scheduled')));
    await tester.pump();
    expect(find.text('Partite programmate'), findsOneWidget);
    expect(find.textContaining('Campo 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('padel-match-tab-finished')));
    await tester.pump();
    expect(find.text('Partite terminate'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Filippo / Andrea'), findsOneWidget);
    expect(find.text('Luca / Marco'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('impostazioni Padel seguono la schermata 04', (tester) async {
    final padel = League('p', 'Padel del giovedì', [], [],
        sport: LeagueSport.padel, primaryColor: 0xff63c7f2);
    await tester.pumpWidget(MaterialApp(
        home: LeagueSettingsPage(
            league: padel, save: () async {}, delete: () async {})));

    expect(find.text('Impostazioni lega'), findsOneWidget);
    expect(find.text('Nome lega'), findsOneWidget);
    expect(find.text('Salva nome'), findsOneWidget);
    expect(find.text('Colore primario'), findsOneWidget);
    expect(find.text('#63C7F2'), findsOneWidget);
    expect(find.text('Colore secondario'), findsNothing);
    expect(find.text('Elimina lega'), findsOneWidget);
  });
  testWidgets('colore lega Padel viene selezionato e incluso nel salvataggio',
      (tester) async {
    final padel = League('p', 'Padel', [], [],
        sport: LeagueSport.padel, primaryColor: 0xff63c7f2);
    Map<String, dynamic>? saved;
    await tester.pumpWidget(MaterialApp(
        home: LeagueSettingsPage(
            league: padel, save: () async => saved = padel.toJson())));

    await tester.tap(find.text('#63C7F2'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Colore personalizzato'), 'E35B82');
    await tester.tap(find.text('Seleziona'));
    await tester.pumpAndSettle();

    expect(padel.primaryColor, 0xffe35b82);
    expect(saved?['primaryColor'], 0xffe35b82);
    expect(find.text('#E35B82'), findsOneWidget);
  });
  testWidgets('squadra partecipante apre direttamente la modifica',
      (tester) async {
    final l = league();
    await tester.pumpWidget(MaterialApp(
        home: CompetitionTeams(league: l, save: () async {}, changed: () {})));
    await tester.tap(find.text(l.presets.first.name));
    await tester.pumpAndSettle();
    expect(find.text('Modifica squadra'), findsOneWidget);
    expect(find.byKey(const ValueKey('competition-team-name')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('giocatore semplice vede la squadra senza poterla modificare',
      (tester) async {
    final l = league()
      ..shared = true
      ..myRole = 'member';
    await tester.pumpWidget(MaterialApp(
        home: CompetitionTeams(league: l, save: () async {}, changed: () {})));
    expect(find.text('+ Squadra'), findsNothing);
    await tester.tap(find.text(l.presets.first.name));
    await tester.pumpAndSettle();
    expect(find.text('Modifica squadra'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creazione squadra iscrive partecipante con numeri automatici',
      (tester) async {
    final l = League(
        'l', 'Nuova', [Player('a', 'Alfa'), Player('b', 'Beta')], [],
        type: 'competition',
        competitions: [
          Competition('c', 'C', 'league', 2, [], allowDraft: true)
        ]);
    await tester.pumpWidget(MaterialApp(
        home: TeamEditor(
            league: l,
            save: () async {},
            initialFormat: 2,
            competition: l.competitions.single)));
    await tester.enterText(find.byType(TextFormField), 'Uno');
    for (final name in ['Alfa', 'Beta']) {
      await tester.tap(find.text('+ Giocatore'));
      await tester.pumpAndSettle();
      expect(find.text('Nuovo giocatore'), findsOneWidget);
      expect(find.text('Squadra'), findsOneWidget);
      expect(find.text('Uno'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('roster-player-name')), name);
      await tester.tap(find.text('Aggiungi giocatore'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Salva squadra'));
    await tester.pumpAndSettle();
    expect(l.competitions.single.teamIds, [l.presets.single.id]);
    expect(l.presets.single.numbers.values, [1, 2]);
    expect(l.presets.single.players.length, 2);
  });
}
