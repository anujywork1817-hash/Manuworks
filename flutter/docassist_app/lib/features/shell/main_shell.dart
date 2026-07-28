import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationToIndex(String loc) {
    if (loc.startsWith('/documents')) return 1;
    if (loc.startsWith('/ai-chat'))   return 2;
    if (loc.startsWith('/matters'))   return 3;
    if (loc.startsWith('/profile'))   return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(AppRoutes.dashboard); break;
      case 1: context.go(AppRoutes.documents);  break;
      case 2: context.go(AppRoutes.aiChat);     break;
      case 3: context.go(AppRoutes.matters);    break;
      case 4: context.go(AppRoutes.profile);    break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index    = _locationToIndex(location);
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    // Handle the Android system back button / back-swipe. Tabs are switched with
    // context.go() (which replaces the stack), so without this a back press on any
    // non-Home tab has nothing to pop and would exit the app to the phone home
    // screen. Intercept every back and route it sensibly:
    //   • a pushed sub-screen is on top  → pop it
    //   • a non-Home tab root            → go to the Home tab
    //   • the Home tab root              → leave the app
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else if (index != 0) {
          context.go(AppRoutes.dashboard);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline, width: 0.8)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => _onTap(context, i),
            backgroundColor: cs.surface,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: isDark
                ? cs.primaryContainer
                : cs.primaryContainer,
            height: 60,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Docs',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'AI Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.cases_outlined),
                selectedIcon: Icon(Icons.cases_rounded),
                label: 'Matters',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
