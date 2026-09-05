import 'package:flutter/material.dart';

/// Invoiz brand palette — single source of truth for the Rider app.
///
/// Mirrors the Invoiz web / buyer-seller ecosystem so the mobile app reads
/// as "Invoiz on mobile", not a separate courier identity. Prefer
/// `AppColors.primary` over raw `Color(0xFF…)` literals in every screen.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF16697A);
  static const Color primaryDark = Color(0xFF0E4A57);
  static const Color secondary = Color(0xFFF0A202);
  static const Color accent = Color(0xFFEAF4F3);
  static const Color background = Color(0xFFF7F6F2);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B1B1E);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFE05A33);
  static const Color gold = Color(0xFFF5A623);
  static const Color border = Color(0xFFE8E6E0);
  static const Color surfaceSoft = Color(0xFFF0EEE9);
}

/// Invoize Rider application theme.
///
/// Uses the platform default font (Segoe UI on Windows/web, Roboto on
/// Android) — the closest Flutter equivalent to the Invoiz `system-ui`
/// stack — with no extra font dependencies.
class AppTheme {
  AppTheme._();

  static const Color primary = AppColors.primary;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color secondary = AppColors.secondary;
  static const Color accent = AppColors.accent;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;

  /// Errors use the brand warning tone (no arbitrary reds).
  static const Color danger = AppColors.warning;

  static const Color background = AppColors.background;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color border = AppColors.border;
  static const Color surfaceSoft = AppColors.surfaceSoft;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: AppColors.card,
        error: warning,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: warning),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: warning, width: 1.6),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: border)),
        side: BorderSide(color: border),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
      ),
    );
  }
}
