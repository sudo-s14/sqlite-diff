import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:sqlite3/open.dart';

import 'models/diff_state.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  _initSqlCipher();
  runApp(const SqliteDiffApp());
}

void _initSqlCipher() {
  open.overrideFor(OperatingSystem.macOS, () {
    return DynamicLibrary.open('libsqlcipher_native.dylib');
  });
}

class SqliteDiffApp extends StatefulWidget {
  const SqliteDiffApp({super.key});

  @override
  State<SqliteDiffApp> createState() => _SqliteDiffAppState();
}

class _SqliteDiffAppState extends State<SqliteDiffApp> {
  final _diffState = DiffState();

  @override
  void dispose() {
    _diffState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQLite Diff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: _diffState,
        builder: (context, _) {
          final scale = _diffState.fontSize / 12.0;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: HomeScreen(state: _diffState),
          );
        },
      ),
    );
  }
}
