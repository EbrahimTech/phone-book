import 'package:flutter/material.dart';

class AppTheme {
  // Colors from Figma design
  static const Color primaryBlue = Color(0xFF007AFF); // Blue button color
  static const Color darkGray = Color(0xFF1C1C1E); // Dark gray text
  static const Color lightGray = Color(0xFF8E8E93); // Light gray placeholder
  static const Color emptyStateIconGray = Color(0xFFD1D1D6); // Empty state icon
  static const Color backgroundColor = Color(0xFFF6F6F6); // Light gray background (from Figma)
  static const Color borderGray = Color(0xFF2C2C2E); // Border color
  static const Color cardBackground = Color(0xFFFFFFFF); // White for cards/search bar

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: darkGray,
        titleTextStyle: TextStyle(
          color: darkGray,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: cardBackground,
        hintStyle: const TextStyle(
          color: lightGray,
          fontSize: 16,
        ),
        // Ensure input text color is #202020
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: darkGray,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: darkGray,
          fontSize: 14,
        ),
        titleLarge: TextStyle(
          color: darkGray,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }
}

