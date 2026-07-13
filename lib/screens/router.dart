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
import 'volunteer/volunteer_mums_helped_screen.dart';
import 'volunteer/volunteer_profile_screen.dart';
import 'volunteer/volunteer_edit_profile_screen.dart';
import 'next_of_kin/next_of_kin_dashboard_screen.dart';
import 'next_of_kin/link_to_mum_screen.dart';
import 'next_of_kin/gift_subscription_screen.dart';
import 'next_of_kin/next_of_kin_faq_screen.dart';
import 'next_of_kin/checklist_screen.dart';
import 'next_of_kin/chat_volunteer_screen.dart';

import 'shared/dashboard_screen.dart';
import 'mum/logs/logs_screen.dart';
import 'mum/logs/view_log_screen.dart';
import 'mum/logs/create_log_screen.dart';
import 'shared/profile_screen.dart';
import 'shared/edit_profile_screen.dart';
import 'shared/faq_screen.dart';
import 'shared/education_screen.dart';
import 'shared/article_detail_screen.dart';
import 'shared/baby_development_screen.dart';
import 'shared/milestone_journey_screen.dart';
import 'shared/subscription_screen.dart';
import 'premium/chatbot_screen.dart';
import 'mum/consultation/consultation_list_screen.dart';
import 'mum/consultation/consultation_detail_screen.dart';
import 'mum/consultation/specialists_list_screen.dart';
import 'mum/consultation/volunteers_list_screen.dart';
import 'mum/consultation/consultation_booking_screen.dart';
import 'mum/consultation/confirm_consultation_screen.dart';
import 'mum/consultation/post_volunteer_question_screen.dart';
import 'mum/consultation/volunteer_question_detail_screen.dart';
import 'app_shell.dart';
import 'mum/onboarding/mum_onboarding_screen.dart';
import 'specialist/specialist_dashboard_screen.dart';
import 'specialist/specialist_profile_screen.dart';
import 'specialist/specialist_edit_profile_screen.dart';
import 'specialist/specialist_consultations_screen.dart';
import 'specialist/change_password_screen.dart';
import 'specialist/specialist_consultation_detail_screen.dart';
import 'specialist/specialist_learn_screen.dart';
import 'specialist/specialist_create_article_screen.dart';
import 'specialist/specialist_edit_article_screen.dart';
import 'specialist/specialist_review_screen.dart';
import 'specialist/specialist_review_thread_screen.dart';

