import 'package:spendlytic_v2/models/user_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚀 Supabase

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static const String _dbName = 'spendlytic.db';
  static const String _userTable = 'userData';
  static const String _balanceTable = 'balance';
  static const String transactionTable = 'transactions';
  static const String budgetTable = 'budgets';

  Database? _db;
  final _supabase = Supabase.instance.client; // 🚀 Access Supabase Client

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS $_userTable');
          await _createTables(db);
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $budgetTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category TEXT UNIQUE,
              amount REAL
            )
          ''');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_userTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        name TEXT,
        provider TEXT,
        defaultCurrency TEXT,
        sorting TEXT,
        summary TEXT,
        profilePicturePath TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_balanceTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_balance REAL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $transactionTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        category TEXT,
        type TEXT,
        date TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $budgetTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT UNIQUE,
        amount REAL
      )
    ''');
  }

  // ... (User Methods) ...

  Future<void> saveUserData({
    required String email,
    String? name,
    String? provider,
    String? defaultCurrency,
    String? sorting,
    String? summary,
    String? profilePicturePath,
  }) async {
    final db = await database;
    await db.insert(
      _userTable,
      {
        'email': email,
        'name': name ?? '',
        'provider': provider ?? '',
        'defaultCurrency': defaultCurrency ?? '',
        'sorting': sorting ?? '',
        'summary': summary ?? '',
        'profilePicturePath': profilePicturePath ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<UserModel?> getUser() async {
    final db = await database;
    final result = await db.query(_userTable, limit: 1);
    if (result.isNotEmpty) {
      try {
        return UserModel.fromMap(result.first);
      } catch (e) {
        debugPrint("Error parsing user data: $e");
        return null;
      }
    }
    return null;
  }

  Future<void> saveOrUpdateUser(UserModel newUser) async {
    final db = await database;
    await db.insert(
      _userTable,
      newUser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearUserData() async {
    final db = await database;
    await db.delete(_userTable);
    await db.delete(_balanceTable);
    await db.delete(transactionTable);
    await db.delete(budgetTable);
  }

  Future<bool> hasSession() async {
    final db = await database;
    final result = await db.query(_userTable, limit: 1);
    return result.isNotEmpty;
  }

  // ============================================================
  // 🚀 TRANSACTION METHODS (Syncing to Supabase)
  // ============================================================

  /// ✅ Add Transaction (Writes to Local + Cloud)
  Future<void> addTransaction({
    required String title,
    required double amount,
    required String category,
    required String type, // 'expense' or 'income'
    required DateTime date,
  }) async {
    final db = await database;
    
    // 1. Save to SQLite (Local)
    await db.insert(transactionTable, {
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'date': date.toIso8601String(),
    });

    // 2. Save to Supabase (Cloud) -> THIS TRIGGERS THE NOTIFICATION
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('transactions').insert({
          'user_id': user.id,
          'title': title,
          'amount': amount,
          'category': category,
          'transaction_date': date.toIso8601String(),
        });
        debugPrint("✅ Transaction synced to Supabase");
      } catch (e) {
        debugPrint("⚠️ Failed to sync to Supabase (Offline?): $e");
      }
    }
  }

  Future<double> getTotalBudget() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM $budgetTable');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalSpend() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM $transactionTable
      WHERE type = 'expense'
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getRecentExpenses(int limit) async {
    final db = await database;
    return await db.query(
      transactionTable,
      where: 'type = ?',
      whereArgs: ['expense'],
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<Map<String, double>> getCategoryTotals() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM $transactionTable
      WHERE type = 'expense'
      GROUP BY category
    ''');
    Map<String, double> totals = {};
    for (var row in result) {
      final category = row['category'] as String?;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      if (category != null) {
        totals[category] = total;
      }
    }
    return totals;
  }

  Future<void> updateUserName(String newName) async {
    final db = await database;
    await db.update(
      _userTable,
      {'name': newName},
      where: 'name IS NOT NULL',
    );
  }

  // ============================================================
  // 🚀 BUDGET METHODS (Syncing to Supabase)
  // ============================================================

  /// ✅ Set Budget (Writes to Local + Cloud)
  Future<void> setBudget(String category, double amount) async {
    final db = await database;
    
    // 1. SQLite
    await db.insert(
      budgetTable,
      {
        'category': category,
        'amount': amount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Supabase 🚀
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('budgets').upsert({
          'user_id': user.id,
          'category': category,
          'amount': amount,
        }, onConflict: 'user_id, category'); 
        debugPrint("✅ Budget synced to Supabase for $category");
      } catch (e) {
        debugPrint("⚠️ Failed to sync budget: $e");
      }
    }
  }

  /// Get all budgets (Local)
  Future<Map<String, double>> getBudgets() async {
    final db = await database;
    final result = await db.query(budgetTable);
    return {
      for (var row in result)
        row['category'] as String: (row['amount'] as num?)?.toDouble() ?? 0.0
    };
  }

  /// Get daily expense sums (Required for Budget Chart)
  Future<Map<DateTime, double>> getDailyExpenseSums() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DATE(date) as day, SUM(amount) as total
      FROM $transactionTable
      WHERE type = 'expense'
      GROUP BY DATE(date)
    ''');

    Map<DateTime, double> sums = {};
    for (final row in result) {
      final dayStr = row['day'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      final day = DateTime.parse(dayStr);
      sums[DateTime(day.year, day.month, day.day)] = total;
    }
    return sums;
  }

  // ============================================================
  // 🚀 SYNC: RESTORE DATA FROM CLOUD (THIS WAS MISSING)
  // ============================================================

  /// Fetch all data from Supabase and fill local SQLite
  Future<void> restoreDataFromCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      debugPrint("☁️ Starting Cloud Restore for user: ${user.id}...");

      // 1. Fetch Transactions from Cloud
      final List<dynamic> cloudTransactions = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id);

      // 2. Fetch Budgets from Cloud
      final List<dynamic> cloudBudgets = await _supabase
          .from('budgets')
          .select()
          .eq('user_id', user.id);

      final db = await database;
      final batch = db.batch();

      // 3. Insert Transactions into SQLite
      for (var row in cloudTransactions) {
        batch.insert(
          transactionTable,
          {
            'title': row['title'],
            'amount': row['amount'],
            'category': row['category'],
            'type': 'expense', // Assuming 'expense' for now
            'date': row['transaction_date'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. Insert Budgets into SQLite
      for (var row in cloudBudgets) {
        batch.insert(
          budgetTable,
          {
            'category': row['category'],
            'amount': row['amount'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      debugPrint("✅ Cloud Data Successfully Restored to Local SQLite");

    } catch (e) {
      debugPrint("❌ Error restoring cloud data: $e");
    }
  }
}