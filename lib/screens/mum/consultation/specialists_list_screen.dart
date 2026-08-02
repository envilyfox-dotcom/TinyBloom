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
  String? _selectedSpecialization;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get _specializations {
    final values = _specialists
        .map((s) => (s['specialization'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  double _specializationFilterWidth(BuildContext context) {
    const style = TextStyle(fontSize: 13);
    double longest = 0;
    for (final label in ['All specializations', ..._specializations]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > longest) longest = painter.width;
    }
    // Room for the leading icon, trailing arrow and the field's own padding.
    const chrome = 18 + 12 + 24 + 24;
    // Cap it well short of the screen edge so long specialization names
    // (e.g. "Maternal-Fetal Medicine (Perinatologist)") don't force the
    // filter to stretch across the whole page — they just wrap onto a
    // second line inside the menu instead.
    final maxAllowed = MediaQuery.of(context).size.width - 40;
    return (longest + chrome).clamp(160.0, maxAllowed.clamp(160.0, 260.0));
  }

  List<Map<String, dynamic>> get _filteredSpecialists {
    if (_selectedSpecialization == null) return _specialists;
    return _specialists
        .where((s) => s['specialization'] == _selectedSpecialization)
        .toList();
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
    final isPremium = context.watch<AuthProvider>().isPremium;
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/consultation');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => backOrToHub(context),
          ),
          title: const Text(
            'Specialist Consultation',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: !isPremium
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: PremiumGate(
                  feature: 'Specialist Consultations',
                  onUpgrade: () => context.push('/subscription'),
                ),
              )
            : _loading
                ? const TBLoading()
                : RefreshIndicator(
                    color: AppColors.rose,
                    onRefresh: _load,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                if (_specializations.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: DropdownMenu<String?>(
                                      initialSelection: _selectedSpecialization,
                                      width:
                                          _specializationFilterWidth(context),
                                      menuHeight: 320,
                                      enableSearch: false,
                                      requestFocusOnTap: false,
                                      textStyle: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 13,
                                      ),
                                      leadingIcon: const Icon(
                                        Icons.filter_list,
                                        color: AppColors.textMid,
                                        size: 18,
                                      ),
                                      label: const Text(
                                          'Filter by specialization',
                                          style: TextStyle(fontSize: 12)),
                                      inputDecorationTheme:
                                          InputDecorationTheme(
                                        isDense: true,
                                        filled: true,
                                        fillColor: AppColors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: AppColors.textLight
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: AppColors.textLight
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.rose,
                                              width: 1.5),
                                        ),
                                      ),
                                      menuStyle: MenuStyle(
                                        backgroundColor:
                                            const WidgetStatePropertyAll(
                                                AppColors.white),
                                        elevation:
                                            const WidgetStatePropertyAll(4),
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: BorderSide(
                                                color: AppColors.textLight
                                                    .withValues(alpha: 0.3)),
                                          ),
                                        ),
                                      ),
                                      onSelected: (v) => setState(
                                          () => _selectedSpecialization = v),
                                      dropdownMenuEntries: [
                                        const DropdownMenuEntry<String?>(
                                          value: null,
                                          label: 'All specializations',
                                        ),
                                        ..._specializations.map(
                                          (s) => DropdownMenuEntry<String?>(
                                            value: s,
                                            label: s,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: _error != null
                              ? SliverToBoxAdapter(
                                  child: TBEmptyState(
                                      emoji: '⚠️',
                                      title: 'Couldn\'t load specialists',
                                      subtitle: _error!,
                                      buttonLabel: 'Retry',
                                      onButton: () {
                                        setState(() => _loading = true);
                                        _load();
                                      }))
                              : _filteredSpecialists.isEmpty
                                  ? SliverToBoxAdapter(
                                      child: TBEmptyState(
                                          emoji: '👩‍⚕️',
                                          title: _specialists.isEmpty
                                              ? 'No specialists available'
                                              : 'No specialists in this specialization',
                                          subtitle: _specialists.isEmpty
                                              ? 'Check back later for verified specialists.'
                                              : 'Try selecting a different specialization.'))
                                  : SliverList.builder(
                                      itemCount: _filteredSpecialists.length,
                                      itemBuilder: (context, i) => providerCard(
                                          context,
                                          _filteredSpecialists[i],
                                          'specialist'),
                                    ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
