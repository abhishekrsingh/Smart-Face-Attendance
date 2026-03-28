// ============================================================
// app_shell.dart
// PURPOSE: Bottom navigation shell for EMPLOYEE users only.
//
// WHY StatefulNavigationShell (not IndexedStack manually):
// GoRouter's StatefulShellRoute manages state per branch —
// each tab keeps its own navigation stack alive.
// Switching tabs does NOT rebuild the page.
//
// WHY 3 tabs: Home | History | Profile
// Admin gets their own full-screen dashboard (no bottom nav).
//
// Tab index ↔ branch index MUST match exactly:
//   0 → /home
//   1 → /history
//   2 → /profile
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  // WHY navigationShell: provided by StatefulShellRoute —
  // contains current tab index + handles branch switching
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  // ── _onTabTapped() ─────────────────────────────────────────
  // PURPOSE: Switch tab when user taps bottom nav item.
  //
  // WHY goBranch() not context.go(): goBranch() properly
  // restores each branch's navigation stack — context.go()
  // would reset the stack every time.
  //
  // WHY initialLocation: true when tapping current tab →
  // scrolls the tab back to its root (common UX pattern)
  void _onTabTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // WHY navigationShell as body: it renders the current
      // branch's page — GoRouter handles which widget shows
      body: navigationShell,

      bottomNavigationBar: NavigationBar(
        // WHY currentIndex from navigationShell: single source
        // of truth — keeps router state and UI in sync
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabTapped,

        // WHY elevation 0: clean modern look
        elevation: 0,

        // WHY alwaysShow: labels help users identify tabs faster
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,

        destinations: const [
          // Tab 0: Home — mark today's attendance
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),

          // Tab 1: History — view past attendance records
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'History',
          ),

          // Tab 2: Profile — stats, avatar, logout
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
