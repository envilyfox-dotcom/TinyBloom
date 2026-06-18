import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/auth_provider.dart';
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
      if (mounted) {
        setState(() {
          _specialists = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: !isPremium
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGate(
                  feature: 'Specialist Consultations',
                  onUpgrade: () => context.push('/subscription')),
            )
          : _loading
          ? const TBLoading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('Select Specialist',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                const Text('Choose a healthcare specialist.',
                    style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 20),
                if (_error != null)
                  TBEmptyState(
                      emoji: '⚠️',
                      title: 'Couldn\'t load specialists',
                      subtitle: _error!,
                      buttonLabel: 'Retry',
                      onButton: () { setState(() => _loading = true); _load(); })
                else if (_specialists.isEmpty)
                  const TBEmptyState(
                      emoji: '👩‍⚕️',
                      title: 'No specialists available',
                      subtitle: 'Check back later for available specialists.')
                else
                  ..._specialists
                      .map((s) => providerCard(context, s, 'specialist')),
              ],
            ),
    );
  }
}
