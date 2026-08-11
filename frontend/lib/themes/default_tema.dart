import 'package:flutter/material.dart';

/// Glavna brand boja aplikacije.
/// Koristi se kao baza za LIGHT i DARK temu.
const Color bojaNaglaska = Color(0xFF22C55E);

/// Dodatne boje dizajn sistema.
const Color pozadinaSvijetla = Color(0xFFF7F9F7);
const Color povrsinaSvijetla = Color(0xFFFFFFFF);
const Color sekundarnaPovrsinaSvijetla = Color(0xFFF0F3F1);

const Color pozadinaTamna = Color(0xFF0B0F0C);
const Color povrsinaTamna = Color(0xFF131814);
const Color sekundarnaPovrsinaTamna = Color(0xFF1A211C);

ThemeData izradiTemu(Brightness svjetlina) {
  final jeTamna = svjetlina == Brightness.dark;

  final osnovnaShema = ColorScheme.fromSeed(
    seedColor: bojaNaglaska,
    brightness: svjetlina,
  );

  final shema = osnovnaShema.copyWith(
    primary: bojaNaglaska,
    secondary: jeTamna
        ? const Color(0xFF86EFAC)
        : const Color(0xFF15803D),
    surface: jeTamna ? pozadinaTamna : pozadinaSvijetla,
    surfaceContainerLowest:
        jeTamna ? povrsinaTamna : povrsinaSvijetla,
    surfaceContainerLow:
        jeTamna ? const Color(0xFF101511) : const Color(0xFFFAFBFA),
    surfaceContainer:
        jeTamna ? const Color(0xFF151B16) : const Color(0xFFF5F7F5),
    surfaceContainerHigh:
        jeTamna ? sekundarnaPovrsinaTamna : sekundarnaPovrsinaSvijetla,
    surfaceContainerHighest:
        jeTamna ? const Color(0xFF202821) : const Color(0xFFE8EDE9),
    onSurface:
        jeTamna ? const Color(0xFFF7FAF7) : const Color(0xFF151A16),
    onSurfaceVariant:
        jeTamna ? const Color(0xFFAAB4AC) : const Color(0xFF687169),
    outline:
        jeTamna ? const Color(0xFF4B564D) : const Color(0xFFBBC4BC),
    outlineVariant:
        jeTamna ? const Color(0xFF2A332B) : const Color(0xFFDCE3DD),
    error: jeTamna ? const Color(0xFFFF6B6B) : const Color(0xFFDC2626),
  );

  final osnovniTekst = ThemeData(
    brightness: svjetlina,
    useMaterial3: true,
  ).textTheme.apply(
        bodyColor: shema.onSurface,
        displayColor: shema.onSurface,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: svjetlina,
    colorScheme: shema,
    scaffoldBackgroundColor: shema.surface,

    textTheme: osnovniTekst.copyWith(
      headlineLarge: osnovniTekst.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineMedium: osnovniTekst.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: osnovniTekst.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: osnovniTekst.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: osnovniTekst.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: osnovniTekst.bodyLarge?.copyWith(
        height: 1.35,
      ),
      bodyMedium: osnovniTekst.bodyMedium?.copyWith(
        height: 1.35,
      ),
      labelLarge: osnovniTekst.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: shema.surface,
      foregroundColor: shema.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: osnovniTekst.titleLarge?.copyWith(
        color: shema.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),

    cardTheme: CardThemeData(
      color: shema.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: shema.outlineVariant.withValues(
            alpha: jeTamna ? 0.28 : 0.55,
          ),
        ),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: shema.outlineVariant.withValues(alpha: 0.55),
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: shema.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      hintStyle: TextStyle(
        color: shema.onSurfaceVariant,
      ),
      labelStyle: TextStyle(
        color: shema.onSurfaceVariant,
      ),
      prefixIconColor: shema.onSurfaceVariant,
      suffixIconColor: shema.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: shema.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: shema.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: shema.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: shema.error,
          width: 1.5,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: shema.primary,
        foregroundColor: const Color(0xFF07140B),
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: shema.onSurface,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        side: BorderSide(
          color: shema.outlineVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: shema.primary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: shema.primary,
      foregroundColor: const Color(0xFF07140B),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: jeTamna
          ? povrsinaTamna
          : povrsinaSvijetla,
      indicatorColor: shema.primary.withValues(alpha: jeTamna ? 0.18 : 0.14),
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? shema.primary
              : shema.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? shema.primary
              : shema.onSurfaceVariant,
          size: 23,
        ),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: shema.primary,
      linearTrackColor: shema.outlineVariant.withValues(alpha: 0.45),
      circularTrackColor: shema.outlineVariant.withValues(alpha: 0.45),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: jeTamna
          ? const Color(0xFF222A23)
          : const Color(0xFF1D271F),
      contentTextStyle: const TextStyle(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: shema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: shema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
    ),
  );
}

/// Sadržaj input polja.
/// Vizualni izgled polja definiran je globalno u temi.
InputDecoration izgledPolja({
  required String oznaka,
  required String natuknica,
  required IconData ikona,
  Widget? sufiks,
}) {
  return InputDecoration(
    labelText: oznaka,
    hintText: natuknica,
    prefixIcon: Icon(ikona),
    suffixIcon: sufiks,
  );
}
