import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/odometer_entry.dart';
import '../models/fuel_entry.dart';
import '../models/maintenance_entry.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bike_tracker.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE odometer_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            reading REAL NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE fuel_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            odometer_reading REAL NOT NULL,
            liters REAL NOT NULL,
            price_per_liter REAL NOT NULL,
            total_cost REAL NOT NULL,
            full_tank INTEGER NOT NULL DEFAULT 1,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE maintenance_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            cost REAL NOT NULL,
            odometer_reading REAL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS maintenance_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              category TEXT NOT NULL,
              cost REAL NOT NULL,
              odometer_reading REAL,
              note TEXT,
              created_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // --- Odometer CRUD ---

  Future<int> insertOdometerEntry(OdometerEntry entry) async {
    final db = await database;
    return await db.insert('odometer_entries', entry.toMap());
  }

  Future<List<OdometerEntry>> getOdometerEntries() async {
    final db = await database;
    final maps = await db.query('odometer_entries', orderBy: 'date DESC, reading DESC');
    return maps.map((m) => OdometerEntry.fromMap(m)).toList();
  }

  Future<OdometerEntry?> getLatestOdometerEntry() async {
    final db = await database;
    final maps = await db.query(
      'odometer_entries',
      orderBy: 'reading DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OdometerEntry.fromMap(maps.first);
  }

  Future<OdometerEntry?> getFirstOdometerEntry() async {
    final db = await database;
    final maps = await db.query(
      'odometer_entries',
      orderBy: 'reading ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OdometerEntry.fromMap(maps.first);
  }

  Future<List<OdometerEntry>> getOdometerEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'odometer_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC, reading ASC',
    );
    return maps.map((m) => OdometerEntry.fromMap(m)).toList();
  }

  Future<int> updateOdometerEntry(OdometerEntry entry) async {
    final db = await database;
    return await db.update(
      'odometer_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteOdometerEntry(int id) async {
    final db = await database;
    return await db.delete('odometer_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- Fuel CRUD ---

  Future<int> insertFuelEntry(FuelEntry entry) async {
    final db = await database;
    return await db.insert('fuel_entries', entry.toMap());
  }

  Future<List<FuelEntry>> getFuelEntries() async {
    final db = await database;
    final maps = await db.query('fuel_entries', orderBy: 'date DESC, odometer_reading DESC');
    return maps.map((m) => FuelEntry.fromMap(m)).toList();
  }

  Future<FuelEntry?> getPreviousFuelEntry(double currentOdometer) async {
    final db = await database;
    final maps = await db.query(
      'fuel_entries',
      where: 'odometer_reading < ?',
      whereArgs: [currentOdometer],
      orderBy: 'odometer_reading DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FuelEntry.fromMap(maps.first);
  }

  Future<int> updateFuelEntry(FuelEntry entry) async {
    final db = await database;
    return await db.update(
      'fuel_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteFuelEntry(int id) async {
    final db = await database;
    return await db.delete('fuel_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FuelEntry>> getFuelEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'fuel_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((m) => FuelEntry.fromMap(m)).toList();
  }

  // --- Maintenance CRUD ---

  Future<int> insertMaintenanceEntry(MaintenanceEntry entry) async {
    final db = await database;
    return await db.insert('maintenance_entries', entry.toMap());
  }

  Future<List<MaintenanceEntry>> getMaintenanceEntries() async {
    final db = await database;
    final maps = await db.query('maintenance_entries', orderBy: 'date DESC');
    return maps.map((m) => MaintenanceEntry.fromMap(m)).toList();
  }

  Future<int> updateMaintenanceEntry(MaintenanceEntry entry) async {
    final db = await database;
    return await db.update(
      'maintenance_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteMaintenanceEntry(int id) async {
    final db = await database;
    return await db.delete('maintenance_entries', where: 'id = ?', whereArgs: [id]);
  }
}
