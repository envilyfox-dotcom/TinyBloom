import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/forgot_password_screen.dart';

import 'volunteer/volunteer_dashboard_screen.dart';
import 'volunteer/volunteer_services_screen.dart';
import 'volunteer/volunteer_sessions_screen.dart';
import 'volunteer/volunteer_requests_screen.dart';
import 'volunteer/volunteer_more_screen.dart';

import 'shared/dashboard_screen.dart';
import 'shared/profile_screen.dart';
import 'shared/edit_profile_screen.dart';
import 'shared/faq_screen.dart';
import 'shared/article_detail_screen.dart';
import 'shared/baby_development_screen.dart';
import 'shared/milestone_journey_screen.dart';
import 'shared/subscription_screen.dart';
import 'shared/notifications_screen.dart';
import 'premium/chatbot_screen.dart';

import 'mum/logs/view_log_screen.dart';
import 'mum/logs/create_log_screen.dart';
import 'mum/consultation/consultation_list_screen.dart';
import 'mum/consultation/consultation_detail_screen.dart';
import 'mum/consultation/specialists_list_screen.dart';
import 'mum/consultation/volunteers_list_screen.dart';
import 'mum/consultation/consultation_booking_screen.dart';
import 'mum/consultation/confirm_consultation_screen.dart';
import 'mum/onboarding/mum_onboarding_screen.dart';
import 'mum/forum/post_detail_screen.dart';

import 'app_shell.dart';

import 'specialist/submit_link_screen.dart';
import 'specialist/specialist_dashboard_screen.dart';
import 'specialist/specialist_profile_screen.dart';
import 'specialist/specialist_edit_profile_screen.dart';
import 'specialist/change_password_screen.dart';


