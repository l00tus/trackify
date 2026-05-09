import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String userId;
  final String storeName;
  final double amount;
  final DateTime date;
  final String category;
  final String currency;

  const Expense({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.amount,
    required this.date,
    required this.category,
    this.currency = 'RON',
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? 'Unknown',
      amount: _parseDouble(json['amount'] ?? json['total'] ?? 0.0),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      category: json['category']?.toString() ?? 'Other',
      currency: json['currency']?.toString() ?? 'RON',
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
      'currency': currency,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  List<Object?> get props => [id, userId, storeName, amount, date, category, currency];
}