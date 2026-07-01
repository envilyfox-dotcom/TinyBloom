import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';

// ── Specialists List ──────────────────────────────────────────────
class SpecialistsListScreen extends StatefulWidget {
  const SpecialistsListScreen({super.key});
  @override
  State<SpecialistsListScreen> createState() => _SpecialistsListScreenState();
}

class _SpecialistsListScreenState extends State<SpecialistsListScreen> {
  List<Map<String, dynamic>> _specialists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getSpecialists();

      // Show only timings from 9 AM - 6 PM that have not passed today and
      // are not already booked by another user for the same specialist.
      final withAvailability = await attachAvailableTimingsForToday(data);

      if (mounted) {
        setState(() {
          _specialists = withAvailability;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Specialist Consultation',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const TBLoading()
          : RefreshIndicator(
              color: AppColors.rose,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('Specialist Consultation',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 26)),
                  const SizedBox(height: 4),
                  const Text(
                    "Choose a verified healthcare specialist. Today's remaining timings are shown. You can select another date on the next screen.",
                    style: TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    TBEmptyState(
                        emoji: '⚠️',
                        title: 'Couldn\'t load specialists',
                        subtitle: _error!,
                        buttonLabel: 'Retry',
                        onButton: () {
                          setState(() => _loading = true);
                          _load();
                        })
                  else if (_specialists.isEmpty)
                    const TBEmptyState(
                        emoji: '👩‍⚕️',
                        title: 'No specialists available',
                        subtitle: 'Check back later for verified specialists.')
                  else
                    ..._specialists
                        .map((s) => providerCard(context, s, 'specialist')),
                ],
              ),
            ),
    );
  }
}
