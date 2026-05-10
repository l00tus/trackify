import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/expense.dart';
import '../data/expense_api_service.dart';

abstract class ExpenseEvent {}

class LoadExpenses extends ExpenseEvent {}

class ChangeDisplayCurrency extends ExpenseEvent {
  final String currency;
  ChangeDisplayCurrency(this.currency);
}

class ChangeDefaultCurrency extends ExpenseEvent {
  final String currency;
  ChangeDefaultCurrency(this.currency);
}

class SyncExpenses extends ExpenseEvent {
  final List<Expense> expenses;
  SyncExpenses(this.expenses);
}

class ProcessReceiptEvent extends ExpenseEvent {
  final dynamic image;
  final dynamic bytes;
  ProcessReceiptEvent({this.image, this.bytes});
}

abstract class ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final String displayCurrency;
  final String defaultCurrency;

  ExpenseLoaded({
    required this.expenses,
    this.displayCurrency = "RON",
    this.defaultCurrency = "RON",
  });

  ExpenseLoaded copyWith({
    List<Expense>? expenses,
    String? displayCurrency,
    String? defaultCurrency,
  }) {
    return ExpenseLoaded(
      expenses: expenses ?? this.expenses,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    );
  }
}

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseApiService apiService;

  ExpenseBloc(this.apiService) : super(ExpenseLoading()) {
    on<LoadExpenses>((event, emit) async {
      try {
        final expenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(expenses: expenses));
      } catch (e) {
        emit(ExpenseLoaded(expenses: []));
      }
    });

    on<ChangeDisplayCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        emit((state as ExpenseLoaded).copyWith(displayCurrency: event.currency));
      }
    });

    on<ChangeDefaultCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        emit((state as ExpenseLoaded).copyWith(defaultCurrency: event.currency));
      }
    });

    on<ProcessReceiptEvent>((event, emit) async {
      if (state is ExpenseLoaded) {
        try {
          Expense newExpense;
          if (event.bytes != null) {
            newExpense = await apiService.uploadReceiptWeb(event.bytes);
          } else {
            newExpense = await apiService.uploadReceipt(event.image);
          }
          final currentState = state as ExpenseLoaded;
          emit(currentState.copyWith(expenses: [newExpense, ...currentState.expenses]));
        } catch (e) {}
      }
    });

    on<SyncExpenses>((event, emit) async {
      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        try {
          await apiService.syncExpenses(event.expenses);
          emit(currentState.copyWith(
              expenses: [...currentState.expenses, ...event.expenses]
          ));
        } catch (e) {}
      }
    });
  }
}