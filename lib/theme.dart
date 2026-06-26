import 'package:flutter/material.dart';

/// Rhombus theme tokens — mirrors the web app's `globals.css` for both the
/// light (default) and dark variants.
class RhombusTheme {
  static const accent = Color(0xFFf37021);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: const Color(0xFFF7F8FA),
        surface: const Color(0xFFFFFFFF),
        surfaceVariant: const Color(0xFFF4F6F9),
        textPrimary: const Color(0xFF1C1C28),
        textSecondary: const Color(0xFF5A6072),
        border: const Color(0xFFEEF0F4),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: const Color(0xFF0F1117),
        surface: const Color(0xFF1A1D27),
        surfaceVariant: const Color(0xFF20242F),
        textPrimary: const Color(0xFFF3F4F8),
        textSecondary: const Color(0xFFAEB4C4),
        border: const Color(0xFF272B38),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceVariant,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      surface: surface,
      surfaceContainerHighest: surfaceVariant,
      error: const Color(0xFFE5544B),
      onSurface: textPrimary,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: surface),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        dividerColor: border,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      listTileTheme: ListTileThemeData(iconColor: textSecondary),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
