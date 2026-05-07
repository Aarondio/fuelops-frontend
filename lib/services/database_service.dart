import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'meter_reader.db');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pump_id INTEGER NOT NULL,
        pump_name TEXT,
        opening_reading REAL NOT NULL,
        closing_reading REAL,
        declared_litres_sold REAL,
        declared_cash_collected REAL,
        attendant_id INTEGER,
        ocr_confidence REAL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        notes TEXT,
        opening_image_path TEXT,
        closing_image_path TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        error_message TEXT,
        server_id INTEGER,
        retry_count INTEGER DEFAULT 0,
        last_retry_at TEXT,
        is_closing_only INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_pumps (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        product_type TEXT NOT NULL,
        current_price REAL NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_readings (
        id INTEGER PRIMARY KEY,
        pump_id INTEGER NOT NULL,
        pump_name TEXT,
        attendant_id INTEGER,
        opening_reading REAL NOT NULL,
        closing_reading REAL,
        volume_sold REAL,
        declared_litres_sold REAL,
        declared_cash_collected REAL,
        price_at_close REAL,
        expected_revenue REAL,
        volume_variance REAL,
        revenue_variance REAL,
        variance_status TEXT,
        handover_confirmed_at TEXT,
        closed_at TEXT,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        status TEXT DEFAULT 'open',
        notes TEXT,
        ocr_confidence REAL,
        low_confidence_flag INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_wholesale_customers (
        id INTEGER PRIMARY KEY,
        station_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        company_name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        credit_limit REAL NOT NULL,
        current_balance REAL NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_tank_dips (
        id INTEGER PRIMARY KEY,
        tank_id INTEGER NOT NULL,
        station_id INTEGER NOT NULL,
        recorded_by INTEGER NOT NULL,
        date TEXT NOT NULL,
        opening_dip REAL NOT NULL,
        closing_dip REAL,
        deliveries_received REAL NOT NULL,
        volume_dispensed REAL NOT NULL,
        expected_closing REAL,
        variance REAL,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_deliveries (
        id INTEGER PRIMARY KEY,
        station_id INTEGER NOT NULL,
        tank_id INTEGER NOT NULL,
        product_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        actual_received_volume REAL,
        unit_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        supplier_name TEXT NOT NULL,
        delivery_note_number TEXT,
        delivered_at TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_wholesale_transactions (
        id INTEGER PRIMARY KEY,
        station_id INTEGER NOT NULL,
        wholesale_customer_id INTEGER NOT NULL,
        product_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        payment_status TEXT NOT NULL,
        amount_paid REAL NOT NULL,
        reference_number TEXT,
        transaction_date TEXT NOT NULL,
        notes TEXT,
        customer_name TEXT,
        customer_company_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        read_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_attendants (
        id INTEGER PRIMARY KEY,
        station_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE pending_readings ADD COLUMN server_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE pending_readings ADD COLUMN retry_count INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE pending_readings ADD COLUMN last_retry_at TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE pending_readings ADD COLUMN is_closing_only INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_pumps (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          product_type TEXT NOT NULL,
          current_price REAL NOT NULL,
          is_active INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_readings (
          id INTEGER PRIMARY KEY,
          pump_id INTEGER NOT NULL,
          pump_name TEXT,
          opening_reading REAL NOT NULL,
          closing_reading REAL,
          volume_sold REAL,
          date TEXT NOT NULL,
          shift TEXT NOT NULL,
          is_open INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE pending_readings ADD COLUMN declared_litres_sold REAL');
      await db.execute('ALTER TABLE pending_readings ADD COLUMN declared_cash_collected REAL');
      await db.execute('ALTER TABLE pending_readings ADD COLUMN attendant_id INTEGER');
      await db.execute('ALTER TABLE pending_readings ADD COLUMN ocr_confidence REAL');
      try {
        await db.execute('ALTER TABLE cached_readings ADD COLUMN attendant_id INTEGER');
        await db.execute('ALTER TABLE cached_readings ADD COLUMN variance_status TEXT');
        await db.execute('ALTER TABLE cached_readings ADD COLUMN revenue_variance REAL');
        await db.execute('ALTER TABLE cached_readings ADD COLUMN handover_confirmed_at TEXT');
        await db.execute('ALTER TABLE cached_readings ADD COLUMN status TEXT DEFAULT \'open\'');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      // Add full detail columns to cached_readings
      final cols = [
        'declared_litres_sold REAL',
        'declared_cash_collected REAL',
        'price_at_close REAL',
        'expected_revenue REAL',
        'volume_variance REAL',
        'closed_at TEXT',
        'notes TEXT',
        'ocr_confidence REAL',
        'low_confidence_flag INTEGER DEFAULT 0',
      ];
      for (final col in cols) {
        try {
          await db.execute('ALTER TABLE cached_readings ADD COLUMN $col');
        } catch (_) {}
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_tank_dips (
            id INTEGER PRIMARY KEY,
            tank_id INTEGER NOT NULL,
            station_id INTEGER NOT NULL,
            recorded_by INTEGER NOT NULL,
            date TEXT NOT NULL,
            opening_dip REAL NOT NULL,
            closing_dip REAL,
            deliveries_received REAL NOT NULL,
            volume_dispensed REAL NOT NULL,
            expected_closing REAL,
            variance REAL,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_deliveries (
            id INTEGER PRIMARY KEY,
            station_id INTEGER NOT NULL,
            tank_id INTEGER NOT NULL,
            product_type TEXT NOT NULL,
            quantity REAL NOT NULL,
            actual_received_volume REAL,
            unit_price REAL NOT NULL,
            total_amount REAL NOT NULL,
            supplier_name TEXT NOT NULL,
            delivery_note_number TEXT,
            delivered_at TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_wholesale_customers (
            id INTEGER PRIMARY KEY,
            station_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            company_name TEXT,
            phone TEXT,
            email TEXT,
            address TEXT,
            credit_limit REAL NOT NULL,
            current_balance REAL NOT NULL,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_wholesale_transactions (
            id INTEGER PRIMARY KEY,
            station_id INTEGER NOT NULL,
            wholesale_customer_id INTEGER NOT NULL,
            product_type TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit_price REAL NOT NULL,
            total_amount REAL NOT NULL,
            payment_status TEXT NOT NULL,
            amount_paid REAL NOT NULL,
            reference_number TEXT,
            transaction_date TEXT NOT NULL,
            notes TEXT,
            customer_name TEXT,
            customer_company_name TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_notifications (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            read_at TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_attendants (
            id INTEGER PRIMARY KEY,
            station_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            is_active INTEGER DEFAULT 1
          )
        ''');
      } catch (_) {}
    }
  }

  // Pumps Cache

  Future<void> cachePumps(List<Map<String, dynamic>> pumps) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_pumps');
      for (final pump in pumps) {
        await txn.insert('cached_pumps', pump);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedPumps() async {
    final db = await database;
    return await db.query('cached_pumps');
  }

  // Readings Cache — accumulates across dates via upsert

  Future<void> upsertReadings(List<Map<String, dynamic>> readings) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final reading in readings) {
        await txn.insert(
          'cached_readings',
          reading,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Returns cached readings for a specific date (yyyy-MM-dd)
  Future<List<Map<String, dynamic>>> getCachedReadingsForDate(String date) async {
    final db = await database;
    return await db.query(
      'cached_readings',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at DESC',
    );
  }

  /// Returns all cached readings — used for offline fallback when date unknown
  Future<List<Map<String, dynamic>>> getCachedReadings() async {
    final db = await database;
    return await db.query('cached_readings', orderBy: 'created_at DESC');
  }

  /// Returns the set of dates (yyyy-MM-dd strings) that have cached readings
  Future<Set<String>> getCachedDates() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT date FROM cached_readings');
    return rows.map((r) => r['date'] as String).toSet();
  }

  // Pending Readings CRUD

  Future<int> insertPendingReading(Map<String, dynamic> reading) async {
    final db = await database;
    return await db.insert('pending_readings', reading);
  }

  Future<List<Map<String, dynamic>>> getPendingReadings() async {
    final db = await database;
    return await db.query(
      'pending_readings',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllPendingReadings() async {
    final db = await database;
    return await db.query('pending_readings', orderBy: 'created_at DESC');
  }

  Future<int> updatePendingReadingStatus(
    int id,
    String status, {
    String? errorMessage,
  }) async {
    final db = await database;
    return await db.update(
      'pending_readings',
      {'sync_status': status, 'error_message': errorMessage},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePendingReadingServerId(int id, int serverId) async {
    final db = await database;
    return await db.update(
      'pending_readings',
      {'server_id': serverId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateRetryCount(int id, int retryCount) async {
    final db = await database;
    return await db.update(
      'pending_readings',
      {'retry_count': retryCount, 'last_retry_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePendingReading(int id) async {
    final db = await database;
    return await db.delete('pending_readings', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_readings WHERE sync_status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearSyncedReadings() async {
    final db = await database;
    await db.delete('pending_readings', where: 'sync_status = ?', whereArgs: ['synced']);
  }

  // Wholesale Customers Cache

  Future<void> upsertWholesaleCustomers(List<Map<String, dynamic>> customers) async {
    if (customers.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final c in customers) {
        await txn.insert('cached_wholesale_customers', c, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedWholesaleCustomers({
    String? search,
    String? status,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (search != null && search.isNotEmpty) {
      where.add('(name LIKE ? OR company_name LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }
    return await db.query(
      'cached_wholesale_customers',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getCachedWholesaleCustomer(int id) async {
    final db = await database;
    final rows = await db.query('cached_wholesale_customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteWholesaleCustomerFromCache(int id) async {
    final db = await database;
    await db.delete('cached_wholesale_customers', where: 'id = ?', whereArgs: [id]);
    await db.delete('cached_wholesale_transactions', where: 'wholesale_customer_id = ?', whereArgs: [id]);
  }

  // Wholesale Transactions Cache

  Future<void> upsertWholesaleTransactions(List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final t in transactions) {
        await txn.insert('cached_wholesale_transactions', t, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedWholesaleTransactions({int? customerId}) async {
    final db = await database;
    return await db.query(
      'cached_wholesale_transactions',
      where: customerId != null ? 'wholesale_customer_id = ?' : null,
      whereArgs: customerId != null ? [customerId] : null,
      orderBy: 'transaction_date DESC',
    );
  }

  // Tank Dips Cache

  Future<void> upsertTankDips(List<Map<String, dynamic>> dips) async {
    if (dips.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final d in dips) {
        await txn.insert('cached_tank_dips', d, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedTankDips() async {
    final db = await database;
    return await db.query('cached_tank_dips', orderBy: 'date DESC, created_at DESC');
  }

  // Deliveries Cache

  Future<void> upsertDeliveries(List<Map<String, dynamic>> deliveries) async {
    if (deliveries.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final d in deliveries) {
        await txn.insert('cached_deliveries', d, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedDeliveries() async {
    final db = await database;
    return await db.query('cached_deliveries', orderBy: 'delivered_at DESC');
  }

  // Notifications Cache

  Future<void> upsertNotifications(List<Map<String, dynamic>> notifications) async {
    if (notifications.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final n in notifications) {
        await txn.insert(
          'cached_notifications',
          n,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedNotifications() async {
    final db = await database;
    return await db.query('cached_notifications', orderBy: 'created_at DESC');
  }

  Future<void> updateCachedNotificationRead(String id) async {
    final db = await database;
    await db.update(
      'cached_notifications',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND read_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> markAllCachedNotificationsRead() async {
    final db = await database;
    await db.update(
      'cached_notifications',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'read_at IS NULL',
    );
  }

  // Attendants Cache

  /// Replaces ALL cached attendants — prevents stale entries from prior station logins.
  Future<void> replaceAllAttendants(List<Map<String, dynamic>> attendants) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_attendants');
      for (final a in attendants) {
        await txn.insert('cached_attendants', a);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedAttendants() async {
    final db = await database;
    return await db.query('cached_attendants', orderBy: 'name ASC');
  }
}
