import 'package:flutter/material.dart';

const paper = Color(0xFFFAF7F1);
const ink = Color(0xFF382D29);
const muted = Color(0xFF9C8D83);
const accent = Color(0xFFC86140);
const peach = Color(0xFFECD6C4);
const line = Color(0xFFE9E1D6);
const serif = TextStyle(fontFamily: 'serif', color: ink);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: accent,
    surface: paper,
    primary: accent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  dividerColor: line,
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: ink,
    displayColor: ink,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  ),
);
String repeatLabel(String value) => switch (value) {
  'yearly' => '每年重复',
  'weekly' => '每周重复',
  _ => '不重复',
};
String numberText(int n) => n.abs().toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
Widget noteText(String text) =>
    Text(text, style: const TextStyle(color: muted, fontSize: 12, height: 1.8));
Widget eventBadge(String icon, {double size = 24}) => Container(
  width: size + 24,
  height: size + 26,
  decoration: BoxDecoration(
    color: const Color(0xFFF6EEE4),
    borderRadius: BorderRadius.circular(14),
  ),
  alignment: Alignment.center,
  child: Text(
    icon,
    style: TextStyle(fontSize: size, color: accent),
  ),
);
