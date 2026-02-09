import 'package:flutter/foundation.dart';
import 'package:sqlite_diff/sqlite_diff.dart';

enum DiffStatus { idle, loading, done, error }

enum ContentTab { schema, data }

enum TableSchemaStatus { added, removed, modified, unchanged }

class TableSidebarEntry {
  final String tableName;
  final TableSchemaStatus schemaStatus;
  final int dataChangeCount;

  const TableSidebarEntry({
    required this.tableName,
    required this.schemaStatus,
    required this.dataChangeCount,
  });

  bool get hasChanges =>
      schemaStatus != TableSchemaStatus.unchanged || dataChangeCount > 0;

  TableSidebarEntry withDataCount(int count) => TableSidebarEntry(
        tableName: tableName,
        schemaStatus: schemaStatus,
        dataChangeCount: count,
      );
}

class DiffState extends ChangeNotifier {
  String? oldFilePath;
  String? newFilePath;

  DatabaseDiff? diff;
  DiffStatus status = DiffStatus.idle;
  String? errorMessage;

  String? selectedTable;
  ContentTab activeTab = ContentTab.data;
  Set<String> expandedRowKeys = {};

  double fontSize = 12.0;
  static const double minFontSize = 10.0;
  static const double maxFontSize = 24.0;

  void increaseFontSize() {
    if (fontSize < maxFontSize) {
      fontSize = (fontSize + 1).clamp(minFontSize, maxFontSize);
      notifyListeners();
    }
  }

  void decreaseFontSize() {
    if (fontSize > minFontSize) {
      fontSize = (fontSize - 1).clamp(minFontSize, maxFontSize);
      notifyListeners();
    }
  }

  void setOldFile(String path) {
    oldFilePath = path;
    notifyListeners();
  }

  void setNewFile(String path) {
    newFilePath = path;
    notifyListeners();
  }

  bool get canCompare =>
      oldFilePath != null &&
      newFilePath != null &&
      status != DiffStatus.loading;

  Future<void> runDiff() async {
    if (oldFilePath == null || newFilePath == null) return;

    status = DiffStatus.loading;
    errorMessage = null;
    diff = null;
    selectedTable = null;
    expandedRowKeys.clear();
    notifyListeners();

    try {
      final result = await compute(
        _compareFiles,
        (oldFilePath!, newFilePath!),
      );
      diff = result;
      status = DiffStatus.done;
      _autoSelectTable();
    } catch (e) {
      status = DiffStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  static DatabaseDiff _compareFiles((String, String) paths) {
    return SqliteDiff.compareFiles(paths.$1, paths.$2);
  }

  void selectTable(String tableName) {
    selectedTable = tableName;
    expandedRowKeys.clear();
    notifyListeners();
  }

  void setActiveTab(ContentTab tab) {
    activeTab = tab;
    notifyListeners();
  }

  void toggleRowExpansion(String rowKey) {
    if (expandedRowKeys.contains(rowKey)) {
      expandedRowKeys.remove(rowKey);
    } else {
      expandedRowKeys.add(rowKey);
    }
    notifyListeners();
  }

  void _autoSelectTable() {
    if (diff == null) return;
    final tablesWithData = diff!.tablesWithDataChanges;
    if (tablesWithData.isNotEmpty) {
      selectedTable = tablesWithData.first.tableName;
      activeTab = ContentTab.data;
      return;
    }
    final schema = diff!.schemaDiff;
    if (schema.addedTables.isNotEmpty) {
      selectedTable = schema.addedTables.first.name;
      activeTab = ContentTab.schema;
    } else if (schema.removedTables.isNotEmpty) {
      selectedTable = schema.removedTables.first.name;
      activeTab = ContentTab.schema;
    } else if (schema.modifiedTables.isNotEmpty) {
      selectedTable = schema.modifiedTables.first.tableName;
      activeTab = ContentTab.schema;
    }
  }

  List<TableSidebarEntry> get sidebarEntries {
    if (diff == null) return [];

    final entries = <String, TableSidebarEntry>{};

    for (final t in diff!.schemaDiff.addedTables) {
      entries[t.name] = TableSidebarEntry(
        tableName: t.name,
        schemaStatus: TableSchemaStatus.added,
        dataChangeCount: 0,
      );
    }
    for (final t in diff!.schemaDiff.removedTables) {
      entries[t.name] = TableSidebarEntry(
        tableName: t.name,
        schemaStatus: TableSchemaStatus.removed,
        dataChangeCount: 0,
      );
    }
    for (final t in diff!.schemaDiff.modifiedTables) {
      entries[t.tableName] = TableSidebarEntry(
        tableName: t.tableName,
        schemaStatus: TableSchemaStatus.modified,
        dataChangeCount: 0,
      );
    }

    for (final d in diff!.dataDiffs) {
      final existing = entries[d.tableName];
      if (existing != null) {
        entries[d.tableName] = existing.withDataCount(d.totalChanges);
      } else if (d.totalChanges > 0) {
        entries[d.tableName] = TableSidebarEntry(
          tableName: d.tableName,
          schemaStatus: TableSchemaStatus.unchanged,
          dataChangeCount: d.totalChanges,
        );
      }
    }

    for (final name in diff!.schemaDiff.unchangedTables) {
      entries.putIfAbsent(
        name,
        () => TableSidebarEntry(
          tableName: name,
          schemaStatus: TableSchemaStatus.unchanged,
          dataChangeCount: 0,
        ),
      );
    }

    final sorted = entries.values.toList()
      ..sort((a, b) {
        final aHas = a.hasChanges ? 0 : 1;
        final bHas = b.hasChanges ? 0 : 1;
        final cmp = aHas.compareTo(bHas);
        if (cmp != 0) return cmp;
        return a.tableName.compareTo(b.tableName);
      });

    return sorted;
  }
}
