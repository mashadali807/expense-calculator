// ─────────────────────────────────────────────────────────────────
//  DatabaseHelper – SQLite layer for ExpenseIQ (FINAL FIXED)
// ─────────────────────────────────────────────────────────────────

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  static const _dbName = 'expenseiq.db';
  static const _dbVersion = 1;

  static const tableExpenses = 'expenses';

  static const colId = 'id';
  static const colTitle = 'title';
  static const colAmount = 'amount';
  static const colCategory = 'category';
  static const colDate = 'date';
  static const colNote = 'note';
  static const colCreatedAt = 'created_at';

  // ── INIT ──────────────────────────────────────────────────────
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,

      // ✅ FIXED WAL issue
      onOpen: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableExpenses (
        $colId        TEXT    PRIMARY KEY,
        $colTitle     TEXT    NOT NULL,
        $colAmount    REAL    NOT NULL CHECK($colAmount > 0),
        $colCategory  TEXT    NOT NULL,
        $colDate      INTEGER NOT NULL,
        $colNote      TEXT,
        $colCreatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_expenses_date ON $tableExpenses ($colDate)');
    await db.execute(
        'CREATE INDEX idx_expenses_category ON $tableExpenses ($colCategory)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ── CREATE ────────────────────────────────────────────────────
  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert(
      tableExpenses,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── READ ──────────────────────────────────────────────────────
  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      orderBy: '$colDate DESC, $colCreatedAt DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: '$colId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Expense.fromMap(rows.first);
  }

  Future<List<Expense>> getExpensesForDay(DateTime day) async {
    final start =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: '$colDate BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: '$colCreatedAt DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;

    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: '$colDate BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: '$colDate DESC, $colCreatedAt DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> searchExpenses(String query) async {
    final db = await database;
    final like = '%${query.toLowerCase()}%';
    final rows = await db.query(
      tableExpenses,
      where: 'LOWER($colTitle) LIKE ? OR LOWER($colNote) LIKE ?',
      whereArgs: [like, like],
      orderBy: '$colDate DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: '$colCategory = ?',
      whereArgs: [category],
      orderBy: '$colDate DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  // ── UPDATE ────────────────────────────────────────────────────
  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return db.update(
      tableExpenses,
      expense.toMap(),
      where: '$colId = ?',
      whereArgs: [expense.id],
    );
  }

  // ── DELETE ────────────────────────────────────────────────────
  Future<int> deleteExpense(String id) async {
    final db = await database;
    return db.delete(
      tableExpenses,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllExpenses() async {
    final db = await database;
    await db.delete(tableExpenses);
  }

  // ── AGGREGATES ────────────────────────────────────────────────
  Future<double> getTotalAmount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM($colAmount), 0) AS total FROM $tableExpenses');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTodayTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM($colAmount), 0) AS total '
          'FROM $tableExpenses '
          'WHERE $colDate BETWEEN ? AND ?',
      [start, end],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthTotal(int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;

    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM($colAmount), 0) AS total '
          'FROM $tableExpenses '
          'WHERE $colDate BETWEEN ? AND ?',
      [start, end],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getCategoryTotalsForMonth(
      int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT $colCategory, COALESCE(SUM($colAmount), 0) AS total '
          'FROM $tableExpenses '
          'WHERE $colDate BETWEEN ? AND ? '
          'GROUP BY $colCategory '
          'ORDER BY total DESC',
      [start, end],
    );

    return {
      for (final row in rows)
        row[colCategory] as String: (row['total'] as num).toDouble(),
    };
  }

  Future<Map<String, double>> getAllTimeCategoryTotals() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT $colCategory, COALESCE(SUM($colAmount), 0) AS total '
          'FROM $tableExpenses '
          'GROUP BY $colCategory '
          'ORDER BY total DESC',
    );

    return {
      for (final row in rows)
        row[colCategory] as String: (row['total'] as num).toDouble(),
    };
  }

  Future<Map<int, double>> getDailyTotalsForMonth(int year, int month) async {
    final expenses = await getExpensesForMonth(year, month);
    final map = <int, double>{};
    for (final e in expenses) {
      map[e.date.day] = (map[e.date.day] ?? 0) + e.amount;
    }
    return map;
  }

  Future<int> getExpenseCount() async {
    final db = await database;
    final result =
    await db.rawQuery('SELECT COUNT(*) AS cnt FROM $tableExpenses');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}