import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/padel/padel_couple_edit_page.dart';
import 'package:calcetto_mvp/features/padel/padel_couples_page.dart';
import 'package:calcetto_mvp/features/padel/padel_league_page.dart';
import 'package:calcetto_mvp/features/leagues/player_edit_page.dart';

League padelLeague() => League(
      'padel',
      'Padel del giovedì',
      [
        Player('a', 'Andrea Rossi', color: 0xffe3f24a),
        Player('f', 'Filippo Fuschini', color: 0xffff7a3d),
        Player('l', 'Luca Bianchi', color: 0xff63c7f2),
        Player('m', 'Marco Verdi', color: 0xff38d9a9),
      ],
      [],
      sport: LeagueSport.padel,
    );

void main() {
  testWidgets('sezione Padel mostra giocatori e apre le coppie salvate',
      (tester) async {
    final league = padelLeague();
    league.myPlayer = 'f';
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: league, save: () async {})));

    await tester.tap(find.text('Giocatori'));
    await tester.pumpAndSettle();
    expect(find.text('Giocatori della lega'), findsOneWidget);
    expect(find.text('Andrea Rossi'), findsOneWidget);
    expect(find.text('Filippo Fuschini · Tu'), findsOneWidget);
    expect(find.text('Coppie salvate'), findsOneWidget);
    await tester.tap(find.text('Coppie salvate'));
    await tester.pumpAndSettle();
    expect(find.byType(PadelCouplesPage), findsOneWidget);
    expect(find.text('+ Coppia'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('+ Giocatore'), 200);
    expect(find.text('+ Giocatore'), findsOneWidget);
  });

  testWidgets('modifica giocatore Padel usa la schermata dedicata',
      (tester) async {
    final league = padelLeague();
    await tester.pumpWidget(
        MaterialApp(home: PadelLeaguePage(league: league, save: () async {})));

    await tester.tap(find.text('Giocatori'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifica giocatore').first);
    await tester.pumpAndSettle();

    expect(find.byType(PlayerEditPage), findsOneWidget);
    expect(find.text('Modifica giocatore'), findsOneWidget);
    expect(find.text('Colore giocatore'), findsOneWidget);
    expect(find.text('Salva'), findsOneWidget);
    expect(find.text('Elimina giocatore'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
  });

  testWidgets('coppie salvate apre la modifica della coppia', (tester) async {
    final league = padelLeague();
    league.presets
        .add(TeamPreset('c', 'I Falchi', ['a', 'f'], color: 0xff63c7f2));
    await tester.pumpWidget(
        MaterialApp(home: PadelCouplesPage(league: league, save: () async {})));

    expect(find.text('I Falchi'), findsOneWidget);
    expect(find.text('Andrea Rossi · Filippo Fuschini'), findsOneWidget);
    await tester.tap(find.text('I Falchi'));
    await tester.pumpAndSettle();

    expect(find.byType(PadelCoupleEditPage), findsOneWidget);
    expect(find.text('Modifica coppia'), findsOneWidget);
    expect(find.text('Salva coppia'), findsOneWidget);
    expect(find.text('Elimina coppia'), findsOneWidget);
  });

  testWidgets('modifica coppia mostra prima solo i due giocatori selezionati',
      (tester) async {
    final league = padelLeague();
    league.myPlayer = 'f';
    final couple = TeamPreset('c', 'I Falchi', ['a', 'f'], color: 0xff63c7f2);
    league.presets.add(couple);
    await tester.pumpWidget(MaterialApp(
        home: PadelCoupleEditPage(
            league: league, couple: couple, save: () async {})));

    expect(find.text('Andrea Rossi'), findsOneWidget);
    expect(find.text('Filippo Fuschini · Tu'), findsOneWidget);
    expect(find.text('Luca Bianchi'), findsNothing);
    expect(find.byTooltip('Rimuovi dalla coppia'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Rimuovi dalla coppia').first);
    await tester.pump();
    expect(find.text('Luca Bianchi'), findsOneWidget);
  });

  testWidgets('una coppia Padel richiede e salva esattamente due giocatori',
      (tester) async {
    final league = padelLeague();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: PadelCoupleEditPage(league: league, save: () async => saves++)));

    await tester.enterText(find.byType(TextFormField), 'Filippo / Andrea');
    await tester.tap(find.text('Andrea Rossi'));
    await tester.pump();
    await tester.tap(find.text('Filippo Fuschini'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva coppia').last);
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(league.presets, hasLength(1));
    expect(league.presets.single.players.toSet(), {'a', 'f'});
    expect(league.presets.single.color, 0xff63c7f2);
  });

  testWidgets('non permette di selezionare un terzo giocatore nella coppia',
      (tester) async {
    final league = padelLeague();
    await tester.pumpWidget(MaterialApp(
        home: PadelCoupleEditPage(league: league, save: () async {})));

    await tester.tap(find.text('Andrea Rossi'));
    await tester.tap(find.text('Filippo Fuschini'));
    await tester.tap(find.text('Luca Bianchi'));
    await tester.pump();

    expect(find.text('Una coppia Padel è composta da due giocatori.'),
        findsOneWidget);
  });
}
