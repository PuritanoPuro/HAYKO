import 'package:flutter/material.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

/// Fondazioni HAYKO: palette Campo e Bricolage Grotesque in locale.
/// Le geometrie delle schermate successive restano quelle esistenti.
ThemeData buildHaykoTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final scheme = base.colorScheme.copyWith(
    primary: HaykoColors.chalk,
    onPrimary: HaykoColors.fieldBackground,
    primaryContainer: HaykoColors.fieldLine,
    onPrimaryContainer: HaykoColors.chalk,
    secondary: HaykoColors.chalk,
    onSecondary: HaykoColors.fieldBackground,
    secondaryContainer: HaykoColors.fieldLine,
    onSecondaryContainer: HaykoColors.chalk,
    surface: HaykoColors.fieldSurface,
    onSurface: HaykoColors.chalk,
    onSurfaceVariant: HaykoColors.mutedText,
    surfaceDim: HaykoColors.fieldBackground,
    surfaceBright: HaykoColors.fieldSurface,
    surfaceContainerLowest: HaykoColors.fieldBackground,
    surfaceContainerLow: HaykoColors.fieldSurface,
    surfaceContainer: HaykoColors.fieldSurface,
    surfaceContainerHigh: HaykoColors.fieldSurface,
    surfaceContainerHighest: HaykoColors.fieldSurface,
    outline: HaykoColors.fieldLine,
    outlineVariant: HaykoColors.fieldLine,
    inverseSurface: HaykoColors.chalk,
    onInverseSurface: HaykoColors.fieldBackground,
    inversePrimary: HaykoColors.fieldBackground,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: HaykoColors.fieldBackground,
    primaryTextTheme:
        base.primaryTextTheme.apply(fontFamily: 'BricolageGrotesque'),
    textTheme: base.textTheme.apply(
        fontFamily: 'BricolageGrotesque',
        bodyColor: HaykoColors.chalk,
        displayColor: HaykoColors.chalk),
    appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: HaykoColors.fieldBackground,
        foregroundColor: HaykoColors.chalk,
        surfaceTintColor: Colors.transparent),
    cardTheme: base.cardTheme.copyWith(
        color: HaykoColors.fieldSurface, surfaceTintColor: Colors.transparent),
    dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: HaykoColors.fieldSurface,
        surfaceTintColor: Colors.transparent),
    navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: HaykoColors.fieldSurface,
        indicatorColor: HaykoColors.fieldLine),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: HaykoColors.chalk,
        foregroundColor: HaykoColors.fieldBackground),
    dividerColor: HaykoColors.fieldLine,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: const TextStyle(color: HaykoColors.mutedText),
        hintStyle: const TextStyle(color: HaykoColors.mutedText),
        helperStyle: const TextStyle(color: HaykoColors.mutedText)),
  );
}
