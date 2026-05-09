import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String userId;
  final String storeName;
  final double amount;
  final DateTime date;
  final String category;

  const Expense({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.amount,
    required this.date,
    required this.category,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      storeName: json['store_name'] ?? 'Unknown',
      amount: (json['amount'] as num? ?? json['total'] as num? ?? 0.0).toDouble(),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? 'Other',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'store_name': storeName,
      'amount': amount,
      'date': date.toIso8601String().split('T')[0],
      'category': category,
    };
  }

  @override
  List<Object?> get props => [id, userId, storeName, amount, date, category];
}