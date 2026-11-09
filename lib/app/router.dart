import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/history/history_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/session/session_screen.dart';
import '../features/summary/summary_screen.dart';
import '../features/breathing/breathing_screen.dart';
import 'consent.dart';
import '../features/consent/consent_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: consentNotifier,
  redirect: (context, state) {
    final ok = consentNotifier.value;
    final atConsent = state.matchedLocation == '/consent';
    if (!ok && !atConsent) return '/consent';
    if (ok && atConsent) return '/';
    return null;
  },
  routes: [
    ShellRoute(
      builder: (c, s, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
        GoRoute(path: '/insights', builder: (c, s) => const InsightsScreen()),
        GoRoute(path: '/journal', builder: (c, s) => const JournalScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      ],
    ),
    GoRoute(path: '/setup', builder: (c, s) => const SetupScreen()),
    GoRoute(path: '/consent', builder: (c, s) => const ConsentScreen()),
    GoRoute(path: '/session', builder: (c, s) => const SessionScreen()),
    GoRoute(path: '/summary', builder: (c, s) => const SummaryScreen()),
    GoRoute(path: '/breathing', builder: (c, s) => const BreathingScreen()),
  ],
);

const _tabs = ['/', '/history', '/insights', '/journal', '/settings'];

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _tabs.indexOf(loc).clamp(0, 4);
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'History'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}