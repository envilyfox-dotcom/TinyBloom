import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

// Wraps every logged-in screen with the bottom nav bar. Which tabs show up
// depends on the user's role (mum, volunteer, specialist, next of kin).
class AppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const AppShell({super.key, required this.child, required this.selectedIndex});

  static const _tabs = ['/home', '/logs', '/education', '/forum', '/profile'];

  static const _tabsNonMum = [
    '/home',
    '/specialist/consultations',
    '/education',
    '/forum',
    '/profile'
  ];

  static const _tabsSpecialist = [
    '/home',
    '/specialist/consultations',
    '/education',
    '/specialist/review',
    '/profile'
  ];

  static const _tabsVolunteer = [
    '/home',
    '/volunteer/services',
    '/volunteer/sessions',
    '/volunteer/requests',
    '/volunteer/profile'
  ];

  static const _tabsNextOfKin = [
    '/home',
    '/logs',
    '/education',
    '/forum',
    '/next-of-kin/checklist',
    '/profile'
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // On sign-out, the role clears a frame before GoRouter redirects to
    // /login. If we let the role-less fallback branch render here, it builds
    // a bottom bar with fewer tabs than the still-stale `selectedIndex` this
    // widget was built with (e.g. next-of-kin's Profile tab is index 5) and
    // Flutter throws a BottomNavigationBar assertion for that one frame.
    // Bailing out early avoids it.
    if (!auth.isLoggedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final isMum = auth.isMum;
    final isVolunteer = auth.isVolunteer;
    final isNextOfKin = auth.isNextOfKin;
    final isSpecialist = auth.isSpecialist;

    if (isNextOfKin) {
      return Scaffold(
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
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
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Articles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: 'Forum',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist_outlined),
              activeIcon: Icon(Icons.checklist),
              label: 'Checklist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
    }

    if (isVolunteer) {
      return Scaffold(
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
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
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
    }

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
      if (!isMum)
        const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Consultation'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book),
          label: 'Learn'),
      if (isSpecialist)
        const BottomNavigationBarItem(
            icon: Icon(Icons.rate_review_outlined),
            activeIcon: Icon(Icons.rate_review),
            label: 'Review')
      else
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
          if (isSpecialist) {
            context.go(_tabsSpecialist[i]);
          } else {
            final routes = isMum ? _tabs : _tabsNonMum;
            context.go(routes[i]);
          }
        },
      ),
    );
  }
}
