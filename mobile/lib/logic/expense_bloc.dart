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

class LoadExpenses extends ExpenseEvent {}

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
  const ExpenseLoaded(this.expenses);
  @override
  List<Object?> get props => [expenses];
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
      emit(ExpenseLoading());
      try {
        final expenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(expenses));
      } catch (e) {
        emit(ExpenseError(e.toString()));
      }
    });

    on<ProcessReceipt>((event, emit) async {
      emit(ExpenseLoading());
      try {
        if (event.bytes != null) {
          await apiService.uploadReceiptWeb(event.bytes!);
        } else if (event.image != null) {
          await apiService.uploadReceipt(event.image!);
        }
        final updatedExpenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(updatedExpenses));
      } catch (e) {
        emit(ExpenseError(e.toString()));
      }
    });

    on<SyncExpenses>((event, emit) async {
      emit(ExpenseLoading());
      try {
        await apiService.syncExpenses(event.expenses);
        final updatedExpenses = await apiService.fetchExpenses();
        emit(ExpenseLoaded(updatedExpenses));
      } catch (e) {
        emit(ExpenseError(e.toString()));
      }
    });
  }
}