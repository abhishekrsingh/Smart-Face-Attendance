import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String _font = 'Poppins';

  static ThemeData get light => _build(
    // ← CHANGED: was inline, now calls _build()
    brightness: Brightness.light,
    scheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    cardColor: AppColors.cardLight,
    inputFill: Colors.white,
    dividerColor: AppColors.divider,
    textBase: AppColors.textPrimary,
    textHint: AppColors.textSecondary,
    statusIconBright: Brightness.dark,
    navBg: AppColors.cardLight,
    bottomSheetBg: AppColors.surface,
  );

  static ThemeData get dark => _build(
    // ← CHANGED: was inline, now calls _build()
    brightness: Brightness.dark,
    scheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
    ),
    cardColor: AppColors.cardDark,
    inputFill: AppColors.cardDark,
    dividerColor: AppColors.dividerDark,
    textBase: AppColors.textPrimaryDark,
    textHint: AppColors.textSecondaryDark,
    statusIconBright: Brightness.light,
    navBg: AppColors.cardDark,
    bottomSheetBg: AppColors.surfaceDark,
  );

  // ← NEW: single builder shared by both themes —
  //   prevents light/dark from drifting out of sync
  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color cardColor,
    required Color inputFill,
    required Color dividerColor,
    required Color textBase,
    required Color textHint,
    required Brightness statusIconBright,
    required Color navBg,
    required Color bottomSheetBg,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _font,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.surfaceDark
          : AppColors.surface,

      // ── AppBar ────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              statusIconBright, // ← CHANGED: dynamic — dark icons on light, light on dark
          systemNavigationBarColor: Colors.transparent,
        ),
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textBase,
        ),
        iconTheme: IconThemeData(
          color: textBase,
        ), // ← NEW: AppBar icons match text color in both modes
      ),

      // ── Card ──────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dividerColor),
        ),
      ),

      // ── ElevatedButton ────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // ← NEW: OutlinedButton theme — without this, dark mode
      //   shows near-invisible grey border on dark background
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ← NEW: TextButton theme — consistent font + color
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            // ← CHANGED: primaryLight in dark mode — full
            //   primary is too bright on dark background
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: textHint, fontSize: 14),
        labelStyle: TextStyle(color: textHint), // ← NEW: label color explicit
      ),

      // ← NEW: NavigationBar theme — Material 3 NavigationBar
      //   has its own background token, without this it picks
      //   surfaceContainer which is wrong shade in dark mode
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textHint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textHint,
          ),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      // ← NEW: BottomSheet theme — edit attendance dialog uses
      //   showModalBottomSheet — without explicit bg it picks
      //   surfaceContainer which looks wrong in dark mode
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bottomSheetBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        elevation: 0,
      ),

      // ← NEW: Dialog theme — AlertDialog bg + typography explicit
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textBase,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          height: 1.5,
          color: textHint,
        ),
      ),

      // ← NEW: SnackBar theme — floating style + dark slate bg
      //   in both modes — default dark SnackBar is washed grey
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // ← NEW: Checkbox theme — matches brand indigo
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: dividerColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ← NEW: ListTile theme — consistent font across all tiles
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textBase,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 13,
          color: textHint,
        ),
      ),

      // ── Divider ───────────────────────────────────────
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),

      // ── Text ──────────────────────────────────────────
      textTheme: _textTheme(textBase, textHint),
    );
  }

  // ← CHANGED: added textHint param + headlineLarge,
  //   headlineSmall, titleSmall, bodySmall, labelSmall
  //   — these were missing and caused fallback fonts
  static TextTheme _textTheme(Color base, Color hint) => TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: base,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: base,
    ),
    headlineLarge: TextStyle(
      // ← NEW
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: base,
    ),
    headlineSmall: TextStyle(
      // ← NEW
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: base,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: base,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: base,
    ),
    titleSmall: TextStyle(
      // ← NEW
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: hint,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: base,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: base,
    ),
    bodySmall: TextStyle(
      // ← NEW
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: hint,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: base,
    ),
    labelSmall: TextStyle(
      // ← NEW
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: hint,
    ),
  );
}
