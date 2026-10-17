import 'dart:async';

import 'package:calcetto_mvp/features/leagues/invite_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const code = 'HK7P-9M4R';
  final clipboard = <String>[];
  bool fail = false;
  Completer<void>? pending;

  setUp(() {
    clipboard.clear();
    fail = false;
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (fail) throw PlatformException(code: 'unavailable');
        await pending?.future;
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showInviteCodeDialog(context, code),
          child: const Text('Apri invito'),
        );
      })),
    ));
    await tester.tap(find.text('Apri invito'));
    await tester.pumpAndSettle();
  }

  testWidgets('Copia codice scrive il codice mostrato, chiude e conferma',
      (tester) async {
    await open(tester);
    expect(find.text(code), findsOneWidget);
    await tester.tap(find.text('Copia codice'));
    await tester.pumpAndSettle();
    expect(clipboard, [code]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
        find.widgetWithText(SnackBar, 'Codice invito copiato'), findsOneWidget);
  });

  testWidgets('errore appunti conserva codice e permette di riprovare',
      (tester) async {
    fail = true;
    await open(tester);
    await tester.tap(find.text('Copia codice'));
    await tester.pumpAndSettle();
    expect(find.text(code), findsOneWidget);
    expect(find.text('Copia non riuscita. Riprova o seleziona il codice.'),
        findsOneWidget);
    expect(clipboard, isEmpty);
    fail = false;
    await tester.tap(find.text('Copia codice'));
    await tester.pumpAndSettle();
    expect(clipboard, [code]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'chiudere durante la copia non chiude anche la pagina sottostante',
      (tester) async {
    pending = Completer<void>();
    await open(tester);
    await tester.tap(find.text('Copia codice'));
    await tester.pump();
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Apri invito'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
