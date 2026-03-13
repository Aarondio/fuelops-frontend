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
      version: 4,
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
  }

  // Pumps Cache
  Future<void> cachePumps(List<Map<String, dynamic>> pumps) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_pumps');
      for (var pump in pumps) {
        await txn.insert('cached_pumps', pump);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedPumps() async {
    final db = await database;
    return await db.query('cached_pumps');
  }

  // Readings Cache
  Future<void> cacheReadings(List<Map<String, dynamic>> readings) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_readings');
      for (var reading in readings) {
        await txn.insert('cached_readings', reading);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedReadings() async {
    final db = await database;
    return await db.query('cached_readings', orderBy: 'created_at DESC');
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
    return await db.query(
      'pending_readings',
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updatePendingReadingStatus(
    int id,
    String status, {
    String? errorMessage,
  }) async {
    final db = await database;
    return await db.update(
      'pending_readings',
      {
        'sync_status': status,
        'error_message': errorMessage,
      },
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
      {
        'retry_count': retryCount,
        'last_retry_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePendingReading(int id) async {
    final db = await database;
    return await db.delete(
      'pending_readings',
      where: 'id = ?',
      whereArgs: [id],
    );
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
    await db.delete(
      'pending_readings',
      where: 'sync_status = ?',
      whereArgs: ['synced'],
    );
  }
}
