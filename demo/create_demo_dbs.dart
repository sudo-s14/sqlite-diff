import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dir = File(Platform.script.toFilePath()).parent.path;

  // --- Old Database ---
  final oldPath = '$dir/old.db';
  final oldFile = File(oldPath);
  if (oldFile.existsSync()) oldFile.deleteSync();
  final oldDb = sqlite3.open(oldPath);

  oldDb.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT,
      age INTEGER,
      role TEXT DEFAULT 'user'
    )
  ''');
  oldDb.execute("INSERT INTO users VALUES (1, 'Alice Johnson', 'alice@example.com', 30, 'admin')");
  oldDb.execute("INSERT INTO users VALUES (2, 'Bob Smith', 'bob@example.com', 25, 'user')");
  oldDb.execute("INSERT INTO users VALUES (3, 'Charlie Brown', 'charlie@example.com', 35, 'user')");
  oldDb.execute("INSERT INTO users VALUES (4, 'Diana Prince', 'diana@example.com', 28, 'moderator')");
  oldDb.execute("INSERT INTO users VALUES (5, 'Eve Wilson', 'eve@example.com', 22, 'user')");

  oldDb.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      category TEXT,
      in_stock INTEGER DEFAULT 1
    )
  ''');
  oldDb.execute("INSERT INTO products VALUES (1, 'Widget', 9.99, 'gadgets', 1)");
  oldDb.execute("INSERT INTO products VALUES (2, 'Gizmo', 24.99, 'gadgets', 1)");
  oldDb.execute("INSERT INTO products VALUES (3, 'Doohickey', 4.50, 'tools', 1)");
  oldDb.execute("INSERT INTO products VALUES (4, 'Thingamajig', 15.00, 'tools', 0)");
  oldDb.execute("INSERT INTO products VALUES (5, 'Whatchamacallit', 7.25, 'misc', 1)");

  oldDb.execute('''
    CREATE TABLE orders (
      id INTEGER PRIMARY KEY,
      user_id INTEGER,
      product_id INTEGER,
      quantity INTEGER,
      total REAL,
      status TEXT DEFAULT 'pending',
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');
  oldDb.execute("INSERT INTO orders VALUES (1, 1, 2, 1, 24.99, 'completed')");
  oldDb.execute("INSERT INTO orders VALUES (2, 2, 1, 3, 29.97, 'completed')");
  oldDb.execute("INSERT INTO orders VALUES (3, 3, 3, 2, 9.00, 'pending')");
  oldDb.execute("INSERT INTO orders VALUES (4, 1, 5, 1, 7.25, 'shipped')");
  oldDb.execute("INSERT INTO orders VALUES (5, 4, 4, 1, 15.00, 'pending')");

  oldDb.execute('''
    CREATE TABLE audit_log (
      id INTEGER PRIMARY KEY,
      action TEXT,
      timestamp TEXT
    )
  ''');
  oldDb.execute("INSERT INTO audit_log VALUES (1, 'user_created', '2024-01-01')");
  oldDb.execute("INSERT INTO audit_log VALUES (2, 'order_placed', '2024-01-02')");

  oldDb.dispose();
  print('Created: $oldPath');

  // --- New Database ---
  final newPath = '$dir/new.db';
  final newFile = File(newPath);
  if (newFile.existsSync()) newFile.deleteSync();
  final newDb = sqlite3.open(newPath);

  // Users table: added 'avatar_url' column, removed 'age' column
  newDb.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      avatar_url TEXT
    )
  ''');
  // Alice: email changed
  newDb.execute("INSERT INTO users VALUES (1, 'Alice Johnson', 'alice@newcorp.com', 'admin', 'https://img.example.com/alice.png')");
  // Bob: name and role changed
  newDb.execute("INSERT INTO users VALUES (2, 'Robert Smith', 'bob@example.com', 'moderator', NULL)");
  // Charlie: deleted (not present)
  // Diana: unchanged (except age column gone)
  newDb.execute("INSERT INTO users VALUES (4, 'Diana Prince', 'diana@example.com', 'moderator', NULL)");
  // Eve: unchanged
  newDb.execute("INSERT INTO users VALUES (5, 'Eve Wilson', 'eve@example.com', 'user', NULL)");
  // New users
  newDb.execute("INSERT INTO users VALUES (6, 'Frank Castle', 'frank@example.com', 'user', 'https://img.example.com/frank.png')");
  newDb.execute("INSERT INTO users VALUES (7, 'Grace Hopper', 'grace@example.com', 'admin', NULL)");

  // Products table: price changes, new product, one removed
  newDb.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      category TEXT,
      in_stock INTEGER DEFAULT 1
    )
  ''');
  newDb.execute("INSERT INTO products VALUES (1, 'Widget', 12.99, 'gadgets', 1)");   // price up
  newDb.execute("INSERT INTO products VALUES (2, 'Gizmo', 24.99, 'gadgets', 0)");    // out of stock
  newDb.execute("INSERT INTO products VALUES (3, 'Doohickey', 4.50, 'tools', 1)");   // unchanged
  // Product 4 deleted
  newDb.execute("INSERT INTO products VALUES (5, 'Whatchamacallit', 6.99, 'gadgets', 1)"); // price & category changed
  newDb.execute("INSERT INTO products VALUES (6, 'Contraption', 19.99, 'tools', 1)"); // new

  // Orders: some status changes, new orders
  newDb.execute('''
    CREATE TABLE orders (
      id INTEGER PRIMARY KEY,
      user_id INTEGER,
      product_id INTEGER,
      quantity INTEGER,
      total REAL,
      status TEXT DEFAULT 'pending',
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');
  newDb.execute("INSERT INTO orders VALUES (1, 1, 2, 1, 24.99, 'completed')");       // unchanged
  newDb.execute("INSERT INTO orders VALUES (2, 2, 1, 3, 38.97, 'completed')");       // total changed (price went up)
  newDb.execute("INSERT INTO orders VALUES (3, 3, 3, 2, 9.00, 'cancelled')");        // status changed
  newDb.execute("INSERT INTO orders VALUES (4, 1, 5, 1, 6.99, 'delivered')");        // total & status changed
  newDb.execute("INSERT INTO orders VALUES (5, 4, 4, 1, 15.00, 'refunded')");        // status changed
  newDb.execute("INSERT INTO orders VALUES (6, 6, 6, 2, 39.98, 'pending')");         // new order
  newDb.execute("INSERT INTO orders VALUES (7, 7, 1, 1, 12.99, 'pending')");         // new order

  // audit_log table: REMOVED (not present in new DB)

  // New table: notifications
  newDb.execute('''
    CREATE TABLE notifications (
      id INTEGER PRIMARY KEY,
      user_id INTEGER,
      message TEXT NOT NULL,
      read INTEGER DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''');
  newDb.execute("INSERT INTO notifications VALUES (1, 1, 'Your order has been delivered', 1)");
  newDb.execute("INSERT INTO notifications VALUES (2, 6, 'Welcome to the platform!', 0)");
  newDb.execute("INSERT INTO notifications VALUES (3, 4, 'Order refunded', 0)");

  newDb.dispose();
  print('Created: $newPath');

  // --- Encrypted Database (SQLCipher) ---
  final encPath = '$dir/encrypted.db';
  final encFile = File(encPath);
  if (encFile.existsSync()) encFile.deleteSync();
  final encDb = sqlite3.open(encPath);

  // Check if SQLCipher is available
  final cipherVersion = encDb.select('PRAGMA cipher_version;');
  if (cipherVersion.isEmpty || cipherVersion.first.values.first == null) {
    encDb.dispose();
    print('Skipped encrypted.db: SQLCipher not available (install sqlcipher_flutter_libs or brew install sqlcipher)');
  } else {
    encDb.execute("PRAGMA key = 'demo123';");

    encDb.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT DEFAULT 'user',
        avatar_url TEXT
      )
    ''');
    encDb.execute("INSERT INTO users VALUES (1, 'Alice Johnson', 'alice@encrypted.com', 'admin', NULL)");
    encDb.execute("INSERT INTO users VALUES (2, 'Robert Smith', 'bob@example.com', 'moderator', NULL)");
    encDb.execute("INSERT INTO users VALUES (4, 'Diana Prince', 'diana@example.com', 'moderator', NULL)");
    encDb.execute("INSERT INTO users VALUES (5, 'Eve Wilson', 'eve@example.com', 'user', NULL)");

    encDb.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT,
        in_stock INTEGER DEFAULT 1
      )
    ''');
    encDb.execute("INSERT INTO products VALUES (1, 'Widget', 14.99, 'gadgets', 1)");
    encDb.execute("INSERT INTO products VALUES (2, 'Gizmo', 24.99, 'gadgets', 1)");
    encDb.execute("INSERT INTO products VALUES (3, 'Doohickey', 4.50, 'tools', 1)");

    encDb.dispose();
    print('Created (encrypted, password=demo123): $encPath');
  }

  print('\nDone! Compare old.db and new.db in the app.');
  print('For encrypted testing, compare old.db with encrypted.db (password: demo123).');
}
