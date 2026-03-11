import 'package:flutter/material.dart';
import 'colors.dart';

/// VoidMail Dark Theme
class VoidTheme {
  VoidTheme._();

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: VoidColors.bgDeep,
        primaryColor: VoidColors.accentPink,
        colorScheme: const ColorScheme.dark(
          primary: VoidColors.accentPink,
          secondary: VoidColors.accentGreen,
          tertiary: VoidColors.accentSkyBlue,
          surface: VoidColors.bgSurface,
          error: VoidColors.error,
          onPrimary: VoidColors.textInverse,
          onSecondary: VoidColors.textInverse,
          onSurface: VoidColors.textPrimary,
          onError: VoidColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: VoidColors.bgDeep,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: VoidColors.textPrimary),
          titleTextStyle: TextStyle(
            color: VoidColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: VoidColors.bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: VoidColors.border,
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: VoidColors.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(
            color: VoidColors.textTertiary,
            fontSize: 15,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return VoidColors.textTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VoidColors.accentGreen;
            }
            return VoidColors.bgCard;
          }),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            return Colors.transparent;
          }),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: VoidColors.textPrimary),
          displayMedium: TextStyle(color: VoidColors.textPrimary),
          displaySmall: TextStyle(color: VoidColors.textPrimary),
          headlineLarge: TextStyle(color: VoidColors.textPrimary),
          headlineMedium: TextStyle(color: VoidColors.textPrimary),
          headlineSmall: TextStyle(color: VoidColors.textPrimary),
          titleLarge: TextStyle(color: VoidColors.textPrimary),
          titleMedium: TextStyle(color: VoidColors.textPrimary),
          titleSmall: TextStyle(color: VoidColors.textPrimary),
          bodyLarge: TextStyle(color: VoidColors.textPrimary),
          bodyMedium: TextStyle(color: VoidColors.textPrimary),
          bodySmall: TextStyle(color: VoidColors.textSecondary),
          labelLarge: TextStyle(color: VoidColors.textPrimary),
          labelMedium: TextStyle(color: VoidColors.textSecondary),
          labelSmall: TextStyle(color: VoidColors.textTertiary),
        ),
      );
}
