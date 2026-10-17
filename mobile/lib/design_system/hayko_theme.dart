import 'package:flutter/material.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';

/// Fondazioni HAYKO: palette Campo e Bricolage Grotesque in locale.
/// Le geometrie delle schermate successive restano quelle esistenti.
ThemeData buildHaykoTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const radius = BorderRadius.all(Radius.circular(12));
  const buttonText = TextStyle(
      fontFamily: 'BricolageGrotesque',
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w700);
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
    error: HaykoColors.danger,
    onError: HaykoColors.fieldBackground,
  );
  final textTheme = base.textTheme
      .apply(
          fontFamily: 'BricolageGrotesque',
          bodyColor: HaykoColors.chalk,
          displayColor: HaykoColors.chalk)
      .copyWith(
        headlineLarge: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 32,
            height: 1.125,
            fontWeight: FontWeight.w800,
            color: HaykoColors.chalk),
        headlineMedium: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: HaykoColors.chalk),
        titleLarge: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: HaykoColors.chalk),
        titleMedium: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: HaykoColors.chalk),
        bodyLarge: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: HaykoColors.chalk),
        bodyMedium: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w400,
            color: HaykoColors.chalk),
        labelLarge: buttonText,
        labelMedium: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
            color: HaykoColors.mutedText),
      );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: HaykoColors.fieldBackground,
    primaryTextTheme: textTheme,
    textTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: HaykoColors.fieldBackground,
        foregroundColor: HaykoColors.chalk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: HaykoColors.chalk, size: 24)),
    cardTheme: base.cardTheme.copyWith(
        color: HaykoColors.fieldSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: radius)),
    dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: HaykoColors.fieldSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge),
    navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: HaykoColors.fieldSurface,
        indicatorColor: HaykoColors.fieldLine,
        height: 76,
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600))),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: HaykoColors.chalk,
        foregroundColor: HaykoColors.fieldBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: radius)),
    dividerColor: HaykoColors.fieldLine,
    dividerTheme: const DividerThemeData(
        color: HaykoColors.fieldLine, thickness: 1, space: 24),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.all(12),
            backgroundColor: HaykoColors.chalk,
            foregroundColor: HaykoColors.fieldBackground,
            disabledBackgroundColor: HaykoColors.chalk.withValues(alpha: .4),
            disabledForegroundColor:
                HaykoColors.fieldBackground.withValues(alpha: .6),
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: radius),
            textStyle: buttonText)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.all(12),
            foregroundColor: HaykoColors.chalk,
            side: const BorderSide(color: HaykoColors.fieldLine),
            shape: const RoundedRectangleBorder(borderRadius: radius),
            textStyle: buttonText)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: HaykoColors.chalk,
            shape: const RoundedRectangleBorder(borderRadius: radius),
            textStyle: buttonText)),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: HaykoColors.fieldSurface,
        contentPadding: const EdgeInsets.all(12),
        labelStyle: const TextStyle(color: HaykoColors.mutedText),
        hintStyle: const TextStyle(color: HaykoColors.mutedText),
        helperStyle: const TextStyle(color: HaykoColors.mutedText),
        border: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: HaykoColors.fieldLine)),
        enabledBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: HaykoColors.fieldLine)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: HaykoColors.chalk, width: 2))),
    listTileTheme: const ListTileThemeData(
        tileColor: HaykoColors.fieldSurface,
        textColor: HaykoColors.chalk,
        iconColor: HaykoColors.chalk,
        minTileHeight: 72,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: radius)),
    segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            foregroundColor: const WidgetStatePropertyAll(HaykoColors.chalk),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? HaykoColors.fieldLine
                    : HaykoColors.fieldBackground),
            side: const WidgetStatePropertyAll(
                BorderSide(color: HaykoColors.fieldLine)),
            shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: radius)))),
    chipTheme: base.chipTheme.copyWith(
        backgroundColor: HaykoColors.fieldBackground,
        selectedColor: HaykoColors.fieldLine,
        side: const BorderSide(color: HaykoColors.fieldLine),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        labelStyle: textTheme.labelMedium?.copyWith(color: HaykoColors.chalk),
        padding: const EdgeInsets.all(8)),
    switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? HaykoColors.fieldBackground
                : HaykoColors.mutedText),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? HaykoColors.chalk
                : HaykoColors.fieldLine)),
    checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? HaykoColors.chalk
                : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(HaykoColors.fieldBackground),
        side: const BorderSide(color: HaykoColors.mutedText, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
    snackBarTheme: const SnackBarThemeData(
        backgroundColor: HaykoColors.chalk,
        contentTextStyle: TextStyle(
            fontFamily: 'BricolageGrotesque',
            color: HaykoColors.fieldBackground,
            fontSize: 14),
        behavior: SnackBarBehavior.floating),
  );
}
