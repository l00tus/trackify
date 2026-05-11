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

class TriggerSilentRefresh extends ExpenseEvent {} // call this when you want to refresh without showing loading spinner

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

  ExpenseBloc({
    required this.apiService,
    required this.socketService,
    required this.localService,
  }) : super(ExpenseLoading()) {

  on<TriggerSilentRefresh>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded;
        final uid = apiService.userId ?? '';
        try {
          final serverExpenses = await apiService.fetchExpenses(uid);
          await localService.replaceAllFromServer(serverExpenses, uid);
          emit(current.copyWith(expenses: serverExpenses));
        } catch (_) {}
      }
    });

  on<LoadExpenses>((event, emit) async {
    final uid = apiService.userId ?? '';

  if (uid.isNotEmpty) {
    socketService.connect(uid, (data) {
      if (data['type'] == 'RECEIPT_PROCESSED') {
        // Trigger a refresh but WITHOUT the loading spinner
        add(TriggerSilentRefresh()); 
      }
    });
  }

      final localExpenses = await localService.getAllExpenses(uid);
      final unsynced = await localService.getUnsyncedExpenses(uid);
      final prefCurrency = await _safeGetCurrency();

      emit(ExpenseLoaded(
        expenses: localExpenses,
        displayCurrency: prefCurrency,
        defaultCurrency: prefCurrency,
        hasPendingSync: unsynced.isNotEmpty,
      ));

      // 4. Try to fetch from server if online
      if (await _isOnline()) {
        try {
          final results = await Future.wait([
            apiService.fetchExpenses(uid), 
            apiService.fetchUserCurrency(uid), 
          ]);

          final serverExpenses = results[0] as List<Expense>;
          final serverCurrency = results[1] as String;

          // Replace local cache with fresh server data
          await localService.replaceAllFromServer(serverExpenses, uid);

          emit(ExpenseLoaded(
            expenses: serverExpenses,
            displayCurrency: serverCurrency,
            defaultCurrency: serverCurrency,
            hasPendingSync: false,
          ));
        } catch (e) {
          // Keep showing local data if server fails
        }
      }
    });

    on<ChangeDisplayCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        emit((state as ExpenseLoaded).copyWith(displayCurrency: event.currency));
      }
    });

    on<AddExpenseLocally>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded;
        
        print("DEBUG: Saving to SQLite locally...");
        await localService.insertExpense(event.expense, isSynced: false);
        
        final updatedList = [event.expense, ...current.expenses];
        emit(current.copyWith(expenses: updatedList, hasPendingSync: true));

        if (await _isOnline()) {
          print("DEBUG: Online. Syncing to backend...");
          try {
            await apiService.syncExpenses([event.expense]);
            await localService.markAllSynced([event.expense.id]);
            print("DEBUG: Sync success.");
            emit((state as ExpenseLoaded).copyWith(hasPendingSync: false));
          } catch (e) {
            print("DEBUG: Sync failed: $e");
          }
        }
      }
    });

    on<ChangeDefaultCurrency>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded; // Fixed 'current' variable
        try {
          await apiService.updateUserCurrency(event.currency, apiService.userId!);
          _playCurrencySound(event.currency);
          
          // FIX: Changed 'currentState' to 'current'
          emit(current.copyWith(
            defaultCurrency: event.currency,
            displayCurrency: event.currency,
          ));
        } catch (_) {}
      }
    });

    on<ProcessReceiptEvent>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded;
        final uid = apiService.userId ?? '';
        try {
          Expense newExpense;
          if (event.bytes != null) {
            newExpense = await apiService.uploadReceiptWeb(event.bytes, apiService.userId!);
          } else {
            newExpense = await apiService.uploadReceipt(event.image, uid);
          }
          
          // Mark as synced since it came from server
          await localService.insertExpense(newExpense, isSynced: true);
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

    on<TriggerSync>((event, emit) async {
      if (state is! ExpenseLoaded) return;
      final uid = apiService.userId ?? '';
      final unsynced = await localService.getUnsyncedExpenses(uid);
      if (unsynced.isNotEmpty && await _isOnline()) {
        try {
          await apiService.syncExpenses(unsynced);
          await localService.markAllSynced(unsynced.map((e) => e.id).toList());
          add(LoadExpenses()); 
        } catch (_) {}
      }
    });
  }

  void _playCurrencySound(String currency) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$currency.mp3'));
    } catch (_) {}
  }

  Future<bool> _isOnline() async {
    final List<ConnectivityResult> result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<String> _safeGetCurrency() async {
    try {
      final uid = apiService.userId ?? '';
      return await apiService.fetchUserCurrency(uid);
    } catch (_) {
      return 'RON';
    }
  }
}