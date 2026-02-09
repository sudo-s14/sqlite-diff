import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Light mode colors
  static const _inserted = Color(0xFF2E7D32);
  static const _deleted = Color(0xFFC62828);
  static const _modified = Color(0xFFF57F17);
  static const _insertedBg = Color(0xFFE8F5E9);
  static const _deletedBg = Color(0xFFFFEBEE);
  static const _modifiedBg = Color(0xFFFFF8E1);

  // Dark mode colors
  static const _insertedDark = Color(0xFF66BB6A);
  static const _deletedDark = Color(0xFFEF5350);
  static const _modifiedDark = Color(0xFFFFCA28);
  static const _insertedBgDark = Color(0xFF1B3A1B);
  static const _deletedBgDark = Color(0xFF3A1B1B);
  static const _modifiedBgDark = Color(0xFF3A3518);

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      );

  static Color insertedColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _insertedDark
          : _inserted;

  static Color deletedColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _deletedDark
          : _deleted;

  static Color modifiedColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _modifiedDark
          : _modified;

  static Color insertedBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _insertedBgDark
          : _insertedBg;

  static Color deletedBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _deletedBgDark
          : _deletedBg;

  static Color modifiedBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _modifiedBgDark
          : _modifiedBg;
}
