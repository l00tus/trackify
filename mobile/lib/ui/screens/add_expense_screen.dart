import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../logic/expense_bloc.dart';
import '../../models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = "Other";
  final List<String> _categories = ["Groceries", "Transport", "Entertainment", "Bills", "Shopping", "Other"];

  void _clearForm() {
    _storeController.clear();
    _amountController.clear();
    setState(() {
      _selectedCategory = "Other";
    });
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        context.read<ExpenseBloc>().add(ProcessReceipt(bytes: bytes));
      } else {
        context.read<ExpenseBloc>().add(ProcessReceipt(image: File(image.path)));
      }
      _clearForm();
    }
  }

  void _submitManualEntry() {
    final String store = _storeController.text.trim();
    final double? amount = double.tryParse(_amountController.text);
    if (store.isEmpty || amount == null) return;

    final newExpense = Expense(
      id: const Uuid().v4(),
      userId: "user_123",
      storeName: store,
      amount: amount,
      date: DateTime.now(),
      category: _selectedCategory,
      currency: "RON",
    );

    context.read<ExpenseBloc>().add(SyncExpenses([newExpense]));
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.gallery),
                  icon: const Icon(Icons.cloud_upload, size: 24),
                  label: const Text("UPLOAD RECEIPT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _storeController,
              decoration: const InputDecoration(
                labelText: "STORE",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: "AMOUNT (RON)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: "CATEGORY",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 48),
            Center(
              child: SizedBox(
                width: 250,
                child: ElevatedButton(
                  onPressed: _submitManualEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: const Text(
                    "SAVE",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}