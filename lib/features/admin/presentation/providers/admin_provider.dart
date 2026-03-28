// ============================================================
// admin_provider.dart
// PURPOSE: Riverpod state management for admin dashboard.
//
// FIXED: adminRepositoryProvider now uses the global
// adminRepository singleton instead of creating a new instance
// — prevents duplicate instances + matches project pattern.
//
// State holds:
//   - selectedDate : which day admin is viewing
//   - employees    : list with attendance status for that date
//   - isLoading    : loading indicator flag
//   - error        : error message if fetch fails
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/admin_repository.dart';

// ── AdminState ────────────────────────────────────────────────
class AdminState {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> employees;
  final bool isLoading;
  final String? error;

  const AdminState({
    required this.selectedDate,
    this.employees = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    DateTime? selectedDate,
    List<Map<String, dynamic>>? employees,
    bool? isLoading,
    String? error,
  }) {
    return AdminState(
      selectedDate: selectedDate ?? this.selectedDate,
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      error: error, // WHY no ?? : null clears previous error
    );
  }
}

// ── AdminNotifier ─────────────────────────────────────────────
class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() {
    // WHY microtask: prevents calling async during build()
    // which would cause "setState during build" error
    Future.microtask(() => loadEmployees());
    return AdminState(selectedDate: DateTime.now());
  }

  // ── loadEmployees() ────────────────────────────────────────
  // PURPOSE: Fetch all employees + their attendance for
  // the currently selected date
  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // WHY adminRepository directly: uses global singleton
      // declared at bottom of admin_repository.dart —
      // same pattern as attendanceRepository
      final employees = await adminRepository.fetchEmployeesWithAttendance(
        state.selectedDate,
      );
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load employees: $e',
      );
    }
  }

  // ── changeDate() ───────────────────────────────────────────
  // PURPOSE: Admin picks a different date from date picker
  // → reload attendance data for that date
  Future<void> changeDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await loadEmployees();
  }

  // ── refresh() ──────────────────────────────────────────────
  // PURPOSE: Pull-to-refresh or manual refresh button
  Future<void> refresh() async {
    await loadEmployees();
  }
}

// ── Providers ─────────────────────────────────────────────────

// WHY keep adminRepositoryProvider: some widgets may inject
// repository via provider for easier testing/mocking
final adminRepositoryProvider = Provider<AdminRepository>(
  (_) => adminRepository, // ← uses global singleton, not new instance
);

// WHY NotifierProvider: Riverpod 2.x modern pattern
// StateNotifierProvider is deprecated in Riverpod 2.x
final adminProvider = NotifierProvider<AdminNotifier, AdminState>(
  AdminNotifier.new,
);
