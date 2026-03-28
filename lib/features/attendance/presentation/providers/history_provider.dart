// ============================================================
// HistoryProvider
// PURPOSE: Manages state for the Attendance History screen.
// Uses Riverpod 2.x NotifierProvider — StateNotifierProvider
// was removed in Riverpod 2.x, Notifier replaces StateNotifier.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/attendance_repository.dart';
import '../../data/models/attendance_model.dart';

// ------------------------------------------------------------
// HistoryState
// PURPOSE: Immutable state object — holds list of records,
// loading flag, and optional error message.
// ------------------------------------------------------------
class HistoryState {
  final List<AttendanceModel> records; // fetched attendance rows
  final bool isLoading; // true while Supabase query runs
  final String? error; // non-null if fetch failed

  const HistoryState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  // WHY copyWith: Riverpod state must be immutable — never mutate
  // directly, always return a new object with changed fields only
  HistoryState copyWith({
    List<AttendanceModel>? records,
    bool? isLoading,
    String? error,
  }) => HistoryState(
    records: records ?? this.records,
    isLoading: isLoading ?? this.isLoading,
    error: error, // intentionally allows null to clear previous error
  );
}

// ------------------------------------------------------------
// HistoryNotifier
// PURPOSE: Riverpod 2.x Notifier — replaces old StateNotifier.
// build() is required and returns the initial state.
// All methods update state via `state = state.copyWith(...)`.
// ------------------------------------------------------------
class HistoryNotifier extends Notifier<HistoryState> {
  // WHY build(): In Riverpod 2.x, build() replaces the constructor
  // for setting initial state. Called once when provider is first read.
  @override
  HistoryState build() {
    // Auto-load history as soon as provider is created
    Future.microtask(() => loadHistory());
    return const HistoryState(); // initial empty state
  }

  Future<void> loadHistory() async {
    // Show loading spinner while fetching
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch raw List<Map> from Supabase (last 7 days, newest first)
      final raw = await attendanceRepository.getAttendanceHistory();

      // Convert each Map<String,dynamic> → typed AttendanceModel
      final records = raw.map(AttendanceModel.fromMap).toList();

      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      // Keep old records visible, just show error banner
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load history. Please retry.',
      );
    }
  }
}

// ------------------------------------------------------------
// historyProvider
// PURPOSE: Global Riverpod 2.x provider using NotifierProvider.
// WHY NotifierProvider: StateNotifierProvider removed in v2.x.
// Access state:  ref.watch(historyProvider)
// Call methods:  ref.read(historyProvider.notifier).loadHistory()
// ------------------------------------------------------------
final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);
