import '../models/expense.dart';
import 'local_database.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseLocalService {
  final _db = LocalDatabase.instance;

  Future<void> insertExpense(Expense expense, {bool isSynced = false}) async {
    final db = await _db.database;
    await db.insert(
      'expenses',
      {
        'id': expense.id,
        'user_id': expense.userId,
        'store_name': expense.storeName,
        'amount': expense.amount,
        'date': expense.date.toIso8601String(),
        'category': expense.category,
        'currency': expense.currency,
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // safe for re-sync
    );
  }

  Future<List<Expense>> getAllExpenses(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'expenses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return rows.map(_rowToExpense).toList();
  }

  Future<List<Expense>> getUnsyncedExpenses(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'expenses',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return rows.map(_rowToExpense).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db.database;
    await db.update(
      'expenses',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllSynced(List<String> ids) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'expenses',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAllFromServer(List<Expense> expenses, String userId) async {
    final db = await _db.database;
    await db.delete('expenses', where: 'user_id = ?', whereArgs: [userId]);
    final batch = db.batch();
    for (final e in expenses) {
      batch.insert('expenses', {
        'id': e.id,
        'user_id': e.userId,
        'store_name': e.storeName,
        'amount': e.amount,
        'date': e.date.toIso8601String(),
        'category': e.category,
        'currency': e.currency,
        'is_synced': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  Expense _rowToExpense(Map<String, dynamic> row) {
    return Expense(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      storeName: row['store_name'] as String,
      amount: row['amount'] as double,
      date: DateTime.parse(row['date'] as String),
      category: row['category'] as String,
      currency: row['currency'] as String,
    );
  }
}