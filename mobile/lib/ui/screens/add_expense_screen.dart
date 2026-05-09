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

  @override
  void dispose() {
    _storeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _storeController.clear();
    _amountController.clear();
    setState(() => _selectedCategory = "Other");
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      if (kIsWeb) {
        final Uint8List bytes = await image.readAsBytes();
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

    if (store.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid store name and amount")),
      );
      return;
    }

    final newExpense = Expense(
      id: const Uuid().v4(),
      userId: "user_123",
      storeName: store,
      amount: amount,
      date: DateTime.now(),
      category: _selectedCategory,
    );

    context.read<ExpenseBloc>().add(SyncExpenses([newExpense]));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense saved successfully!")));
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isWindows && !kIsWeb) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text("Scan Receipt"),
                onPressed: () => _pickImage(context, ImageSource.camera),
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text("Upload from Gallery"),
              onPressed: () => _pickImage(context, ImageSource.gallery),
            ),

            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

            TextField(
              controller: _storeController,
              decoration: const InputDecoration(labelText: "Store Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: "Amount", prefixText: "\$ ", border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submitManualEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: const Text("Save Manually", style: TextStyle(fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}