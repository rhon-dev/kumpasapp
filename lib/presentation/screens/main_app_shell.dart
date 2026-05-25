import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kumpas/presentation/providers/app_state_provider.dart';
import 'package:kumpas/presentation/screens/home_screen.dart';
import 'package:kumpas/presentation/screens/translate_screen.dart';
import 'package:kumpas/presentation/screens/dictionary_screen.dart';
import 'package:kumpas/presentation/screens/learn_screen.dart';
import 'package:kumpas/presentation/screens/profile_screen.dart';
import 'package:kumpas/theme/app_theme.dart';

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  @override
  void initState() {
    super.initState();
    // Initialize dummy data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().initializeDummyData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        return Scaffold(
          body: _buildPages()[appState.currentTabIndex],
          bottomNavigationBar: _buildBottomNavigation(context, appState),
        );
      },
    );
  }

  List<Widget> _buildPages() {
    return [
      const HomeScreen(),
      const TranslateScreen(),
      const DictionaryScreen(),
      const LearnScreen(),
      const ProfileScreen(),
    ];
  }

  Widget _buildBottomNavigation(
      BuildContext context, AppStateProvider appState) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: appState.currentTabIndex,
        onTap: (index) {
          appState.selectTab(index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 24),
            activeIcon: Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.g_translate_outlined, size: 24),
            activeIcon: Icon(Icons.g_translate, size: 24),
            label: 'Translate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined, size: 24),
            activeIcon: Icon(Icons.menu_book, size: 24),
            label: 'Dictionary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined, size: 24),
            activeIcon: Icon(Icons.school, size: 24),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined, size: 24),
            activeIcon: Icon(Icons.person, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
