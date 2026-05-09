import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/expense_bloc.dart';
import '../../models/expense.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trackify Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ExpenseBloc>().add(LoadExpenses()),
          ),
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Fetching your expenses..."),
                ],
              ),
            );
          }

          if (state is ExpenseError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      "Connection Error",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.read<ExpenseBloc>().add(LoadExpenses()),
                      child: const Text("Retry Connection"),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ExpenseLoaded) {
            if (state.expenses.isEmpty) {
              return const Center(
                child: Text("No expenses found. Add one to get started!"),
              );
            }

            return Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _generateSections(state.expenses),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.expenses.length,
                    itemBuilder: (context, index) {
                      final item = state.expenses[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(item.category).withOpacity(0.2),
                          child: Icon(
                            _getCategoryIcon(item.category),
                            color: _getCategoryColor(item.category),
                          ),
                        ),
                        title: Text(item.storeName),
                        subtitle: Text(item.category),
                        trailing: Text(
                          "\$${item.amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text("Welcome to Trackify"));
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Groceries": return Icons.shopping_cart;
      case "Transport": return Icons.directions_car;
      case "Entertainment": return Icons.movie;
      case "Bills": return Icons.receipt_long;
      case "Shopping": return Icons.redeem;
      default: return Icons.help_outline;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Groceries": return Colors.green;
      case "Transport": return Colors.blue;
      case "Entertainment": return Colors.orange;
      case "Bills": return Colors.red;
      case "Shopping": return Colors.purple;
      default: return Colors.grey;
    }
  }

  List<PieChartSectionData> _generateSections(List<Expense> expenses) {
    final Map<String, double> totals = {};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }

    return totals.entries.map((entry) {
      return PieChartSectionData(
        color: _getCategoryColor(entry.key),
        value: entry.value,
        title: entry.key,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}