import 'mum/forum/forum_screen.dart';
import 'mum/forum/post_detail_screen.dart';
import 'shared/notifications_screen.dart';

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
        final isNextOfKin = auth.isNextOfKin;

        if (isVolunteer) {
          // Home(0) | Services(1) | Consultation(2) | Request(3) | Profile(4)
          if (location.startsWith('/volunteer/services')) {
            idx = 1;
          } else if (location.startsWith('/volunteer/sessions'))
            idx = 2;
          else if (location.startsWith('/volunteer/requests'))
            idx = 3;
          else if (location.startsWith('/volunteer/profile')) idx = 4;
        } else if (isNextOfKin) {
          // Home(0) | Logs(1) | Consultation(2) | Articles(3) | Checklist(4) | Profile(5)
          if (location.startsWith('/logs')) {
            idx = 1;
          } else if (location.startsWith('/consultation'))
            idx = 2;
          else if (location.startsWith('/education'))
            idx = 3;
          else if (location.startsWith('/next-of-kin/checklist'))
            idx = 4;
          else if (location.startsWith('/profile')) idx = 5;
        } else if (isMum) {
          if (location.startsWith('/logs')) {
            idx = 1;
          } else if (location.startsWith('/education'))
            idx = 2;
          else if (location.startsWith('/forum'))
            idx = 3;
          else if (location.startsWith('/profile')) idx = 4;
        } else {
          // Specialist: Home(0) | Consultation(1) | Learn(2) | Review(3) | Profile(4)
          if (location.startsWith('/specialist/consultations')) {
            idx = 1;
          } else if (location.startsWith('/education'))
            idx = 2;
          else if (location.startsWith('/specialist/review'))
            idx = 3;
          else if (location.startsWith('/profile')) idx = 4;
        }

        return AppShell(selectedIndex: idx, child: child);
      },
      routes: [
        // ── Shared home (role-based) ───────────────────────────
        GoRoute(
            path: '/home',
            builder: (context, __) {
              final auth = context.read<AuthProvider>();
              if (auth.isMum) return const DashboardScreen();
              if (auth.isVolunteer) return const VolunteerDashboardScreen();
              if (auth.isNextOfKin) return const NextOfKinDashboardScreen();
              return const SpecialistDashboardScreen();
            }),

        // ── Mum / Specialist tabs ──────────────────────────────
        GoRoute(
            path: '/profile',
            builder: (context, __) {
              final auth = context.read<AuthProvider>();
              if (auth.role == 'specialist') {
                return const SpecialistProfileScreen();
              }
              return const ProfileScreen();
            }),
        GoRoute(
            path: '/education',
            builder: (context, __) {
              final auth = context.read<AuthProvider>();
              if (auth.isSpecialist) return const SpecialistLearnScreen();
              return const EducationScreen();
            }),
        GoRoute(path: '/logs', builder: (_, __) => const LogsScreen()),
        GoRoute(path: '/forum', builder: (_, __) => const ForumScreen()),
        GoRoute(
            path: '/next-of-kin/checklist',
            builder: (_, __) => const NextOfKinChecklistScreen()),
        GoRoute(
            path: '/specialist/consultations',
            builder: (_, __) => const SpecialistConsultationsScreen()),
        GoRoute(
            path: '/specialist/review',
            builder: (_, __) => const SpecialistReviewScreen()),

        // ── Volunteer main tabs (INSIDE ShellRoute so back works) ──
        GoRoute(
          path: '/volunteer/services',
          builder: (_, __) => const VolunteerServicesScreen(),
          routes: [
            // Sub-screens pushed on top — back arrow works automatically
            GoRoute(
              path: 'new',
              builder: (_, __) =>
                  const ServiceFormScreen(mode: ServiceMode.create),
            ),
          ],
        ),
        GoRoute(
          path: '/volunteer/sessions',
          builder: (_, state) {
            final extra = state.extra;
            final completedOnly =
                extra is Map && extra['completedOnly'] == true;
            final initialTab = extra is int ? extra : 0;
            return VolunteerSessionsScreen(
                initialTab: initialTab, completedOnly: completedOnly);
          },
        ),
        GoRoute(
          path: '/volunteer/requests',
          builder: (_, __) => const VolunteerRequestsScreen(),
        ),
        GoRoute(
          path: '/volunteer/mums-helped',
          builder: (_, __) => const VolunteerMumsHelpedScreen(),
        ),
        GoRoute(
          path: '/volunteer/profile',
          builder: (_, __) => const VolunteerProfileScreen(),
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
    GoRoute(path: '/faq', builder: (_, __) => const FaqScreen()),
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
        path: '/ask-volunteer',
        builder: (_, __) => const PostVolunteerQuestionScreen()),
    GoRoute(
        path: '/ask-volunteer/detail',
        builder: (context, state) => VolunteerQuestionDetailScreen(
            request: state.extra as Map<String, dynamic>)),

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
        builder: (context, state) {
          final auth = context.read<AuthProvider>();
          final consultation = state.extra as Map<String, dynamic>;
          if (auth.isSpecialist) {
            return SpecialistConsultationDetailScreen(
                consultation: consultation);
          }
          return ConsultationDetailScreen(consultation: consultation);
        }),
    GoRoute(
        path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
    GoRoute(
        path: '/education/:id',
        builder: (context, state) => ArticleDetailScreen(
            article: (state.extra as Map<String, dynamic>?) ?? {})),

    GoRoute(
        path: '/baby-development',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BabyDevelopmentScreen(
            patientUserId: extra?['userId'] as String?,
            patientName: extra?['name'] as String?,
          );
        }),
    GoRoute(
        path: '/milestone-journey',
        builder: (_, __) => const MilestoneJourneyScreen()),
    GoRoute(
        path: '/specialist/create-article',
        builder: (_, __) => const SpecialistCreateArticleScreen()),
    GoRoute(
        path: '/specialist/edit-article',
        builder: (context, state) => SpecialistEditArticleScreen(
            article: state.extra as Map<String, dynamic>)),
    GoRoute(
        path: '/specialist/review/thread',
        builder: (context, state) => SpecialistReviewThreadScreen(
            contentId: state.extra as String)),

    GoRoute(
        path: '/specialist/edit-profile',
        builder: (context, state) => SpecialistEditProfileScreen(
            specialistProfile: state.extra as Map<String, dynamic>?)),
    GoRoute(
        path: '/volunteer/edit-profile',
        builder: (context, state) => VolunteerEditProfileScreen(
            profile: state.extra as Map<String, dynamic>?)),
    GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen()),
    GoRoute(
        path: '/next-of-kin/link', builder: (_, __) => const LinkToMumScreen()),
    GoRoute(
        path: '/next-of-kin/gift-subscription',
        builder: (_, __) => const GiftSubscriptionScreen()),
    GoRoute(
        path: '/next-of-kin/faq',
        builder: (_, __) => const NextOfKinFaqScreen()),
    GoRoute(
        path: '/next-of-kin/chat-volunteer',
        builder: (_, __) => const ChatVolunteerScreen()),
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
