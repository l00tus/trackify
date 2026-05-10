import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../data/expense_api_service.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();
  @override
  List<Object?> get props => [];
}

class LoadExpenses extends ExpenseEvent {
  final String userId;
  const LoadExpenses(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ChangeDisplayCurrency extends ExpenseEvent {
  final String currency;
  const ChangeDisplayCurrency(this.currency);

  @override
  List<Object?> get props => [currency];
}

class ChangeDefaultCurrency extends ExpenseEvent {
  final String currency;
  const ChangeDefaultCurrency(this.currency);

  @override
  List<Object?> get props => [currency];
}

class SyncExpenses extends ExpenseEvent {
  final List<Expense> expenses;
  const SyncExpenses(this.expenses);

  @override
  List<Object?> get props => [expenses];
}

class ProcessReceiptEvent extends ExpenseEvent {
  final dynamic image;
  final dynamic bytes;
  const ProcessReceiptEvent({this.image, this.bytes});

  @override
  List<Object?> get props => [image, bytes];
}

abstract class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object?> get props => [];
}

class ExpenseLoading extends ExpenseState {
  const ExpenseLoading();
}

class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final String displayCurrency;
  final String defaultCurrency;
  final String userId;

  const ExpenseLoaded({
    required this.expenses,
    required this.displayCurrency,
    required this.defaultCurrency,
    required this.userId,
  });

  @override
  List<Object?> get props => [expenses, displayCurrency, defaultCurrency, userId];

  ExpenseLoaded copyWith({
    List<Expense>? expenses,
    String? displayCurrency,
    String? defaultCurrency,
    String? userId,
  }) {
    return ExpenseLoaded(
      expenses: expenses ?? this.expenses,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      userId: userId ?? this.userId,
    );
  }
}

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseApiService apiService;

  ExpenseBloc(this.apiService) : super(const ExpenseLoading()) {
    on<LoadExpenses>((event, emit) async {
      try {
        final results = await Future.wait([
          apiService.fetchExpenses(event.userId),
          apiService.fetchUserCurrency(event.userId),
        ]);

        final expenses = results[0] as List<Expense>;
        final prefCurrency = results[1] as String;

        emit(ExpenseLoaded(
          expenses: expenses,
          userId: event.userId,
          displayCurrency: prefCurrency,
          defaultCurrency: prefCurrency,
        ));
      } catch (e) {
        emit(ExpenseLoaded(
          expenses: [],
          displayCurrency: 'RON',
          defaultCurrency: 'RON',
          userId: event.userId,
        ));
      }
    });

    on<ChangeDisplayCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        emit((state as ExpenseLoaded).copyWith(displayCurrency: event.currency));
      }
    });

    on<ChangeDefaultCurrency>((event, emit) async {
      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        try {
          await apiService.updateUserCurrency(currentState.userId, event.currency);
          emit(currentState.copyWith(
            defaultCurrency: event.currency,
            displayCurrency: event.currency,
          ));
        } catch (e) {}
      }
    });

    on<ProcessReceiptEvent>((event, emit) async {
      if (state is ExpenseLoaded) {
        try {
          Expense newExpense;
          final currentState = state as ExpenseLoaded;

          if (event.bytes != null) {
            newExpense = await apiService.uploadReceiptWeb(currentState.userId, event.bytes);
          } else {
            newExpense = await apiService.uploadReceipt(currentState.userId, event.image);
          }
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