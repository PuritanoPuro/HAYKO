import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/shared/customization.dart';
import 'package:calcetto_mvp/design_system/hayko_theme.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

void main() {
  test('testi e azione primaria leggibili sulle superfici Campo', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + 0.05) / (second + 0.05)
          : (second + 0.05) / (first + 0.05);
    }

    for (final surface in [
      HaykoColors.fieldBackground,
      HaykoColors.fieldSurface
    ]) {
      expect(contrast(HaykoColors.chalk, surface), greaterThanOrEqualTo(4.5));
      expect(
          contrast(HaykoColors.mutedText, surface), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(HaykoColors.chalk, HaykoColors.fieldBackground),
        greaterThanOrEqualTo(4.5));
  });
  testWidgets('lega personalizzata conserva il tema Campo e i propri dati',
      (tester) async {
    final l = League('l', 'Lega', [], [],
        primaryColor: 0xffff0000, secondaryColor: 0xff40c9ff);
    final before = l.toJson();
    await tester.pumpWidget(MaterialApp(
        theme: buildHaykoTheme(),
        home: Builder(
            builder: (context) => Theme(
                data: leagueTheme(context, l),
                child: const Scaffold(
                    body: FilledButton(
                        onPressed: null, child: Text('Conferma')))))));
    final context = tester.element(find.text('Conferma'));
    expect(
        Theme.of(context).scaffoldBackgroundColor, HaykoColors.fieldBackground);
    expect(Theme.of(context).colorScheme.primary, HaykoColors.chalk);
    expect(Theme.of(context).colorScheme.secondary, const Color(0xff40c9ff));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(l.toJson(), before);
  });
}