final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: authProvider,
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final loc = state.matchedLocation;
    if (auth.loading) return loc == '/splash' ? null : '/splash';
    final loggedIn = auth.isLoggedIn;
    final onAuth = loc == '/login' || loc == '/forgot-password';
    final onOnboarding = loc == '/onboarding';

    if (!loggedIn && !onAuth) return '/login';
    if (loggedIn && onAuth) return '/home';
    if (loggedIn && auth.needsOnboarding && !onOnboarding) return '/onboarding';
    if (loggedIn && !auth.needsOnboarding && onOnboarding) return '/home';
    if (loc == '/splash') return loggedIn ? '/home' : '/login';
    return null;
  },
  routes: [
    // ── Splash ────────────────────────────────────────────────────
    GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),

    // ── Auth ──────────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(
        path: '/onboarding', builder: (_, __) => const MumOnboardingScreen()),

    // ── Shell (bottom nav) ────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) {
        final location = state.matchedLocation;
        int idx = 0;
        final auth = context.read<AuthProvider>();
        final isMum = auth.isMum;
        final isVolunteer = auth.isVolunteer;

        if (isVolunteer) {
          // Home(0) | Services(1) | Consultation(2) | Request(3) | More(4)
          if (location.startsWith('/volunteer/services'))      idx = 1;
          else if (location.startsWith('/volunteer/sessions')) idx = 2;
          else if (location.startsWith('/volunteer/requests')) idx = 3;
          else if (location.startsWith('/volunteer/more'))     idx = 4;
        } else if (isMum) {
          if (location.startsWith('/logs'))           idx = 1;
          else if (location.startsWith('/education')) idx = 2;
          else if (location.startsWith('/forum'))     idx = 3;
          else if (location.startsWith('/profile'))   idx = 4;
        } else {
          if (location.startsWith('/education'))    idx = 1;
          else if (location.startsWith('/forum'))   idx = 2;
          else if (location.startsWith('/profile')) idx = 3;
        }

        return AppShell(selectedIndex: idx, child: child);
      },
      routes: [
        GoRoute(
            path: '/home',
            builder: (context, __) {
              final auth = context.read<AuthProvider>();
              if (auth.isMum) {
                return const DashboardScreen();
              }
              if (auth.isVolunteer) {
                return const VolunteerDashboardScreen();
              }
              return const SpecialistDashboardScreen();
            }),
        GoRoute(
            path: '/profile',
            builder: (context, __) {
              final auth = context.read<AuthProvider>();
              return auth.isSpecialist
                  ? const SpecialistProfileScreen()
                  : const ProfileScreen();
            }),
        GoRoute(
          path: '/volunteer/services',
          builder: (_, __) => const VolunteerServicesScreen(),
          routes: [
            // Sub-screens pushed on top — back arrow works automatically
            GoRoute(
              path: 'new',
              builder: (_, __) => const ServiceFormScreen(mode: ServiceMode.create),
            ),
          ],
        ),
        GoRoute(
          path: '/volunteer/sessions',
          builder: (_, __) => const VolunteerSessionsScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, __) => const NewVolunteerSessionScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/volunteer/requests',
          builder: (_, __) => const VolunteerRequestsScreen(),
        ),
        GoRoute(
          path: '/volunteer/more',
          builder: (_, __) => const VolunteerMoreScreen(),
        ),
      ],
    ),

    // ── Detail screens (no shell) — unchanged from your original ──
    GoRoute(path: '/logs/create', builder: (_, __) => const CreateLogScreen()),
    GoRoute(
        path: '/logs/:id',
        builder: (context, state) =>
            ViewLogScreen(log: state.extra as Map<String, dynamic>?)),
    GoRoute(
        path: '/logs/:id/edit',
        builder: (context, state) =>
            CreateLogScreen(existing: state.extra as Map<String, dynamic>?)),
    GoRoute(
        path: '/profile/edit',
        builder: (context, state) =>
            EditProfileScreen(profile: state.extra as Map<String, dynamic>?)),
    GoRoute(path: '/faq',     builder: (_, __) => const FaqScreen()),
    GoRoute(path: '/chatbot', builder: (_, __) => const ChatbotScreen()),

    GoRoute(
        path: '/consultation',
        builder: (_, __) => const ConsultationListScreen()),
    GoRoute(
        path: '/consultation/specialists',
        builder: (_, __) => const SpecialistsListScreen()),
    GoRoute(
        path: '/consultation/volunteers',
        builder: (_, __) => const VolunteersListScreen()),

    GoRoute(
        path: '/consultation/book',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ConsultationBookingScreen(
              provider: extra['provider'] as Map<String, dynamic>,
              type: extra['type'] as String);
        }),
    GoRoute(
        path: '/consultation/confirm',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ConfirmConsultationScreen(
              provider: extra['provider'] as Map<String, dynamic>,
              type: extra['type'] as String,
              date: extra['date'] as DateTime,
              time: extra['time'] as String,
              purpose: extra['purpose'] as String);
        }),
    GoRoute(
        path: '/consultation/detail',
        builder: (context, state) => ConsultationDetailScreen(
            consultation: state.extra as Map<String, dynamic>)),
    GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
    GoRoute(
        path: '/education/:id',
        builder: (context, state) => ArticleDetailScreen(
            article: (state.extra as Map<String, dynamic>?) ?? {})),

    GoRoute(
        path: '/baby-development',
        builder: (_, __) => const BabyDevelopmentScreen()),
    GoRoute(
        path: '/milestone-journey',
        builder: (_, __) => const MilestoneJourneyScreen()),
    GoRoute(path: '/submit-link', builder: (_, __) => const SubmitLinkScreen()),

    GoRoute(
        path: '/specialist/edit-profile',
        builder: (context, state) => SpecialistEditProfileScreen(
            specialistProfile: state.extra as Map<String, dynamic>?)),
    GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen()),
    GoRoute(
        path: '/forum/post',
        builder: (context, state) =>
            PostDetailScreen(post: state.extra as Map<String, dynamic>)),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
  ],
);

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE8A0B4))),
    );
  }
}
