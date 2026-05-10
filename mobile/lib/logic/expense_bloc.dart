import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

class ProcessReceipt extends ExpenseEvent {
  final File? image;
  final Uint8List? bytes;
  const ProcessReceipt({this.image, this.bytes});
  @override
  List<Object?> get props => [image, bytes];
}

class SyncExpenses extends ExpenseEvent {
  final List<Expense> expenses;
  const SyncExpenses(this.expenses);
  @override
  List<Object?> get props => [expenses];
}

abstract class ExpenseState extends Equatable {
  const ExpenseState();
  @override
  List<Object?> get props => [];
}

class ExpenseInitial extends ExpenseState {}
class ExpenseLoading extends ExpenseState {}
class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final String displayCurrency;
  const ExpenseLoaded(this.expenses, {this.displayCurrency = 'RON'});
  @override
  List<Object?> get props => [expenses, displayCurrency];
}
class ExpenseError extends ExpenseState {
  final String message;
  const ExpenseError(this.message);
  @override
  List<Object?> get props => [message];
}

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseApiService apiService;

  ExpenseBloc(this.apiService) : super(ExpenseInitial()) {
    on<LoadExpenses>((event, emit) async {
      final currentCurrency = state is ExpenseLoaded ? (state as ExpenseLoaded).displayCurrency : 'RON';
      emit(ExpenseLoading());
      try {
        final expenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(expenses, displayCurrency: currentCurrency));
      } catch (e) {
        emit(ExpenseError(e.toString()));
      }
    });

    on<ChangeDisplayCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        emit(ExpenseLoaded(currentState.expenses, displayCurrency: event.currency));
      }
    });

    on<ProcessReceipt>((event, emit) async {
      final currentCurrency = state is ExpenseLoaded ? (state as ExpenseLoaded).displayCurrency : 'RON';
      emit(ExpenseLoading());
      try {
        if (event.bytes != null) {
          await apiService.uploadReceiptWeb(event.bytes!);
        } else if (event.image != null) {
          await apiService.uploadReceipt(event.image!);
        }
        final updatedExpenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(updatedExpenses, displayCurrency: currentCurrency));
      } catch (e) {
        emit(ExpenseError(e.toString()));
      }
    });

    on<SyncExpenses>((event, emit) async {
      final currentCurrency = state is ExpenseLoaded ? (state as ExpenseLoaded).displayCurrency : 'RON';
      emit(ExpenseLoading());
      try {
        await apiService.syncExpenses(event.expenses);
        final updatedExpenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(updatedExpenses, displayCurrency: currentCurrency));
      } catch (e) {
        emit(ExpenseError(e.toString()));
      }
    });
  }
}