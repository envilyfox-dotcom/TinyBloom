import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

// ── Bottom Nav Shell ──────────────────────────────────────────────
class AppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const AppShell({
    super.key, required this.child, required this.selectedIndex});

  static const _tabs = [
    '/home', '/logs', '/education', '/forum', '/profile'];
  static const _tabsNonMum = [
    '/home', '/education', '/forum', '/profile'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMum = auth.isMum;

    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home),
        label: 'Home'),
      if (isMum) const BottomNavigationBarItem(
        icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite),
        label: 'Logs'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book),
        label: 'Learn'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.forum_outlined), activeIcon: Icon(Icons.forum),
        label: 'Forum'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person),
        label: 'Profile'),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        items: items,
        onTap: (i) {
          final routes = isMum ? _tabs : _tabsNonMum;
          context.go(routes[i]);
        },
      ),
    );
  }
}
