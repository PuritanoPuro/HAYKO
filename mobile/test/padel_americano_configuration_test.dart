import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/features/leagues/league_creation.dart';

void main() {
  testWidgets('schermata 24 crea Americano e conserva la configurazione',
      (tester) async {
    League? created;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => created = await Navigator.push<League>(
            context,
            MaterialPageRoute(
              builder: (_) => const LeagueCreation(
                initialSport: LeagueSport.padel,
                initialType: 'competition',
              ),
            ),
          ),
          child: const Text('Apri'),
        ),
      ),
    ));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Americano Test');
    await tester.tap(find.text('Campionato a coppie fisse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Americano').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configura Americano'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('padel-americano-configuration')),
        findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-padel-americano')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('create-padel-americano')));
    await tester.pumpAndSettle();
    expect(created, isNotNull);
    final config = League.fromJson(created!.toJson()).competitions.single;
    expect(config.kind, 'americano');
    expect(config.americanoPlayerCount, 8);
    expect(config.americanoCourts, 2);
    expect(config.americanoRounds, 7);
    expect(config.americanoTargetPoints, 24);
    expect(config.americanoRotatingPairs, isTrue);
  });
}
