import 'package:flutter/material.dart';

/// Premium dark palette (matte black + orange accent).
abstract final class AppColors {
  static const Color voidBlack = Color(0xFF0A0A0A);
  static const Color matte = Color(0xFF121212);
  static const Color graphite = Color(0xFF1C1C1E);
  static const Color graphiteElevated = Color(0xFF2C2C2E);
  static const Color stroke = Color(0xFF3A3A3C);
  static const Color mist = Color(0xFF8E8E93);
  static const Color fog = Color(0xFFAEAEB2);
  static const Color snow = Color(0xFFF2F2F7);
  static const Color ember = Color(0xFFFF7A00);
  static const Color emberDeep = Color(0xFFE05F00);
  static const Color ultraGold = Color(0xFFE8C547);
}

abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

abstract final class AppShadows {
  static List<BoxShadow> cardLift(Color accent) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.14),
          blurRadius: 40,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.03),
          blurRadius: 1,
          offset: const Offset(0, -1),
        ),
      ];
}

/// Material 3 dark theme for QuickScanner.
abstract final class AppTheme {
  static ThemeData dark() {
    const seed = AppColors.ember;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: AppColors.matte,
      onSurface: AppColors.snow,
      primary: AppColors.ember,
      onPrimary: Colors.white,
      secondary: AppColors.graphiteElevated,
      onSecondary: AppColors.snow,
      surfaceContainerHighest: AppColors.graphite,
      outline: AppColors.stroke,
    );

    final baseText = TextTheme(
      displaySmall: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: AppColors.snow,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.snow,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.snow,
      ),
      titleMedium: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.snow,
      ),
      bodyLarge: const TextStyle(color: AppColors.snow, height: 1.25),
      bodyMedium: const TextStyle(color: AppColors.mist, height: 1.35),
      labelLarge: const TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.mist,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.voidBlack,
      canvasColor: AppColors.voidBlack,
      textTheme: baseText,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.snow,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.snow,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.graphite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.graphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.graphiteElevated,
        contentTextStyle: const TextStyle(color: AppColors.snow),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.graphite,
        indicatorColor: AppColors.ember.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.ember : AppColors.mist,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: selected ? AppColors.snow : AppColors.mist,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ember,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.graphiteElevated,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ember,
          side: const BorderSide(color: AppColors.stroke),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return Colors.white;
          return AppColors.mist;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.ember.withValues(alpha: 0.55);
          return AppColors.graphiteElevated;
        }),
      ),
    );
  }
}
