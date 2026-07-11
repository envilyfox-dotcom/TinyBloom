import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../shared/education_screen.dart';

// ── Learn tab (Specialists) ─────────────────────────────────────────────
// Wraps the shared EducationScreen (unchanged, used by Mum/Next-of-kin too)
// with a "+" FAB so specialists can start a new article submission, mirroring
// the Forum tab's create-post FAB.
class SpecialistLearnScreen extends StatelessWidget {
  const SpecialistLearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const EducationScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/specialist/create-article'),
        backgroundColor: AppColors.rose,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
