import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/expense_bloc.dart';
import '../../models/expense.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedCategory;

  static const Map<String, double> exchangeRates = {
    'RON': 1.0,
    'USD': 4.58,
    'EUR': 4.97,
    'GBP': 5.81,
  };

  static const Map<String, String> currencySymbols = {
    'RON': 'lei',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCategory == null ? "Trackify Dashboard" : "Details: $_selectedCategory"),
        leading: _selectedCategory != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedCategory = null),
        )
            : null,
        actions: [
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              if (state is ExpenseLoaded) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).primaryColor, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.displayCurrency,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14
                        ),
                        items: exchangeRates.keys.map((String curr) {
                          return DropdownMenuItem(
                              value: curr,
                              child: Text(curr, style: const TextStyle(color: Colors.black))
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            context.read<ExpenseBloc>().add(ChangeDisplayCurrency(newValue));
                          }
                        },
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ExpenseBloc>().add(LoadExpenses()),
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

            List<Expense> filteredExpenses = _selectedCategory == null
                ? state.expenses
                : state.expenses.where((e) => e.category == _selectedCategory).toList();

            double totalSum = 0;
            for (var e in filteredExpenses) {
              totalSum += _convert(e.amount, e.currency, targetCurrency);
            }

            return Column(
              children: [
                const SizedBox(height: 30),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 300,
                      width: 300,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              if (event is FlTapUpEvent &&
                                  pieTouchResponse != null &&
                                  pieTouchResponse.touchedSection != null &&
                                  _selectedCategory == null) {
                                final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                setState(() {
                                  _selectedCategory = _getCategoryFromIndex(state.expenses, targetCurrency, index);
                                });
                              }
                            },
                          ),
                          sections: _selectedCategory == null
                              ? _generateCategorySections(state.expenses, targetCurrency)
                              : _generateStoreSections(filteredExpenses, targetCurrency),
                          centerSpaceRadius: 80,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedCategory == null ? "TOTAL" : "CATEGORY",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${totalSum.toStringAsFixed(2)} $symbol",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedCategory = null),
                            child: const Text("BACK", style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final item = filteredExpenses[index];
                      final displayAmount = _convert(item.amount, item.currency, targetCurrency);
                      final icon = categoryIcons[item.category] ?? Icons.help_outline;
                      final color = categoryColors[item.category] ?? Colors.blueGrey;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.2),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(item.storeName),
                        subtitle: Text("${item.category} (${item.amount} RON)"),
                        trailing: Text(
                          "${displayAmount.toStringAsFixed(2)} $symbol",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  String _getCategoryFromIndex(List<Expense> expenses, String targetCurrency, int index) {
    final Map<String, double> totals = {};
    for (var e in expenses) {
      double converted = _convert(e.amount, e.currency, targetCurrency);
      totals[e.category] = (totals[e.category] ?? 0) + converted;
    }
    if (index < 0 || index >= totals.length) return "Other";
    return totals.keys.elementAt(index);
  }

  List<PieChartSectionData> _generateCategorySections(List<Expense> expenses, String targetCurrency) {
    final Map<String, double> totals = {};
    for (var e in expenses) {
      double converted = _convert(e.amount, e.currency, targetCurrency);
      totals[e.category] = (totals[e.category] ?? 0) + converted;
    }

    return totals.entries.map((entry) {
      final symbol = currencySymbols[targetCurrency] ?? '';
      return PieChartSectionData(
        color: categoryColors[entry.key] ?? Colors.blueGrey,
        value: entry.value,
        title: '${entry.key}\n${entry.value.toStringAsFixed(1)} $symbol',
        radius: 60,
        showTitle: true,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  List<PieChartSectionData> _generateStoreSections(List<Expense> expenses, String targetCurrency) {
    final Map<String, double> storeTotals = {};
    for (var e in expenses) {
      double converted = _convert(e.amount, e.currency, targetCurrency);
      storeTotals[e.storeName] = (storeTotals[e.storeName] ?? 0) + converted;
    }

    final List<Color> colors = [Colors.teal, Colors.indigo, Colors.brown, Colors.pink, Colors.cyan, Colors.amber];
    int colorIdx = 0;

    return storeTotals.entries.map((entry) {
      final symbol = currencySymbols[targetCurrency] ?? '';
      final section = PieChartSectionData(
        color: colors[colorIdx % colors.length],
        value: entry.value,
        title: '${entry.key}\n${entry.value.toStringAsFixed(1)} $symbol',
        radius: 60,
        showTitle: true,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
      colorIdx++;
      return section;
    }).toList();
  }
}