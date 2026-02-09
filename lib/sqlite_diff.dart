/// A library for comparing two SQLite databases and producing structured
/// diff results with human-readable text output.
library;

export 'src/sqlite_diff.dart';
export 'src/models/column_info.dart';
export 'src/models/table_schema.dart';
export 'src/models/schema_diff.dart';
export 'src/models/row_diff.dart';
export 'src/models/table_data_diff.dart';
export 'src/models/database_diff.dart';
export 'src/models/diff_options.dart';
export 'src/formatter/text_formatter.dart' show DiffTextFormatter;
