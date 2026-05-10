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

  final List<String> _supportedCurrencies = [
    "USD", "EUR", "GBP", "RON", "CHF", "CNY", "JPY", "ILS", "RUB", "HUF", "PLN",
    "DEM", "GRD", "ITL", "FRF", "ESP", "ATS"
  ];

  final Map<String, double> _legacyRates = {
    "DEM": 0.40, "GRD": 68.10, "ITL": 387.25,
    "FRF": 1.31, "ESP": 33.27, "ATS": 2.75,
  };

  final Map<String, double> _liveRates = {"RON": 1.0};
  bool _isLoadingRates = true;

  static const Map<String, IconData> categoryIcons = {
    'Groceries': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Entertainment': Icons.theater_comedy,
    'Bills': Icons.history_edu,
    'Shopping': Icons.shopping_basket,
    'Other': Icons.style,
  };

  static const Map<String, Color> categoryColors = {
    'Groceries': Color(0xFF4F6D7A),
    'Transport': Color(0xFF7E6B8F),
    'Entertainment': Color(0xFFA64D32),
    'Bills': Color(0xFF5E503F),
    'Shopping': Color(0xFF22333B),
    'Other': Color(0xFF432818),
  };

  @override
  void initState() {
    super.initState();
    _fetchLiveRates();
  }

  Future<void> _fetchLiveRates() async {
    setState(() => _isLoadingRates = true);
    try {
      final response = await http.get(Uri.parse('https://api.frankfurter.dev/v2/rates?base=RON'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _liveRates.clear();
            _liveRates["RON"] = 1.0;
            for (var item in data) {
              String quote = item['quote'];
              double rate = (item['rate'] as num).toDouble();
              if (_supportedCurrencies.contains(quote)) {
                _liveRates[quote] = rate;
              }
            }
            _isLoadingRates = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  double _convert(double amount, String targetCurrency, String defaultCurrency) {
    if (defaultCurrency == targetCurrency) return amount;
    double amountInRon;
    if (_legacyRates.containsKey(defaultCurrency)) {
      amountInRon = amount / _legacyRates[defaultCurrency]!;
    } else {
      double rateToRon = _liveRates[defaultCurrency] ?? 1.0;
      amountInRon = amount / rateToRon;
    }
    if (targetCurrency == "RON") return amountInRon;
    double finalAmount;
    if (_legacyRates.containsKey(targetCurrency)) {
      finalAmount = amountInRon * _legacyRates[targetCurrency]!;
    } else {
      double rateFromRon = _liveRates[targetCurrency] ?? 1.0;
      finalAmount = amountInRon * rateFromRon;
    }
    return finalAmount;
  }

  @override
  Widget build(BuildContext context) {
    const vintageBg = Color(0xFFF4EBD9);
    const vintageInk = Color(0xFF2B2118);
    const vintageBorder = BorderSide(color: Color(0xFF8D7B68), width: 1.5);

    return Scaffold(
      backgroundColor: vintageBg,
      appBar: AppBar(
        title: Text(_selectedCategory?.toUpperCase() ?? "GENERAL LEDGER"),
        leading: _selectedCategory != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedCategory = null))
            : null,
        actions: [
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              String currentView = (state is ExpenseLoaded) ? state.displayCurrency : "RON";
              return _buildPicker(
                label: "VIEWING IN",
                current: currentView,
                vintageInk: vintageInk,
                onChanged: (val) => context.read<ExpenseBloc>().add(ChangeDisplayCurrency(val!)),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLiveRates),
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) return const Center(child: CircularProgressIndicator(color: vintageInk));
          if (state is ExpenseLoaded) {
            final targetCurrency = state.displayCurrency;
            final defaultCurrency = state.defaultCurrency;
            final periodExpenses = _filterByPeriod(state.expenses);
            if (periodExpenses.isEmpty) {
              return Column(children: [_buildPeriodSelector(), const Expanded(child: Center(child: Text("No entries recorded.", style: TextStyle(fontStyle: FontStyle.italic))))]);
            }
            final filteredExpenses = _selectedCategory == null
                ? periodExpenses
                : periodExpenses.where((e) => e.category == _selectedCategory).toList();
            double totalSum = filteredExpenses.fold(0, (sum, e) => sum + _convert(e.amount, targetCurrency, defaultCurrency));
            return Column(
              children: [
                _buildPeriodSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAD8B1),
                            border: Border.all(color: const Color(0xFF8D7B68), width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(3, 3))],
                          ),
                          child: Column(
                            children: [
                              const Text("DISTRIBUTION OF WEALTH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              const SizedBox(height: 15),
                              SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(touchCallback: (event, res) {
                                      if (event is FlTapUpEvent && res?.touchedSection != null && _selectedCategory == null) {
                                        final index = res!.touchedSection!.touchedSectionIndex;
                                        if (index >= 0) setState(() => _selectedCategory = _getCategoryFromIndex(periodExpenses, targetCurrency, defaultCurrency, index));
                                      }
                                    }),
                                    sections: _selectedCategory == null
                                        ? _generateCategorySections(periodExpenses, targetCurrency, defaultCurrency)
                                        : _generateStoreSections(filteredExpenses, targetCurrency, defaultCurrency),
                                    centerSpaceRadius: 60,
                                    sectionsSpace: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Text("SUM TOTAL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              Text("${totalSum.toStringAsFixed(2)} $targetCurrency", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF432818))),
                              if (_selectedCategory != null)
                                TextButton(onPressed: () => setState(() => _selectedCategory = null), child: const Text("CLOSE FOLDER", style: TextStyle(color: vintageInk, decoration: TextDecoration.underline, fontSize: 10))),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredExpenses.length,
                            itemBuilder: (context, index) {
                              final item = filteredExpenses[index];
                              final color = categoryColors[item.category] ?? Colors.grey;
                              return Container(
                                decoration: const BoxDecoration(border: Border(bottom: vintageBorder)),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(categoryIcons[item.category] ?? Icons.category, color: color),
                                  title: Text(item.storeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text("${item.category} | ${item.date.day}/${item.date.month}"),
                                  trailing: Text("${_convert(item.amount, targetCurrency, defaultCurrency).toStringAsFixed(2)} $targetCurrency", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
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

  Widget _buildPicker({required String label, required String current, required Color vintageInk, required Function(String?) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: vintageInk.withOpacity(0.6))),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current,
              isDense: true,
              icon: Icon(Icons.arrow_drop_down, color: vintageInk, size: 16),
              dropdownColor: const Color(0xFFF4EBD9),
              style: TextStyle(color: vintageInk, fontSize: 11, fontWeight: FontWeight.bold),
              items: _supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFEAD8B1),
        border: Border(bottom: BorderSide(color: Color(0xFF8D7B68), width: 2)),
      ),
      child: Center(
        child: SegmentedButton<StatPeriod>(
          style: SegmentedButton.styleFrom(
            backgroundColor: const Color(0xFFF4EBD9),
            selectedBackgroundColor: const Color(0xFF8D7B68),
            selectedForegroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF8D7B68)),
            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          segments: const [
            ButtonSegment(value: StatPeriod.day, label: Text("DAY")),
            ButtonSegment(value: StatPeriod.month, label: Text("MONTH")),
            ButtonSegment(value: StatPeriod.year, label: Text("YEAR")),
            ButtonSegment(value: StatPeriod.all, label: Text("ALL")),
          ],
          selected: {_selectedPeriod},
          onSelectionChanged: (set) => setState(() { _selectedPeriod = set.first; _selectedCategory = null; }),
        ),
      ),
    );
  }

  List<Expense> _filterByPeriod(List<Expense> expenses) {
    return expenses.where((e) {
      if (_selectedPeriod == StatPeriod.day) return e.date.year == _focusedDate.year && e.date.month == _focusedDate.month && e.date.day == _focusedDate.day;
      if (_selectedPeriod == StatPeriod.month) return e.date.year == _focusedDate.year && e.date.month == _focusedDate.month;
      if (_selectedPeriod == StatPeriod.year) return e.date.year == _focusedDate.year;
      return true;
    }).toList();
  }

  String _getCategoryFromIndex(List<Expense> expenses, String targetCurrency, String defaultCurrency, int index) {
    final Map<String, double> totals = {};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, targetCurrency, defaultCurrency);
    }
    return totals.keys.elementAt(index);
  }

  List<PieChartSectionData> _generateCategorySections(List<Expense> expenses, String targetCurrency, String defaultCurrency) {
    final Map<String, double> totals = {};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + _convert(e.amount, targetCurrency, defaultCurrency);
    }
    return totals.entries.map((entry) => PieChartSectionData(
      color: categoryColors[entry.key] ?? Colors.grey,
      value: entry.value,
      title: entry.key.toUpperCase(),
      radius: 50, showTitle: true,
      titleStyle: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
    )).toList();
  }

  List<PieChartSectionData> _generateStoreSections(List<Expense> expenses, String targetCurrency, String defaultCurrency) {
    final Map<String, double> storeTotals = {};
    for (var e in expenses) {
      storeTotals[e.storeName] = (storeTotals[e.storeName] ?? 0) + _convert(e.amount, targetCurrency, defaultCurrency);
    }
    final colors = [const Color(0xFF432818), const Color(0xFF5E503F), const Color(0xFF22333B), const Color(0xFF4F6D7A)];
    int i = 0;
    return storeTotals.entries.map((entry) => PieChartSectionData(
      color: colors[i++ % colors.length],
      value: entry.value,
      title: entry.key.toUpperCase(),
      radius: 50, showTitle: true,
      titleStyle: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
    )).toList();
  }
}