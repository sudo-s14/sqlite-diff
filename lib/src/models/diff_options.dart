/// Options that control the diff operation.
final class DiffOptions {
  /// If non-null, only these tables will be compared.
  final Set<String>? tables;

  /// Per-table column filters. Key is table name.
  /// Only affects data comparison, not schema comparison.
  final Map<String, Set<String>>? columnFilters;

  /// Per-table custom key columns. Key is table name.
  /// If not specified for a table, the primary key is used.
  final Map<String, List<String>>? customKeyColumns;

  /// Whether to include schema differences in the result.
  final bool includeSchema;

  /// Whether to include data differences in the result.
  final bool includeData;

  /// Whether to report all rows in tables that exist in only one database
  /// as inserted/deleted.
  final bool includeDataForExclusiveTables;

  /// A label for the old database (used in formatted output).
  final String? oldLabel;

  /// A label for the new database (used in formatted output).
  final String? newLabel;

  const DiffOptions({
    this.tables,
    this.columnFilters,
    this.customKeyColumns,
    this.includeSchema = true,
    this.includeData = true,
    this.includeDataForExclusiveTables = false,
    this.oldLabel,
    this.newLabel,
  });

  static const DiffOptions defaults = DiffOptions();

  /// Creates a copy with updated labels.
  DiffOptions withLabels({String? oldLabel, String? newLabel}) => DiffOptions(
        tables: tables,
        columnFilters: columnFilters,
        customKeyColumns: customKeyColumns,
        includeSchema: includeSchema,
        includeData: includeData,
        includeDataForExclusiveTables: includeDataForExclusiveTables,
        oldLabel: oldLabel ?? this.oldLabel,
        newLabel: newLabel ?? this.newLabel,
      );
}
