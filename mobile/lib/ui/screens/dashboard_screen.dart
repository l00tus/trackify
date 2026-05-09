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

  String _defaultCurrency = "RON";

  final List<String> _supportedCurrencies = [
    "USD", "EUR", "GBP", "RON", "CHF", "CNY", "JPY", "ILS", "RUB", "HUF", "PLN",
    "DEM", "GRD", "ITL", "FRF", "ESP", "ATS"
  ];

  // Fallback rates to prevent 1:1 conversion if API fails
  final Map<String, double> _liveRates = {
    "RON": 1.0, "USD": 0.22, "EUR": 0.20, "GBP": 0.17,
    "DEM": 0.40, "GRD": 68.10, "ITL": 387.25,
    "FRF": 1.31, "ESP": 33.27, "ATS": 2.75,
  };

  bool _isLoadingRates = true;

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
              if (_supportedCurrencies.contains(key)) {
                _liveRates[key] = (value is int) ? value.toDouble() : value;
              }
            });
            _isLoadingRates = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  // FIXED TWO-STEP CONVERSION
  double _convert(double amount, String targetCurrency) {
    if (_defaultCurrency == targetCurrency) return amount;

    // 1. Convert Default Input to RON (Base)
    // Formula: Amount / Rate_of_Default_Relative_to_RON
    double rateDefault = _liveRates[_defaultCurrency] ?? 1.0;
    double amountInRon = amount / rateDefault;

    // 2. Convert RON to Target Output
    // Formula: AmountInRon * Rate_of_Target_Relative_to_RON
    if (targetCurrency == "RON") return amountInRon;
    double rateTarget = _liveRates[targetCurrency] ?? 1.0;

    return amountInRon * rateTarget;
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
        title: Text(_selectedCategory ?? "Trackify"),
        actions: [
          _buildCurrencyPicker(
            label: "DEFAULT",
            current: _defaultCurrency,
            onChanged: (val) => setState(() => _defaultCurrency = val!),
          ),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              return _buildCurrencyPicker(
                label: "VIEW IN",
                current: (state is ExpenseLoaded) ? state.displayCurrency : "RON",
                onChanged: (val) => context.read<ExpenseBloc>().add(ChangeDisplayCurrency(val!)),
              );
            },
          ),
          IconButton(icon: Icon(Icons.refresh, color: _isLoadingRates ? Colors.orange : null), onPressed: _fetchLiveRates),
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) return const Center(child: CircularProgressIndicator());
          if (state is ExpenseLoaded) {
            final targetCurrency = state.displayCurrency;
            final periodExpenses = _filterByPeriod(state.expenses);

            if (periodExpenses.isEmpty) {
              return Column(children: [_buildPeriodSelector(), const Expanded(child: Center(child: Text("No entries found.")))]);
            }

            final filteredExpenses = _selectedCategory == null
                ? periodExpenses
                : periodExpenses.where((e) => e.category == _selectedCategory).toList();

            double totalSum = filteredExpenses.fold(0, (sum, e) => sum + _convert(e.amount, targetCurrency));

            return Column(
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 10),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 280, width: 280,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(touchCallback: (event, res) {
                            if (event is FlTapUpEvent && res?.touchedSection != null && _selectedCategory == null) {
                              final index = res!.touchedSection!.touchedSectionIndex;
                              if (index >= 0) setState(() => _selectedCategory = _getCategoryFromIndex(periodExpenses, targetCurrency, index));
                            }
                          }),
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
                        Text(_selectedCategory == null ? "TOTAL" : "CATEGORY", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("${totalSum.toStringAsFixed(2)} $targetCurrency", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      return ListTile(
                        leading: CircleAvatar(child: Icon(_getIcon(item.category))),
                        title: Text(item.storeName),
                        subtitle: Text("${item.category} • ${item.date.day}/${item.date.month}"),
                        trailing: Text("${_convert(item.amount, targetCurrency).toStringAsFixed(2)} $targetCurrency", style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildCurrencyPicker({required String label, required String current, required Function(String?) onChanged}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _supportedCurrencies.contains(current) ? current : "RON",
            isDense: true,
            items: _supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<StatPeriod>(
        segments: const [
          ButtonSegment(value: StatPeriod.day, label: Text("Day")),
          ButtonSegment(value: StatPeriod.month, label: Text("Month")),
          ButtonSegment(value: StatPeriod.year, label: Text("Year")),
          ButtonSegment(value: StatPeriod.all, label: Text("All")),
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (set) => setState(() { _selectedPeriod = set.first; _selectedCategory = null; }),
      ),
    );
  }

  IconData _getIcon(String cat) {
    switch(cat) {
      case 'Groceries': return Icons.local_grocery_store;
      case 'Transport': return Icons.directions_bus;
      case 'Entertainment': return Icons.confirmation_number;
      case 'Bills': return Icons.receipt_long;
      case 'Shopping': return Icons.shopping_bag;
      default: return Icons.category;
    }
  }

  String _getCategoryFromIndex(List<Expense> expenses, String targetCurrency, int index) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, targetCurrency);
    }
    return totals.keys.elementAt(index);
  }

  List<PieChartSectionData> _generateCategorySections(List<Expense> expenses, String targetCurrency) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, targetCurrency);
    }
    int i = 0;
    return totals.entries.map((entry) => PieChartSectionData(
      color: Colors.primaries[i++ % Colors.primaries.length],
      value: entry.value,
      title: '${entry.key}\n${entry.value.toStringAsFixed(1)}',
      radius: 60, showTitle: true,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
    )).toList();
  }

  List<PieChartSectionData> _generateStoreSections(List<Expense> expenses, String targetCurrency) {
    final storeTotals = <String, double>{};
    for (var e in expenses) {
      storeTotals[e.storeName] = (storeTotals[e.storeName] ?? 0) + _convert(e.amount, targetCurrency);
    }
    int i = 0;
    return storeTotals.entries.map((entry) => PieChartSectionData(
      color: Colors.accents[i++ % Colors.accents.length],
      value: entry.value,
      title: '${entry.key}\n${entry.value.toStringAsFixed(1)}',
      radius: 60, showTitle: true,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
    )).toList();
  }
}