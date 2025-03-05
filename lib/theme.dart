import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  primaryColor: const Color(0xFFD06100),
  scaffoldBackgroundColor: const Color(0xFFF2E9E9),
  colorScheme: ColorScheme.light(
    primary: const Color(0xFFD06100),
    secondary: const Color(0xFFD06100),
    brightness: Brightness.light,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFD06100),
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFFD06100),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
  ),
  // Define additional light theme properties here
);

final ThemeData darkTheme = ThemeData(
  primaryColor: const Color(0xFFD06100),
  scaffoldBackgroundColor: const Color(0xFF383633),
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFFD06100),
    secondary: const Color(0xFFD06100),
    brightness: Brightness.dark,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFD06100),
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFFD06100),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
  ),
  // Define additional dark theme properties here
);