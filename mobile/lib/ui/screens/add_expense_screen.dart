import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../logic/expense_bloc.dart';
import '../../models/expense.dart';
import '../../data/expense_api_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = "Other";
  final List<String> _categories = ["Groceries", "Transport", "Entertainment", "Bills", "Shopping", "Other"];

  void _clearForm() {
    _storeController.clear();
    _amountController.clear();
    setState(() {
      _selectedCategory = "Other";
      _selectedDate = DateTime.now();
    });
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        context.read<ExpenseBloc>().add(ProcessReceiptEvent(bytes: bytes));
      } else {
        context.read<ExpenseBloc>().add(ProcessReceiptEvent(image: File(image.path)));
      }
      _clearForm();
    }
  }

  void _submitManualEntry() {
    final String store = _storeController.text.trim();
    final double? amount = double.tryParse(_amountController.text);
    if (store.isEmpty || amount == null) return;

    final apiService = context.read<ExpenseApiService>();

    final newExpense = Expense(
      id: const Uuid().v4(),
      userId: apiService.userId ?? "", // Use the authenticated ID
      storeName: store,
      amount: amount,
      date: _selectedDate,
      category: _selectedCategory,
      currency: "RON",
    );

    context.read<ExpenseBloc>().add(AddExpenseLocally(newExpense));
    _clearForm();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8D7B68),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2B2118),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const vintageBg = Color(0xFFF4EBD9);
    const vintageInk = Color(0xFF2B2118);
    return Scaffold(
      backgroundColor: vintageBg,
      appBar: AppBar(title: const Text("NEW LEDGER ENTRY")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAD8B1),
                border: Border.all(color: const Color(0xFF8D7B68), width: 3),
                boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(4, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: Text("TRANSACTION DETAILS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12))),
                  const Divider(color: Color(0xFF8D7B68), thickness: 1.5),
                  _buildVintageField("Establishment Name", _storeController, Icons.store),
                  const SizedBox(height: 15),
                  _buildVintageField("Amount Transacted", _amountController, Icons.attach_money, isNumber: true),
                  const SizedBox(height: 15),
                  _buildVintageDropdown("Classification"),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Transaction Date",
                        prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF2B2118)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(fontFamily: 'Georgia', color: Color(0xFF2B2118))),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _submitManualEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: vintageInk, foregroundColor: vintageBg, elevation: 5,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: const Text("RECORD IN PERMANENT LEDGER", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildVintageIconButton(Icons.camera_alt, "SCAN RECEIPT", () => _pickImage(context, ImageSource.camera)),
                _buildVintageIconButton(Icons.photo_library, "FROM GALLERY", () => _pickImage(context, ImageSource.gallery)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVintageField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontFamily: 'Georgia'),
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF2B2118)),
        labelStyle: const TextStyle(color: Color(0xFF5E503F)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2B2118), width: 2)),
      ),
    );
  }

  Widget _buildVintageDropdown(String label) {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: label, prefixIcon: const Icon(Icons.category, color: Color(0xFF2B2118)),
        labelStyle: const TextStyle(color: Color(0xFF5E503F)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D7B68))),
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  Widget _buildVintageIconButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onPressed, icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFD6C5A0), foregroundColor: const Color(0xFF2B2118),
            padding: const EdgeInsets.all(20), shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF8D7B68), width: 1)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      ],
    );
  }
}