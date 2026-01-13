import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/stock_model.dart';
import '../models/favorite_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('stock_favorites.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        symbol TEXT NOT NULL,
        name TEXT NOT NULL,
        json_data TEXT NOT NULL,
        captured_at INTEGER NOT NULL
      )
    ''');

    // 股票基础信息表 - 发现新股票时保存
    await db.execute('''
      CREATE TABLE stocks (
        symbol TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        exchange TEXT,
        industry TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_stocks_name ON stocks(name)');

    // 每日捕捉到的推荐股票表
    await db.execute('''
      CREATE TABLE recommendations (
        symbol TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stocks (
          symbol TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          exchange TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stocks_name ON stocks(name)',
      );
      await db.execute('DROP TABLE IF EXISTS stock_history');
    }
    if (oldVersion < 4) {
      // Add industry column to stocks table
      await db.execute('ALTER TABLE stocks ADD COLUMN industry TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stocks_industry ON stocks(industry)',
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recommendations (
          symbol TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          json_data TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }
  }

  // ========== Favorites Methods ==========

  Future<void> insertFavorite(FavoriteRecommendation fav) async {
    final db = await database;
    await db.insert('favorites', {
      'id': fav.id,
      'symbol': fav.snapshot.symbol,
      'name': fav.snapshot.name,
      'json_data': jsonEncode(fav.toJson()),
      'captured_at': fav.capturedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavorite(String id) async {
    final db = await database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FavoriteRecommendation>> getFavorites() async {
    final db = await database;
    final result = await db.query('favorites', orderBy: 'captured_at DESC');
    return result.map((json) {
      final jsonData = json['json_data'] as String;
      return FavoriteRecommendation.fromJson(jsonDecode(jsonData));
    }).toList();
  }

  // ========== Stocks Master Table Methods ==========

  /// 批量插入新股票（如果不存在）
  Future<int> insertStocksBatch(List<StockInfo> stocks) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    int inserted = 0;

    final batch = db.batch();
    for (final stock in stocks) {
      if (stock.name.isEmpty) continue;

      String? exchange;
      if (stock.symbol.startsWith('sh')) {
        exchange = 'SH';
      } else if (stock.symbol.startsWith('sz')) {
        exchange = 'SZ';
      }

      batch.insert('stocks', {
        'symbol': stock.symbol,
        'name': stock.name,
        'exchange': exchange,
        'industry': stock.industry,
        'updated_at': now,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    return inserted;
  }

  /// 获取特定板块的股票代码
  Future<List<String>> getSymbolsByIndustry(String industry) async {
    final db = await database;
    final result = await db.query(
      'stocks',
      columns: ['symbol'],
      where: 'industry = ?',
      whereArgs: [industry],
      orderBy: 'updated_at DESC',
    );
    return result.map((row) => row['symbol'] as String).toList();
  }

  /// 获取所有已保存的股票
  Future<List<Map<String, dynamic>>> getAllStocks({String? exchange}) async {
    final db = await database;
    return await db.query(
      'stocks',
      where: exchange != null ? 'exchange = ?' : null,
      whereArgs: exchange != null ? [exchange] : null,
      orderBy: 'symbol ASC',
    );
  }

  /// 搜索股票
  Future<List<Map<String, dynamic>>> searchStocks(String keyword) async {
    final db = await database;
    return await db.query(
      'stocks',
      where: 'symbol LIKE ? OR name LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'symbol ASC',
      limit: 50,
    );
  }

  /// 获取股票数量
  Future<int> getStockCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM stocks');
    return result.first['count'] as int;
  }
  // ========== Recommendations Management ==========

  Future<void> saveRecommendations(List<TradingSuggestion> suggestions) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final sug in suggestions) {
      batch.insert('recommendations', {
        'symbol': sug.stock.symbol,
        'name': sug.stock.name,
        'json_data': jsonEncode(sug.toJson()),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<TradingSuggestion>> getRecommendations() async {
    final db = await database;
    final result = await db.query(
      'recommendations',
      orderBy: 'updated_at DESC',
    );
    return result.map((row) {
      final jsonData = row['json_data'] as String;
      return TradingSuggestion.fromJson(jsonDecode(jsonData));
    }).toList();
  }

  Future<void> clearRecommendations() async {
    final db = await database;
    await db.delete('recommendations');
  }
}
