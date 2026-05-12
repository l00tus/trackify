import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import 'local_database.dart';

class ExpenseLocalService {
  final _db = LocalDatabase.instance;

  Future<void> insertExpense(Expense expense, {bool isSynced = false}) async {
    if (kIsWeb) return;
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
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Expense>> getAllExpenses(String userId) async {
    if (kIsWeb) return [];
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
    if (kIsWeb) return [];
    final db = await _db.database;
    final rows = await db.query(
      'expenses',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return rows.map(_rowToExpense).toList();
  }

  Future<void> markSynced(String id) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update(
      'expenses',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllSynced(List<String> ids) async {
    if (kIsWeb) return;
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

  // FIX: wrapped in a transaction so delete and inserts are atomic,
  // and using ConflictAlgorithm.replace so duplicate IDs never crash.
  Future<void> replaceAllFromServer(List<Expense> expenses, String userId) async {
    if (kIsWeb) return;
    final db = await _db.database;

    await db.transaction((txn) async {
      // Delete existing cached rows for this user
      await txn.delete('expenses', where: 'user_id = ?', whereArgs: [userId]);

      // Re-insert everything from server — replace on conflict just in case
      for (final e in expenses) {
        await txn.insert(
          'expenses',
          {
            'id': e.id,
            'user_id': e.userId,
            'store_name': e.storeName,
            'amount': e.amount,
            'date': e.date.toIso8601String(),
            'category': e.category,
            'currency': e.currency,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
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
