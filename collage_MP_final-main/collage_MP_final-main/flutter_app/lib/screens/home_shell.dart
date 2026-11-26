import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'hospitals_screen.dart';
import 'settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();

  void _openNewProfile() {
    setState(() => index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileKey.currentState?.createNewProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onAddProfile: _openNewProfile),
      ProfileScreen(key: _profileKey),
      const HospitalsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
          NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined), label: 'Hospitals'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings')
        ],
      ),
    );
  }
}
