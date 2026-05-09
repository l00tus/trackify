import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/expense_bloc.dart';
import '../../models/expense.dart';

enum StatPeriod { day, month, year, all }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedCategory;
  StatPeriod _selectedPeriod = StatPeriod.all;
  DateTime _focusedDate = DateTime.now();

  static const Map<String, double> exchangeRates = {
    'RON': 1.0, 'USD': 4.58, 'EUR': 4.97, 'GBP': 5.81,
  };

  static const Map<String, String> currencySymbols = {
    'RON': 'lei', 'USD': '\$', 'EUR': '€', 'GBP': '£',
  };

  static const Map<String, IconData> categoryIcons = {
    'Groceries': Icons.local_grocery_store,
    'Transport': Icons.directions_bus,
    'Entertainment': Icons.confirmation_number,
    'Bills': Icons.receipt_long,
    'Shopping': Icons.shopping_bag,
    'Other': Icons.category,
  };

  static const Map<String, Color> categoryColors = {
    'Groceries': Colors.green,
    'Transport': Colors.blue,
    'Entertainment': Colors.orange,
    'Bills': Colors.red,
    'Shopping': Colors.purple,
    'Other': Colors.grey,
  };

  double _convert(double amount, String from, String to) {
    double inRon = amount * (exchangeRates[from] ?? 1.0);
    return inRon / (exchangeRates[to] ?? 1.0);
  }

  List<Expense> _filterByPeriod(List<Expense> expenses) {
    return expenses.where((e) {
      if (_selectedPeriod == StatPeriod.day) {
        return e.date.year == _focusedDate.year &&
            e.date.month == _focusedDate.month &&
            e.date.day == _focusedDate.day;
      } else if (_selectedPeriod == StatPeriod.month) {
        return e.date.year == _focusedDate.year &&
            e.date.month == _focusedDate.month;
      } else if (_selectedPeriod == StatPeriod.year) {
        return e.date.year == _focusedDate.year;
      }
      return true;
    }).toList();
  }

  Future<void> _selectSearchDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _focusedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCategory == null ? "Trackify Dashboard" : "Details: $_selectedCategory"),
        leading: _selectedCategory != null
            ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedCategory = null)
        )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectSearchDate(context),
          ),
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              if (state is ExpenseLoaded) {
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.displayCurrency,
                    dropdownColor: Colors.white,
                    items: exchangeRates.keys.map((curr) => DropdownMenuItem(
                        value: curr,
                        child: Text(curr, style: const TextStyle(color: Colors.black))
                    )).toList(),
                    onChanged: (val) => context.read<ExpenseBloc>().add(ChangeDisplayCurrency(val!)),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _selectedCategory = null);
                context.read<ExpenseBloc>().add(LoadExpenses());
              }
          ),
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) return const Center(child: CircularProgressIndicator());
          if (state is ExpenseError) return Center(child: Text(state.message));

          if (state is ExpenseLoaded) {
            final targetCurrency = state.displayCurrency;
            final symbol = currencySymbols[targetCurrency] ?? '';

            final periodExpenses = _filterByPeriod(state.expenses);
            final filteredExpenses = _selectedCategory == null
                ? periodExpenses
                : periodExpenses.where((e) => e.category == _selectedCategory).toList();

            double totalSum = filteredExpenses.fold(0, (sum, e) => sum + _convert(e.amount, e.currency, targetCurrency));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _selectedPeriod == StatPeriod.all
                        ? "Showing All Time"
                        : "Data for: ${_focusedDate.day}/${_focusedDate.month}/${_focusedDate.year}",
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SegmentedButton<StatPeriod>(
                    segments: const [
                      ButtonSegment(value: StatPeriod.day, label: Text("Day")),
                      ButtonSegment(value: StatPeriod.month, label: Text("Month")),
                      ButtonSegment(value: StatPeriod.year, label: Text("Year")),
                      ButtonSegment(value: StatPeriod.all, label: Text("All")),
                    ],
                    selected: {_selectedPeriod},
                    onSelectionChanged: (newSelection) => setState(() => _selectedPeriod = newSelection.first),
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 280, width: 280,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, res) {
                              if (event is FlTapUpEvent && res?.touchedSection != null && _selectedCategory == null) {
                                final index = res!.touchedSection!.touchedSectionIndex;
                                if (index >= 0 && index < _getUniqueCategories(periodExpenses).length) {
                                  setState(() => _selectedCategory = _getCategoryFromIndex(periodExpenses, targetCurrency, index));
                                }
                              }
                            },
                          ),
                          sections: _selectedCategory == null
                              ? _generateCategorySections(periodExpenses, targetCurrency)
                              : _generateStoreSections(filteredExpenses, targetCurrency),
                          centerSpaceRadius: 80,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_selectedCategory == null ? "TOTAL" : "CATEGORY", style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        Text("${totalSum.toStringAsFixed(2)} $symbol", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedCategory = null),
                            child: const Text("BACK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final item = filteredExpenses[index];
                      final displayAmount = _convert(item.amount, item.currency, targetCurrency);
                      final icon = categoryIcons[item.category] ?? Icons.category;
                      final color = categoryColors[item.category] ?? Colors.blueGrey;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(item.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${item.category} • ${item.date.day}/${item.date.month}/${item.date.year}"),
                        trailing: Text("${displayAmount.toStringAsFixed(2)} $symbol", style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  List<String> _getUniqueCategories(List<Expense> expenses) {
    return expenses.map((e) => e.category).toSet().toList();
  }

  String _getCategoryFromIndex(List<Expense> expenses, String targetCurrency, int index) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, e.currency, targetCurrency);
    }
    return totals.keys.elementAt(index);
  }

  List<PieChartSectionData> _generateCategorySections(List<Expense> expenses, String targetCurrency) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, e.currency, targetCurrency);
    }
    return totals.entries.map((entry) => PieChartSectionData(
      color: categoryColors[entry.key] ?? Colors.grey,
      value: entry.value,
      title: '${entry.key}\n${entry.value.toStringAsFixed(1)}',
      radius: 60, showTitle: true,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2)]),
    )).toList();
  }

  List<PieChartSectionData> _generateStoreSections(List<Expense> expenses, String targetCurrency) {
    final storeTotals = <String, double>{};
    for (var e in expenses) {
      storeTotals[e.storeName] = (storeTotals[e.storeName] ?? 0) + _convert(e.amount, e.currency, targetCurrency);
    }
    final colors = [Colors.teal, Colors.indigo, Colors.brown, Colors.pink, Colors.cyan, Colors.amber];
    int i = 0;
    return storeTotals.entries.map((entry) => PieChartSectionData(
      color: colors[(i++) % colors.length],
      value: entry.value,
      title: '${entry.key}\n${entry.value.toStringAsFixed(1)}',
      radius: 60, showTitle: true,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2)]),
    )).toList();
  }
}