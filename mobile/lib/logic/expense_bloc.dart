import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class TriggerSync extends ExpenseEvent {}

class TriggerSilentRefresh extends ExpenseEvent {}

class ProcessReceiptEvent extends ExpenseEvent {
  final dynamic image;
  final dynamic bytes;
  ProcessReceiptEvent({this.image, this.bytes});
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final String displayCurrency;
  final String defaultCurrency;
  final bool hasPendingSync;

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

// ── BLoC ──────────────────────────────────────────────────────────────────────

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

    // ── Silent refresh (socket-triggered, no spinner) ─────────────────────────
    on<TriggerSilentRefresh>((event, emit) async {
      if (state is! ExpenseLoaded) return;
      final current = state as ExpenseLoaded;
      final uid = apiService.userId ?? '';
      try {
        final serverExpenses = await apiService.fetchExpenses(uid);
        await localService.replaceAllFromServer(serverExpenses, uid);
        emit(current.copyWith(expenses: serverExpenses));
      } catch (_) {}
    });

    // ── Load: sync pending first, then fetch server ───────────────────────────
    //
    // FIX 1 (empty ledger after re-login): we now always try to push any
    // unsynced local items BEFORE replacing the local cache with server data.
    // This prevents offline items being wiped on the first online load.
    //
    // FIX 2 (offline items lost when backend comes back): same root cause —
    // we never wipe local before flushing unsynced items to the server first.
    on<LoadExpenses>((event, emit) async {
      final uid = apiService.userId ?? '';

      // Connect socket if logged in
      if (uid.isNotEmpty) {
        socketService.connect(uid, (data) {
          if (data['type'] == 'RECEIPT_PROCESSED') {
            add(TriggerSilentRefresh());
          }
        });
      }

      // 1. Show local data immediately — no spinner, works offline
      final localExpenses = await localService.getAllExpenses(uid);
      final unsynced = await localService.getUnsyncedExpenses(uid);
      final prefCurrency = await _safeGetCurrency();

      emit(ExpenseLoaded(
        expenses: localExpenses,
        displayCurrency: prefCurrency,
        defaultCurrency: prefCurrency,
        hasPendingSync: unsynced.isNotEmpty,
      ));

      if (await _isOnline()) {
        // 2. Push any pending offline items BEFORE fetching/replacing
        if (unsynced.isNotEmpty) {
          try {
            await apiService.syncExpenses(unsynced);
            await localService.markAllSynced(unsynced.map((e) => e.id).toList());
            print('DEBUG LoadExpenses: flushed ${unsynced.length} offline items');
          } catch (e) {
            print('DEBUG LoadExpenses: offline flush failed: $e');
            // Don't replace local cache if we couldn't flush — keep pending
            return;
          }
        }

        // 3. Now safe to fetch fresh data from server and replace local cache
        try {
          final results = await Future.wait([
            apiService.fetchExpenses(uid),
            apiService.fetchUserCurrency(uid),
          ]);

          final serverExpenses = results[0] as List<Expense>;
          final serverCurrency = results[1] as String;

          await localService.replaceAllFromServer(serverExpenses, uid);

          emit(ExpenseLoaded(
            expenses: serverExpenses,
            displayCurrency: serverCurrency,
            defaultCurrency: serverCurrency,
            hasPendingSync: false,
          ));
        } catch (e) {
          print('DEBUG LoadExpenses: server fetch failed: $e');
          // Stay on local data — already emitted above
        }
      }
    });

    // ── Add expense (offline-safe) ────────────────────────────────────────────
    on<AddExpenseLocally>((event, emit) async {
      if (state is! ExpenseLoaded) return;
      final current = state as ExpenseLoaded;

      // Save locally first, always
      await localService.insertExpense(event.expense, isSynced: false);
      final updatedList = [event.expense, ...current.expenses];
      emit(current.copyWith(expenses: updatedList, hasPendingSync: true));

      // Try to push immediately if online
      if (await _isOnline()) {
        try {
          await apiService.syncExpenses([event.expense]);
          await localService.markAllSynced([event.expense.id]);
          emit((state as ExpenseLoaded).copyWith(hasPendingSync: false));
          print('DEBUG AddExpense: synced immediately');
        } catch (e) {
          print('DEBUG AddExpense: immediate sync failed, stays pending: $e');
          // Stays as is_synced=0, TriggerSync will pick it up later
        }
      }
    });

    // ── TriggerSync (connectivity restored) ───────────────────────────────────
    //
    // FIX 2 continued: push unsynced items, mark them synced, THEN fetch
    // fresh server state. Never wipe before flushing.
    on<TriggerSync>((event, emit) async {
      if (state is! ExpenseLoaded) return;
      final current = state as ExpenseLoaded;
      final uid = apiService.userId ?? '';

      final unsynced = await localService.getUnsyncedExpenses(uid);

      if (unsynced.isEmpty) return;

      if (await _isOnline()) {
        try {
          await apiService.syncExpenses(unsynced);
          await localService.markAllSynced(unsynced.map((e) => e.id).toList());
          print('DEBUG TriggerSync: pushed ${unsynced.length} items');

          // Now fetch fresh list from server
          final serverExpenses = await apiService.fetchExpenses(uid);
          await localService.replaceAllFromServer(serverExpenses, uid);
          emit(current.copyWith(expenses: serverExpenses, hasPendingSync: false));
        } catch (e) {
          print('DEBUG TriggerSync: failed: $e');
          // Stay pending, try again on next connectivity event
        }
      }
    });

    // ── Currency ──────────────────────────────────────────────────────────────
    on<ChangeDisplayCurrency>((event, emit) {
      if (state is ExpenseLoaded) {
        emit((state as ExpenseLoaded).copyWith(displayCurrency: event.currency));
      }
    });

    on<ChangeDefaultCurrency>((event, emit) async {
      if (state is ExpenseLoaded) {
        final current = state as ExpenseLoaded;
        try {
          await apiService.updateUserCurrency(event.currency, apiService.userId!);
          _playCurrencySound(event.currency);
          emit(current.copyWith(
            defaultCurrency: event.currency,
            displayCurrency: event.currency,
          ));
        } catch (_) {}
      }
    });

    // ── Receipt processing ────────────────────────────────────────────────────
    on<ProcessReceiptEvent>((event, emit) async {
      if (state is! ExpenseLoaded) return;
      final current = state as ExpenseLoaded;
      final uid = apiService.userId ?? '';
      try {
        Expense newExpense;
        if (event.bytes != null) {
          newExpense = await apiService.uploadReceiptWeb(event.bytes, apiService.userId!);
        } else {
          newExpense = await apiService.uploadReceipt(event.image, uid);
        }
        // Came from server so already persisted — mark synced
        await localService.insertExpense(newExpense, isSynced: true);
        emit(current.copyWith(expenses: [newExpense, ...current.expenses]));
      } catch (_) {}
    });

    // ── Legacy SyncExpenses (kept for compatibility) ──────────────────────────
    on<SyncExpenses>((event, emit) async {
      if (state is! ExpenseLoaded) return;
      final current = state as ExpenseLoaded;
      try {
        await apiService.syncExpenses(event.expenses);
        emit(current.copyWith(
          expenses: [...current.expenses, ...event.expenses],
        ));
      } catch (_) {}
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
