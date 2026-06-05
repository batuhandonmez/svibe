import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return _theme(
      brightness: Brightness.light,
      scaffold: const Color(0xFFFAFAFA),
      surface: Colors.white,
      text: const Color(0xFF111111),
      muted: const Color(0xFF737373),
      border: const Color(0xFFE5E5E5),
      accent: const Color(0xFF1DB954),
    );
  }

  static ThemeData dark() {
    return _theme(
      brightness: Brightness.dark,
      scaffold: const Color(0xFF050505),
      surface: const Color(0xFF111111),
      text: const Color(0xFFF5F5F5),
      muted: const Color(0xFFA3A3A3),
      border: const Color(0xFF242424),
      accent: const Color(0xFF1ED760),
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color text,
    required Color muted,
    required Color border,
    required Color accent,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: colorScheme.copyWith(
        primary: accent,
        surface: surface,
        outline: border,
      ),
      textTheme: Typography.material2021().black.apply(
            bodyColor: text,
            displayColor: text,
          ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: scaffold,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffold,
        selectedItemColor: text,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
