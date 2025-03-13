import 'package:flutter/material.dart';

class ShadowTheme extends ThemeExtension<ShadowTheme> {
  final Color shadowColor;

  ShadowTheme({required this.shadowColor});

  @override
  ShadowTheme copyWith({Color? shadowColor}) {
    return ShadowTheme(
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  ShadowTheme lerp(ShadowTheme? other, double t) {
    if (other is! ShadowTheme) return this;
    return ShadowTheme(
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}







final ThemeData lightTheme = ThemeData(
  primaryColor: const Color(0xFFD06100),
  scaffoldBackgroundColor: const Color(0xFFF2E9E9),
  colorScheme: ColorScheme.light(
    primary: const Color(0xFFD06100),
    secondary: const Color(0xFFD06100),
    brightness: Brightness.light,
  ),

  extensions: <ThemeExtension<dynamic>>[
    ShadowTheme(shadowColor: Colors.black26), 
  ],


  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFD06100),
  ),


 cardTheme: CardTheme(
    color: const Color(0xFFF2E9E9),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: const Color(0xFFD06100)),
    ),
  ),

  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFFD06100),
  ),


  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15.0)),
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15.0)),
      borderSide: BorderSide(color: const Color(0xFFD06100)),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15.0)),
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

  extensions: <ThemeExtension<dynamic>>[
    ShadowTheme(shadowColor: const Color(0xFFD06100)), // Turuncu gölge
  ],

  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFD06100),
  ),



  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFFD06100),
  ),


  cardTheme: CardTheme(
    color: const Color.fromARGB(255, 60, 58, 56),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: const Color(0xFFD06100)),
    ),
  ),



  textTheme: TextTheme(
    bodyLarge: TextStyle(color:const Color(0xFFF2E9E9)),
    bodyMedium: TextStyle(color:const Color(0xFFF2E9E9)),
    bodySmall: TextStyle(color: const Color(0xFFF2E9E9)),
    titleLarge: TextStyle(color:const Color(0xFFF2E9E9)),
    titleMedium: TextStyle(color: const Color(0xFFF2E9E9)),
    titleSmall: TextStyle(color: const Color(0xFFF2E9E9)),
  ),



  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15.0)),
      borderSide: BorderSide(color: const Color(0xFFD06100),width: 2.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15.0)),
      borderSide: BorderSide(color: const Color(0xFFD06100),width: 2.0),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15.0)),
      borderSide: BorderSide(color: const Color(0xFFD06100),width: 2.0),
    ),
  ),
);