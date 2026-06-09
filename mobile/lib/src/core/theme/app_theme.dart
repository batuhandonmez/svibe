import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF121217);
  static const night = Color(0xFF0B0B10);
  static const berry = Color(0xFFFF4E88);
  static const blue = Color(0xFF3F7CFF);
  static const lime = Color(0xFFD9F85F);
  static const lilac = Color(0xFF9A7CFF);
  static const orange = Color(0xFFFFB84A);

  static ThemeData light() {
    return _theme(
      brightness: Brightness.light,
      scaffold: const Color(0xFFF7F1E6),
      surface: const Color(0xFFFFF9EF),
      elevated: Colors.white,
      text: ink,
      muted: const Color(0xFF786F66),
      border: const Color(0xFFE6DAC8),
    );
  }

  static ThemeData dark() {
    return _theme(
      brightness: Brightness.dark,
      scaffold: night,
      surface: const Color(0xFF171720),
      elevated: const Color(0xFF20202B),
      text: const Color(0xFFFFF9EF),
      muted: const Color(0xFFAAA2BA),
      border: const Color(0xFF2A2A36),
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color elevated,
    required Color text,
    required Color muted,
    required Color border,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: berry,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: berry,
          secondary: blue,
          tertiary: lime,
          surface: surface,
          outline: border,
          onSurface: text,
          onSurfaceVariant: muted,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: scheme,
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
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: text,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: berry, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: berry,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        SvibeColors(
          elevated: elevated,
          muted: muted,
          border: border,
          berry: berry,
          blue: blue,
          lime: lime,
          lilac: lilac,
          orange: orange,
        ),
      ],
    );
  }
}

class SvibeColors extends ThemeExtension<SvibeColors> {
  const SvibeColors({
    required this.elevated,
    required this.muted,
    required this.border,
    required this.berry,
    required this.blue,
    required this.lime,
    required this.lilac,
    required this.orange,
  });

  final Color elevated;
  final Color muted;
  final Color border;
  final Color berry;
  final Color blue;
  final Color lime;
  final Color lilac;
  final Color orange;

  @override
  SvibeColors copyWith({
    Color? elevated,
    Color? muted,
    Color? border,
    Color? berry,
    Color? blue,
    Color? lime,
    Color? lilac,
    Color? orange,
  }) {
    return SvibeColors(
      elevated: elevated ?? this.elevated,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      berry: berry ?? this.berry,
      blue: blue ?? this.blue,
      lime: lime ?? this.lime,
      lilac: lilac ?? this.lilac,
      orange: orange ?? this.orange,
    );
  }

  @override
  SvibeColors lerp(ThemeExtension<SvibeColors>? other, double t) {
    if (other is! SvibeColors) {
      return this;
    }
    return SvibeColors(
      elevated: Color.lerp(elevated, other.elevated, t) ?? elevated,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      border: Color.lerp(border, other.border, t) ?? border,
      berry: Color.lerp(berry, other.berry, t) ?? berry,
      blue: Color.lerp(blue, other.blue, t) ?? blue,
      lime: Color.lerp(lime, other.lime, t) ?? lime,
      lilac: Color.lerp(lilac, other.lilac, t) ?? lilac,
      orange: Color.lerp(orange, other.orange, t) ?? orange,
    );
  }
}
