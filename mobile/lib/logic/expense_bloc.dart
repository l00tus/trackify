import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../data/expense_api_service.dart';
import '../data/socket_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data/expense_local_service.dart';

abstract class ExpenseEvent {}

class LoadExpenses extends ExpenseEvent {}

class AddExpenseLocally extends ExpenseEvent {
  final Expense expense;
  AddExpenseLocally(this.expense);
}

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

class TriggerSync extends ExpenseEvent {} // call this on connectivity restore

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
  final bool hasPendingSync; // new: shows a sync badge in UI if you want

  ExpenseLoaded({
    required this.expenses,
    required this.displayCurrency,
    required this.defaultCurrency,
    this.hasPendingSync = false,
  });

  ExpenseLoaded copyWith({
    List<Expense>? expenses,
    String? displayCurrency,
    String? defaultCurrency,
    bool? hasPendingSync,
  }) {
    return ExpenseLoaded(
      expenses: expenses ?? this.expenses,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
    );
  }
}


class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseApiService apiService;
  final SocketService socketService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ExpenseLocalService localService;
  // final String userId; // pass in from auth after login

  ExpenseBloc({
    required this.apiService,
    required this.socketService,
    required this.localService,
  }) : super(ExpenseLoading()) {


    on<LoadExpenses>((event, emit) async {
      final uid = apiService.userId ?? '';

      // Initialize WebSocket connection when expenses are loaded
      if (uid.isNotEmpty) {
        socketService.connect(uid, (data) {
          if (data['type'] == 'RECEIPT_PROCESSED') {
            add(LoadExpenses()); // Auto-refresh the list
          }
        });
      }
            final unsynced = await localService.getUnsyncedExpenses(uid);
      

      try {
        final results = await Future.wait([
          apiService.fetchExpenses(),
          apiService.fetchUserCurrency(),
        ]);

        final expenses = results[0] as List<Expense>;
        final prefCurrency = results[1] as String;

        emit(ExpenseLoaded(
          expenses: expenses,
          displayCurrency: prefCurrency,
          defaultCurrency: prefCurrency,
        ));
      } catch (e) {
        emit(ExpenseLoaded(expenses: [], displayCurrency: "RON", defaultCurrency: "RON"));
      }
    });

    on<ChangeDisplayCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        emit((state as ExpenseLoaded).copyWith(displayCurrency: event.currency));
      }
    });

    on<ChangeDefaultCurrency>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded;
        try {
          await apiService.updateUserCurrency(event.currency);
          _playCurrencySound(event.currency);
          emit(currentState.copyWith(
            defaultCurrency: event.currency,
            displayCurrency: event.currency,
          ));
        } catch (_) {}
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
          // Receipt came from server so mark as synced
          await localService.insertExpense(newExpense, isSynced: true);
          final current = state as ExpenseLoaded;
          emit(current.copyWith(expenses: [newExpense, ...current.expenses]));
        } catch (_) {}
      }
    });

    on<SyncExpenses>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded;
        try {
          await apiService.syncExpenses(event.expenses);
          emit(current.copyWith(
            expenses: [...current.expenses, ...event.expenses],
          ));
        } catch (_) {}
      }
    });
  }

  void _playCurrencySound(String currency) async {
    await _audioPlayer.play(AssetSource('sounds/$currency.mp3'));
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<String> _safeGetCurrency() async {
    try {
      return await apiService.fetchUserCurrency();
    } catch (_) {
      return 'RON';
    }
  }
}