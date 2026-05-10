import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/expense.dart';

class ExpenseApiService {
  static const String _baseUrl = 'http://localhost:8000';
  late final Dio _dio;
  final String userId = "user_123";

  ExpenseApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ));

    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) => "DIRECT";
          return client;
        },
      );
    }
  }

  Future<List<Expense>> fetchExpenses() async {
    try {
      final response = await _dio.get('/expenses/$userId');
      final dynamic rawData = response.data is Map ? response.data['data'] : response.data;

      if (rawData is List) {
        return rawData.map((e) => Expense.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Expense> uploadReceipt(File image) async {
    try {
      FormData formData = FormData.fromMap({
        "user_id": userId,
        "file": await MultipartFile.fromFile(image.path, filename: "receipt.jpg"),
      });
      return await _sendToAi(formData);
    } catch (e) {
      rethrow;
    }
  }

  Future<Expense> uploadReceiptWeb(Uint8List bytes) async {
    try {
      FormData formData = FormData.fromMap({
        "user_id": userId,
        "file": MultipartFile.fromBytes(bytes, filename: "receipt.jpg"),
      });
      return await _sendToAi(formData);
    } catch (e) {
      rethrow;
    }
  }

  Future<Expense> _sendToAi(FormData formData) async {
    final response = await _dio.post('/process-receipt', data: formData);
    final Map<String, dynamic> responseMap = Map<String, dynamic>.from(response.data);
    final Map<String, dynamic> expenseData = Map<String, dynamic>.from(responseMap['data']);
    expenseData['id'] = responseMap['db_id']?.toString() ?? expenseData['id']?.toString();
    return Expense.fromJson(expenseData);
  }

  Future<void> syncExpenses(List<Expense> expenses) async {
    try {
      await _dio.post(
        '/sync-expenses',
        data: expenses.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }
}