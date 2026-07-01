import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const AppShell({
    super.key, required this.child, required this.selectedIndex});

  // Mum tabs (unchanged)
  static const _tabs = [
    '/home', '/logs', '/education', '/forum', '/profile'];

  // Specialist tabs (unchanged)
  static const _tabsNonMum = [
    '/home', '/education', '/forum', '/profile'];

  // Volunteer tabs — Home | Services | Consultation | Request | More
  static const _tabsVolunteer = [
    '/home', '/volunteer/services', '/volunteer/sessions', '/volunteer/requests', '/volunteer/more'];

  // Next-of-kin tabs — Home | Logs | Consultation | AI Chatbot | Articles
  static const _tabsNextOfKin = [
    '/home', '/logs', '/consultation', '/chatbot', '/education'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMum = auth.isMum;
    final isVolunteer = auth.isVolunteer;
    final isNextOfKin = auth.isNextOfKin;

    // ── Next-of-kin bottom nav ─────────────────────────────────────
    if (isNextOfKin) {
      return Scaffold(
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => context.go(_tabsNextOfKin[i]),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Logs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Consultation',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'AI Chatbot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Articles',
            ),
          ],
        ),
      );
    }

    // ── Volunteer bottom nav ──────────────────────────────────────
    if (isVolunteer) {
      return Scaffold(
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFE8A0B4),
          unselectedItemColor: const Color(0xFF9B8B86),
          onTap: (i) => context.go(_tabsVolunteer[i]),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_outlined),
              activeIcon: Icon(Icons.medical_services),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Consultation',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox_outlined),
              activeIcon: Icon(Icons.inbox),
              label: 'Request',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              activeIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      );
    }

    // ── Mum / Specialist bottom nav (unchanged) ───────────────────
    final items = [
      const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home'),
      if (isMum)
        const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Logs'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book),
          label: 'Learn'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.forum_outlined),
          activeIcon: Icon(Icons.forum),
          label: 'Forum'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile'),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: items,
        onTap: (i) {
          final routes = isMum ? _tabs : _tabsNonMum;
          context.go(routes[i]);
        },
      ),
    );
  }
}
