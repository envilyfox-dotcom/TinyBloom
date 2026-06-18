import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';

// ── Volunteers List ───────────────────────────────────────────────
class VolunteersListScreen extends StatefulWidget {
  const VolunteersListScreen({super.key});
  @override
  State<VolunteersListScreen> createState() => _VolunteersListScreenState();
}

class _VolunteersListScreenState extends State<VolunteersListScreen> {
  List<Map<String, dynamic>> _volunteers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getVolunteers();
      if (mounted) {
        setState(() {
          _volunteers = data;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: _loading
          ? const TBLoading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('Select Volunteer',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                const Text('Choose a volunteer.',
                    style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 20),
                if (_error != null)
                  TBEmptyState(
                      emoji: '⚠️',
                      title: 'Couldn\'t load volunteers',
                      subtitle: _error!,
                      buttonLabel: 'Retry',
                      onButton: () { setState(() => _loading = true); _load(); })
                else if (_volunteers.isEmpty)
                  const TBEmptyState(
                      emoji: '🤝',
                      title: 'No volunteers available',
                      subtitle: 'Check back later for available volunteers.')
                else
                  ..._volunteers
                      .map((v) => providerCard(context, v, 'volunteer')),
              ],
            ),
    );
  }
}
