import 'package:meta/meta.dart';

/// Represents metadata about a single column in a SQLite table.
@immutable
final class ColumnInfo {
  /// Column name.
  final String name;

  /// The declared type (e.g., "TEXT", "INTEGER", "REAL", "BLOB").
  final String type;

  /// Whether the column allows NULL values.
  final bool nullable;

  /// The default value expression as a string, or null if no default.
  final String? defaultValue;

  /// Whether this column is part of the primary key.
  final bool isPrimaryKey;

  /// The position of this column in the primary key (0-based), or -1 if not
  /// part of the primary key.
  final int primaryKeyIndex;

  const ColumnInfo({
    required this.name,
    required this.type,
    required this.nullable,
    required this.defaultValue,
    required this.isPrimaryKey,
    this.primaryKeyIndex = -1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnInfo &&
          name == other.name &&
          type == other.type &&
          nullable == other.nullable &&
          defaultValue == other.defaultValue &&
          isPrimaryKey == other.isPrimaryKey;

  @override
  int get hashCode =>
      Object.hash(name, type, nullable, defaultValue, isPrimaryKey);

  @override
  String toString() =>
      'ColumnInfo($name $type${nullable ? '' : ' NOT NULL'}'
      '${defaultValue != null ? ' DEFAULT $defaultValue' : ''}'
      '${isPrimaryKey ? ' PK' : ''})';
}
