import 'package:flutter/material.dart';

class AppTheme {
  static const ember = Color(0xFFFFB000);
  static const violet = Color(0xFF7C5CFF);
  static const ink = Color(0xFF17130D);
  static const night = Color(0xFF0E0D0A);

  static ThemeData light() {
    return _theme(
      brightness: Brightness.light,
      scaffold: const Color(0xFFF7F2EA),
      surface: const Color(0xFFFFFCF4),
      raised: Colors.white,
      text: ink,
      muted: const Color(0xFF756E61),
      border: const Color(0xFFE4D9C7),
      accent: ember,
      secondary: violet,
    );
  }

  static ThemeData dark() {
    return _theme(
      brightness: Brightness.dark,
      scaffold: night,
      surface: const Color(0xFF17140F),
      raised: const Color(0xFF211D16),
      text: const Color(0xFFFFF8EA),
      muted: const Color(0xFFB5A995),
      border: const Color(0xFF343026),
      accent: ember,
      secondary: const Color(0xFF9B84FF),
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color raised,
    required Color text,
    required Color muted,
    required Color border,
    required Color accent,
    required Color secondary,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: accent,
      secondary: secondary,
      surface: surface,
      outline: border,
      onSurface: text,
      onSurfaceVariant: muted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: colorScheme,
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
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffold,
        selectedItemColor: accent,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: raised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        SvibeColors(raised: raised, muted: muted, border: border),
      ],
    );
  }
}

class SvibeColors extends ThemeExtension<SvibeColors> {
  const SvibeColors({
    required this.raised,
    required this.muted,
    required this.border,
  });

  final Color raised;
  final Color muted;
  final Color border;

  @override
  SvibeColors copyWith({Color? raised, Color? muted, Color? border}) {
    return SvibeColors(
      raised: raised ?? this.raised,
      muted: muted ?? this.muted,
      border: border ?? this.border,
    );
  }

  @override
  SvibeColors lerp(ThemeExtension<SvibeColors>? other, double t) {
    if (other is! SvibeColors) {
      return this;
    }
    return SvibeColors(
      raised: Color.lerp(raised, other.raised, t) ?? raised,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      border: Color.lerp(border, other.border, t) ?? border,
    );
  }
}
