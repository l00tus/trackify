import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Map<String, double> _liveRates = {
    "RON": 1.0, "USD": 0.22, "EUR": 0.20, "GBP": 0.17,
    "CHF": 0.20, "CNY": 1.58, "JPY": 34.21, "ILS": 0.81,
    "RUB": 20.15, "HUF": 78.50, "PLN": 0.88, "AUD": 0.33,
    "CAD": 0.30, "BGN": 0.39, "BRL": 1.10, "HKD": 1.70,
    "CZK": 5.20, "DKK": 1.55, "TRY": 7.30
  };

  bool _isLoadingRates = true;

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

  @override
  void initState() {
    super.initState();
    _fetchLiveRates();
  }

  Future<void> _fetchLiveRates() async {
    try {
      final response = await http.get(Uri.parse('https://api.frankfurter.app/latest?from=RON'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = Map<String, dynamic>.from(data['rates']);
        if (mounted) {
          setState(() {
            rates.forEach((key, value) {
              _liveRates[key] = (value is int) ? value.toDouble() : value;
            });
            _isLoadingRates = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  double _convert(double amount, String toCurrency) {
    if (toCurrency == "RON") return amount;
    return amount * (_liveRates[toCurrency] ?? 1.0);
  }

  List<Expense> _filterByPeriod(List<Expense> expenses) {
    return expenses.where((e) {
      if (_selectedPeriod == StatPeriod.day) {
        return e.date.year == _focusedDate.year && e.date.month == _focusedDate.month && e.date.day == _focusedDate.day;
      } else if (_selectedPeriod == StatPeriod.month) {
        return e.date.year == _focusedDate.year && e.date.month == _focusedDate.month;
      } else if (_selectedPeriod == StatPeriod.year) {
        return e.date.year == _focusedDate.year;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCategory == null ? "Trackify Dashboard" : "Details: $_selectedCategory"),
        leading: _selectedCategory != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedCategory = null))
            : null,
        actions: [
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              if (state is ExpenseLoaded) {
                final sortedKeys = _liveRates.keys.toList()..sort();
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _liveRates.containsKey(state.displayCurrency) ? state.displayCurrency : "RON",
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      items: sortedKeys.map((curr) => DropdownMenuItem(value: curr, child: Text(curr))).toList(),
                      onChanged: (val) {
                        if (val != null) context.read<ExpenseBloc>().add(ChangeDisplayCurrency(val));
                      },
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => context.read<ExpenseBloc>().add(LoadExpenses())),
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) return const Center(child: CircularProgressIndicator());
          if (state is ExpenseLoaded) {
            final targetCurrency = state.displayCurrency;
            final periodExpenses = _filterByPeriod(state.expenses);
            final filteredExpenses = _selectedCategory == null
                ? periodExpenses
                : periodExpenses.where((e) => e.category == _selectedCategory).toList();

            double totalSum = filteredExpenses.fold(0, (sum, e) => sum + _convert(e.amount, targetCurrency));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SegmentedButton<StatPeriod>(
                    segments: const [
                      ButtonSegment(value: StatPeriod.day, label: Text("Day")),
                      ButtonSegment(value: StatPeriod.month, label: Text("Month")),
                      ButtonSegment(value: StatPeriod.year, label: Text("Year")),
                      ButtonSegment(value: StatPeriod.all, label: Text("All")),
                    ],
                    selected: {_selectedPeriod},
                    onSelectionChanged: (set) => setState(() {
                      _selectedPeriod = set.first;
                      _selectedCategory = null; // Reset category when period changes
                    }),
                  ),
                ),
                if (filteredExpenses.isEmpty)
                  const Expanded(child: Center(child: Text("No expenses for this period.")))
                else ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 300, width: 300,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(touchCallback: (event, res) {
                              if (event is FlTapUpEvent && res?.touchedSection != null && _selectedCategory == null) {
                                final index = res!.touchedSection!.touchedSectionIndex;
                                if (index >= 0 && index < _getUniqueCategories(periodExpenses).length) {
                                  setState(() => _selectedCategory = _getCategoryFromIndex(periodExpenses, targetCurrency, index));
                                }
                              }
                            }),
                            sections: _selectedCategory == null
                                ? _generateCategorySections(periodExpenses, targetCurrency)
                                : _generateStoreSections(filteredExpenses, targetCurrency),
                            centerSpaceRadius: 90,
                            sectionsSpace: 3,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_selectedCategory == null ? "TOTAL" : "CATEGORY", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text("${totalSum.toStringAsFixed(2)} $targetCurrency", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_selectedCategory != null)
                            TextButton(onPressed: () => setState(() => _selectedCategory = null), child: const Text("BACK")),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredExpenses.length,
                      itemBuilder: (context, index) {
                        final item = filteredExpenses[index];
                        final icon = categoryIcons[item.category] ?? Icons.category;
                        final color = categoryColors[item.category] ?? Colors.blueGrey;
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                          title: Text(item.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item.category} • ${item.date.day}/${item.date.month}"),
                          trailing: Text("${_convert(item.amount, targetCurrency).toStringAsFixed(2)} $targetCurrency"),
                        );
                      },
                    ),
                  ),
                ]
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  List<String> _getUniqueCategories(List<Expense> expenses) => expenses.map((e) => e.category).toSet().toList();

  String _getCategoryFromIndex(List<Expense> expenses, String targetCurrency, int index) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, targetCurrency);
    }
    if (index < 0 || index >= totals.length) return "Other";
    return totals.keys.elementAt(index);
  }

  List<PieChartSectionData> _generateCategorySections(List<Expense> expenses, String targetCurrency) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, targetCurrency);
    }
    return totals.entries.map((entry) => PieChartSectionData(
      color: categoryColors[entry.key] ?? Colors.grey,
      value: entry.value,
      title: '${entry.key}\n${entry.value.toStringAsFixed(1)}',
      radius: 65, showTitle: true,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2)]),
    )).toList();
  }

  List<PieChartSectionData> _generateStoreSections(List<Expense> expenses, String targetCurrency) {
    final storeTotals = <String, double>{};
    for (var e in expenses) {
      storeTotals[e.storeName] = (storeTotals[e.storeName] ?? 0) + _convert(e.amount, targetCurrency);
    }
    final colors = [Colors.teal, Colors.indigo, Colors.brown, Colors.pink, Colors.cyan, Colors.amber];
    int i = 0;
    return storeTotals.entries.map((entry) => PieChartSectionData(
      color: colors[(i++) % colors.length],
      value: entry.value,
      title: '${entry.key}\n${entry.value.toStringAsFixed(1)}',
      radius: 65, showTitle: true,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2)]),
    )).toList();
  }
}