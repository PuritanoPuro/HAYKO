import 'dart:async';

import 'package:calcetto_mvp/design_system/hayko_home.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/home/home_page.dart';
import 'package:calcetto_mvp/design_system/hayko_theme.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la home ignora tocchi di navigazione ripetuti', () async {
    final gate = HomeNavigationGate();
    final release = Completer<void>();
    var openings = 0;

    final first = gate.run(() async {
      openings++;
      await release.future;
    });
    await Future<void>.delayed(Duration.zero);
    await gate.run(() async => openings++);

    expect(openings, 1);
    release.complete();
    await first;
    await gate.run(() async => openings++);
    expect(openings, 2);
  });
  Widget home({
    List<League> leagues = const [],
    ValueChanged<League>? open,
    ValueChanged<String>? create,
    VoidCallback? shared,
    VoidCallback? account,
    VoidCallback? settings,
    bool loading = false,
    String? error,
    VoidCallback? retry,
    double scale = 1,
  }) =>
      MaterialApp(
        theme: buildHaykoTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: HaykoHome(
            leagues: leagues,
            loading: loading,
            error: error,
            onOpenLeague: open ?? (_) {},
            onCreateLeague: create ?? (_) {},
            onSharedLeagues: shared ?? () {},
            onAccount: account ?? () {},
            onSettings: settings ?? () {},
            onRetry: retry ?? () {},
          ),
        ),
      );

  testWidgets('home usa le leghe reali e conserva dati e azioni',
      (tester) async {
    final amateur = League('a', 'Amici', [Player('p', 'Filippo')], [],
        primaryColor: 0xffe3f24a);
    final competition = League('b', 'Coppa', [], [], type: 'competition');
    final before = [amateur.toJson(), competition.toJson()];
    League? selected;
    var created = 0, shared = 0, account = 0, settings = 0;
    await tester.pumpWidget(home(
      leagues: [amateur, competition],
      open: (l) => selected = l,
      create: (_) => created++,
      shared: () => shared++,
      account: () => account++,
      settings: () => settings++,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Amatoriale · 1 giocatori · 0 partite'), findsOneWidget);
    expect(find.text('Competizione · 0 squadre · 0 partite'), findsOneWidget);
    expect(find.byIcon(Icons.groups), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    final footballAccent =
        tester.widget<Container>(find.byKey(const ValueKey('league-accent-a')));
    expect((footballAccent.decoration as BoxDecoration).color,
        const Color(0xffbbf568));
    final footballIcon =
        tester.widget<Container>(find.byKey(const ValueKey('league-icon-a')));
    expect((footballIcon.decoration as BoxDecoration).color,
        const Color(0xffe3f24a));
    expect(tester.widget<Icon>(find.byIcon(Icons.chevron_right).first).color,
        const Color(0xffbbf568));
    await tester.tap(find.text('Coppa'));
    expect(selected, same(competition));
    await tester.tap(find.text('+ NUOVA LEGA'));
    await tester.tap(find.text('ACCEDI CON CODICE'));
    await tester.tap(find.byTooltip('Profilo e account'));
    await tester.tap(find.byTooltip('Impostazioni'));
    expect([created, shared, account, settings], [1, 1, 1, 1]);
    expect([amateur.toJson(), competition.toJson()], before);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.textContaining('MVP locale'), findsNothing);
    expect(find.text('HAYKO'), findsOneWidget);
    expect(find.text('CALCIO'), findsOneWidget);
    expect(find.text('PADEL'), findsOneWidget);
    expect(find.text('TENNIS'), findsOneWidget);
  });

  testWidgets('home Padel usa accento sport e icone del tipo di lega',
      (tester) async {
    final padel = League('p', 'Padel del giovedì', [], [],
        sport: LeagueSport.padel, primaryColor: 0xffffab64);
    final tournament = League('t', 'Torneo Padel', [], [],
        sport: LeagueSport.padel, type: 'competition');
    await tester.pumpWidget(home(leagues: [padel, tournament]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PADEL'));
    await tester.pumpAndSettle();

    expect(find.text('0 giocatori · 0 coppie'), findsOneWidget);
    expect(find.byIcon(Icons.groups), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    final padelAccent =
        tester.widget<Container>(find.byKey(const ValueKey('league-accent-p')));
    expect((padelAccent.decoration as BoxDecoration).color,
        HaykoColors.padelAccent);
    final padelIcon =
        tester.widget<Container>(find.byKey(const ValueKey('league-icon-p')));
    expect(
        (padelIcon.decoration as BoxDecoration).color, const Color(0xffffab64));
    expect(tester.widget<Icon>(find.byIcon(Icons.chevron_right).first).color,
        HaykoColors.padelAccent);
  });

  testWidgets('selettore sport usa geometria Figma e pillola animata',
      (tester) async {
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const ValueKey('sport-switcher'))).height,
        56);
    final before = tester.widget<AnimatedPositioned>(
        find.byKey(const ValueKey('sport-selection-pill')));
    expect(before.left, 0);

    await tester.tap(find.text('PADEL'));
    await tester.pump(const Duration(milliseconds: 120));
    final during = tester.widget<AnimatedPositioned>(
        find.byKey(const ValueKey('sport-selection-pill')));
    expect(during.left, greaterThan(0));
    expect(find.byType(AnimatedDefaultTextStyle), findsAtLeastNWidgets(3));
    await tester.pumpAndSettle();
  });

  testWidgets('tutta la superficie della tab sport è cliccabile',
      (tester) async {
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('sport-switcher')));
    await tester.tapAt(Offset(rect.left + rect.width * 0.64, rect.top + 7));
    await tester.pump(const Duration(milliseconds: 20));

    final pill = tester.widget<AnimatedPositioned>(
        find.byKey(const ValueKey('sport-selection-pill')));
    expect(pill.left, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'nomi lunghi e testo ingrandito restano scorrevoli su telefono stretto',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var created = false;
    await tester.pumpWidget(home(
      leagues: [
        for (var i = 0; i < 15; i++)
          League('$i', 'Squadra degli amici del giovedì sera $i', [], [])
      ],
      create: (_) => created = true,
      scale: 2,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('+ NUOVA LEGA'), 400,
        maxScrolls: 60);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ NUOVA LEGA'));
    expect(created, isTrue);
    await tester.scrollUntilVisible(find.text('ACCEDI CON CODICE'), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('archivio vuoto ed errore mantengono creazione e recupero',
      (tester) async {
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Crea una lega, aggiungi i giocatori e organizza la prima partita.'),
        findsOneWidget);
    expect(find.text('+ NUOVA LEGA'), findsOneWidget);
    var retried = false;
    await tester.pumpWidget(
        home(error: 'Archivio non disponibile', retry: () => retried = true));
    await tester.pumpAndSettle();
    expect(find.text('+ NUOVA LEGA'), findsNothing);
    await tester.tap(find.text('Riprova'));
    expect(retried, isTrue);
    await tester.pumpWidget(home(loading: true));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('+ NUOVA LEGA'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
