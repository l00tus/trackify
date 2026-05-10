import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trackify.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        store_name TEXT,
        amount REAL,
        date TEXT,
        category TEXT,
        currency TEXT
      )
    ''');
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var expense in expenses) {
      batch.insert('expenses', expense.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Expense>> getLocalExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses');
    return result.map((json) => Expense.fromJson(json)).toList();
  }
}