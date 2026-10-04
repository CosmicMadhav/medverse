import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'records_screen.dart';
import 'compare_screen.dart';
import 'timeline_screen.dart';
import 'profile_screen.dart';
import 'upload_flow.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => MainShellState();

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();
}

class MainShellState extends State<MainShell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeScreen(),
      RecordsScreen(),
      CompareListScreen(),
      TimelineScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      floatingActionButton: index <= 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onPressed: () => showUploadSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('add_record')),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: go,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: context.tr('home')),
            NavigationDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder_rounded),
                label: context.tr('records')),
            NavigationDestination(
                icon: const Icon(Icons.compare_arrows_rounded),
                label: context.tr('compare')),
            NavigationDestination(
                icon: const Icon(Icons.timeline_outlined),
                label: context.tr('timeline')),
            NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: context.tr('profile')),
          ],
        ),
      ),
    );
  }
}
