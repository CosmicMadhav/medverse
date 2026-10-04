import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Warm, paper-like palette. Light only. No gradients, no neon.
class AppColors {
  static const primary = Color(0xFF1F5C57); // deep teal ink
  static const primaryDark = Color(0xFF143F3B);
  static const primarySoft = Color(0xFFDDEAE6);
  static const accent = Color(0xFFC8553D); // terracotta
  static const accentSoft = Color(0xFFF6E2DA);
  static const mustard = Color(0xFFD9A441);
  static const mustardSoft = Color(0xFFF7EBCF);
  static const bg = Color(0xFFF7F3EC); // cream paper
  static const card = Color(0xFFFFFDF9);
  static const text = Color(0xFF1F2624);
  static const muted = Color(0xFF6F6A61);
  static const border = Color(0xFFE6DFD3);

  static const good = Color(0xFF3D7A4E);
  static const goodSoft = Color(0xFFE2EFE3);
  static const warn = Color(0xFFB7791F);
  static const warnSoft = Color(0xFFF7EBCF);
  static const bad = Color(0xFFB23A2B);
  static const badSoft = Color(0xFFF6DFDA);
  static const info = Color(0xFF2F5D8A);
  static const infoSoft = Color(0xFFDFE8F1);

  static const agree = good;
  static const differ = accent;
  static const onlyA = info;
  static const onlyB = Color(0xFF7A5C99);
}

TextStyle serif(double size, {FontWeight w = FontWeight.w600, Color? c}) =>
    GoogleFonts.fraunces(
        fontSize: size, fontWeight: w, color: c ?? AppColors.text, height: 1.2);

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final body = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text, displayColor: AppColors.text);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.bg,
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: body,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serif(21),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primarySoft,
      labelStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppColors.border),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.primarySoft,
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
  );
}
