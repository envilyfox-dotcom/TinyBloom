import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/auth_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';

// ── Consultation List Screen ──────────────────────────────────────
class ConsultationListScreen extends StatefulWidget {
  // Lets a caller deep-link straight into a pre-filtered view — e.g. the
  // next-of-kin dashboard's message icon jumps here with just
  // {'Volunteer Chats'} selected, instead of landing on the unfiltered list.
  final Set<String>? initialTypeFilters;
  const ConsultationListScreen({super.key, this.initialTypeFilters});
  @override
  State<ConsultationListScreen> createState() => _ConsultationListScreenState();
}

class _ConsultationListScreenState extends State<ConsultationListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _consultations = [];
  bool _loading = true;
  // Next-of-kin can only view the linked mum's consultations — booking is
  // her own action, so the "Book New" tab and any booking CTA are hidden.
  bool _isNextOfKin = false;

  static const _filterOptions = [
    'All',
    'Pending',
    'Confirmed',
    'Ongoing',
    'Completed',
    'Cancelled',
  ];
  static const _providerOptions = ['Specialist', 'Volunteer'];
  String _selectedFilter = 'All';
  Set<String> _selectedProviders = _providerOptions.toSet();

  // Next-of-kin's simpler type filter — a chip row instead of the Filter
  // sheet, since their tabs already split by status (active vs history).
  // Multi-select: Pending, Confirmed, and Volunteer Chats can each be
  // toggled independently, so "just pending", "just confirmed", or "both"
  // are all reachable. Empty selection means no filter (show everything).
  static const _typeFilterOptions = ['Pending', 'Confirmed', 'Volunteer Chats'];
  final Set<String> _selectedTypeFilters = {};

  @override
  void initState() {
    super.initState();
    _isNextOfKin = context.read<AuthProvider>().isNextOfKin;
    // Both roles get 2 tabs now: mum sees My Consultations + Book New;
    // next-of-kin sees My Consultations (active) + History (past).
    _tabs = TabController(length: 2, vsync: this);
    if (widget.initialTypeFilters != null) {
      _selectedTypeFilters.addAll(widget.initialTypeFilters!);
    }
    _load();
  }

  String? _error;

  // Normalises a consultation row or volunteer question into one shared
  // status bucket so a single filter row can cover both sources.
  String _itemCategory(Map<String, dynamic> item) {
    final status = (item['status'] as String? ?? 'pending').toLowerCase();
    if (item['_kind'] == 'question') {
      return status == 'closed' ? 'completed' : 'ongoing';
    }
    switch (status) {
      case 'confirmed':
        return 'confirmed';
      case 'completed':
        return 'completed';
      case 'cancelled':
      case 'expired':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  // A volunteer question ('_kind' == 'question') came from the open Q&A
  // board; everything else in the merged list is a specialist consultation
  // booking (volunteer bookings were already filtered out in _load).
  String _providerCategory(Map<String, dynamic> item) =>
      item['_kind'] == 'question' ? 'Volunteer' : 'Specialist';

  List<Map<String, dynamic>> get _filteredConsultations {
    final category = _selectedFilter.toLowerCase();
    return _consultations.where((c) {
      final matchesStatus =
          _selectedFilter == 'All' || _itemCategory(c) == category;
      final matchesProvider = _selectedProviders.contains(_providerCategory(c));
      return matchesStatus && matchesProvider;
    }).toList();
  }

  // Next-of-kin's two tabs split by status instead of using the Filter
  // sheet (that stays mum-only): active items now, history once resolved.
  bool _isHistoryItem(Map<String, dynamic> item) {
    final category = _itemCategory(item);
    return category == 'completed' || category == 'cancelled';
  }

  bool _matchesTypeFilter(Map<String, dynamic> item) {
    if (_selectedTypeFilters.isEmpty) return true;
    if (_providerCategory(item) == 'Volunteer') {
      return _selectedTypeFilters.contains('Volunteer Chats');
    }
    final status = _itemCategory(item); // 'pending' or 'confirmed' here
    if (status == 'pending') return _selectedTypeFilters.contains('Pending');
    if (status == 'confirmed') {
      return _selectedTypeFilters.contains('Confirmed');
    }
    // Completed/cancelled consultations only ever show up in the History
    // tab, which Pending/Confirmed/Volunteer Chats never match — correct,
    // since none of those describe a resolved item.
    return false;
  }

  List<Map<String, dynamic>> get _activeConsultations => _consultations
      .where((c) => !_isHistoryItem(c) && _matchesTypeFilter(c))
      .toList();

  List<Map<String, dynamic>> get _historyConsultations => _consultations
      .where((c) => _isHistoryItem(c) && _matchesTypeFilter(c))
      .toList();

  Future<void> _load() async {
    try {
      List<Map<String, dynamic>> c;
      if (_isNextOfKin) {
        // Next-of-kin doesn't book consultations themselves — the real
        // data is the linked mum's own consultations.
        final linkedMum = await SupabaseService.getLinkedMum();
        c = linkedMum != null
            ? await SupabaseService.getConsultationsForPatient(
                linkedMum['id'] as String)
            : <Map<String, dynamic>>[];
      } else {
        c = await SupabaseService.getConsultations();
      }
      List<Map<String, dynamic>> questions = [];
      try {
        questions = await SupabaseService.getMyVolunteerQuestions();
      } catch (_) {}

      // Volunteer bookings are a leftover from before the volunteer flow was
      // replaced by the open Q&A board — volunteer interactions now show up
      // as question cards instead, so drop the old booking rows here.
      final merged = <Map<String, dynamic>>[
        ...c.where((r) => r['consultation_type'] != 'volunteer'),
        ...questions.map((q) => {...q, '_kind': 'question'}),
      ];
      // Fall back to epoch (not "equal") for unparseable dates so a bad/missing
      // created_at can never bump an item out of proper chronological order.
      merged.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _consultations = merged;
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

  bool get _hasActiveFilter =>
      _selectedFilter != 'All' ||
      _selectedProviders.length < _providerOptions.length;

  Future<void> _showFilterSheet() async {
    var draftFilter = _selectedFilter;
    var draftProviders = Set<String>.from(_selectedProviders);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filter Consultations',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 16),
                      const Text('Status',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filterOptions.map((option) {
                          final selected = draftFilter == option;
                          return ChoiceChip(
                            label: Text(option),
                            selected: selected,
                            onSelected: (_) =>
                                setSheetState(() => draftFilter = option),
                            showCheckmark: false,
                            selectedColor: AppColors.teal,
                            backgroundColor: AppColors.tealLight,
                            side: BorderSide(
                                color: selected
                                    ? Colors.transparent
                                    : AppColors.textLight
                                        .withValues(alpha: 0.3)),
                            labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textDark),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Provider',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Leave both unchecked to see everything.',
                          style: TextStyle(
                              color: AppColors.textMid, fontSize: 12)),
                      ..._providerOptions.map((option) {
                        return CheckboxListTile(
                          value: draftProviders.contains(option),
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                draftProviders.add(option);
                              } else {
                                draftProviders.remove(option);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.teal,
                          title: Text(option,
                              style: const TextStyle(fontSize: 14)),
                        );
                      }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedFilter = draftFilter;
                              _selectedProviders = draftProviders.isEmpty
                                  ? _providerOptions.toSet()
                                  : draftProviders;
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Consultations'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.textLight,
          tabs: [
            const Tab(text: 'My Consultations'),
            Tab(text: _isNextOfKin ? 'History' : 'Book New'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _isNextOfKin
            ? [
                _nextOfKinConsultationsList(
                  _activeConsultations,
                  emptyEmoji: '👩‍⚕️',
                  emptyTitle: 'No active consultations',
                  emptySubtitle:
                      "Consultations and questions currently in progress will show up here.",
                ),
                _nextOfKinConsultationsList(
                  _historyConsultations,
                  emptyEmoji: '🗂️',
                  emptyTitle: 'No history yet',
                  emptySubtitle:
                      'Completed or cancelled consultations and questions will show up here.',
                ),
              ]
            : [
                // Tab 1: My consultations
                Column(
                  children: [
                    if (!_loading && _error == null && _consultations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _showFilterSheet,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: const BorderSide(color: AppColors.teal),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: Badge(
                              isLabelVisible: _hasActiveFilter,
                              backgroundColor: AppColors.teal,
                              smallSize: 8,
                              child: const Icon(Icons.filter_list, size: 18),
                            ),
                            label: const Text('Filter'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: _loading
                          ? const TBLoading()
                          : _error != null
                              ? TBEmptyState(
                                  emoji: '⚠️',
                                  title: 'Couldn\'t load consultations',
                                  subtitle: _error!,
                                  buttonLabel: 'Retry',
                                  onButton: () {
                                    setState(() => _loading = true);
                                    _load();
                                  })
                              : _consultations.isEmpty
                                  ? TBEmptyState(
                                      emoji: '👩‍⚕️',
                                      title: 'No consultations yet',
                                      subtitle: isPremium
                                          ? 'Book a consultation with a specialist or ask a volunteer a question.'
                                          : 'Ask a community volunteer a question.',
                                      buttonLabel: 'Book Now',
                                      onButton: () => _tabs.animateTo(1))
                                  : _filteredConsultations.isEmpty
                                      ? TBEmptyState(
                                          emoji: '🔍',
                                          title: 'No matches',
                                          subtitle:
                                              'No consultations match this filter.',
                                          buttonLabel: 'Clear Filter',
                                          onButton: () => setState(() {
                                                _selectedFilter = 'All';
                                                _selectedProviders =
                                                    _providerOptions.toSet();
                                              }))
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount:
                                              _filteredConsultations.length,
                                          itemBuilder: (ctx, i) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _itemCard(
                                                _filteredConsultations[i]),
                                          ),
                                        ),
                    ),
                  ],
                ),

                // Tab 2: Book new — everyone can reach volunteers;
                // specialists are premium-only.
                _buildBookTab(isPremium),
              ],
      ),
    );
  }

  Widget _nextOfKinConsultationsList(
    List<Map<String, dynamic>> items, {
    required String emptyEmoji,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (_loading) return const TBLoading();
    if (_error != null) {
      return TBEmptyState(
        emoji: '⚠️',
        title: 'Couldn\'t load consultations',
        subtitle: _error!,
        buttonLabel: 'Retry',
        onButton: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }

    final Widget content;
    if (items.isNotEmpty) {
      content = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _itemCard(items[i]),
        ),
      );
    } else if (_selectedTypeFilters.isNotEmpty) {
      content = TBEmptyState(
        emoji: '🔍',
        title: 'No matches',
        subtitle: 'Nothing here for this filter yet.',
        buttonLabel: 'Clear Filter',
        onButton: () => setState(() => _selectedTypeFilters.clear()),
      );
    } else {
      content = TBEmptyState(
          emoji: emptyEmoji, title: emptyTitle, subtitle: emptySubtitle);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _typeFilterRow(),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _typeFilterRow() {
    // "All" is its own chip: tapping it clears every specific selection.
    // It's shown as selected exactly when nothing else is picked.
    final chips = ['All', ..._typeFilterOptions];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = chips[index];
          final isAllChip = option == 'All';
          final selected = isAllChip
              ? _selectedTypeFilters.isEmpty
              : _selectedTypeFilters.contains(option);
          return GestureDetector(
            onTap: () => setState(() {
              if (isAllChip) {
                _selectedTypeFilters.clear();
              } else if (!_selectedTypeFilters.remove(option)) {
                _selectedTypeFilters.add(option);
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.teal : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.teal
                      : AppColors.textLight.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    if (item['_kind'] == 'question') return _questionCard(context, item);

    final c = item;
    final status = c['status'] ?? 'pending';
    return TBCard(
      onTap: () async {
        await context.push('/consultation/detail', extra: c);
        _load();
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: statusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Center(child: statusIconWidget(status)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consultationTypeLabel(c['consultation_type'] as String?),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_call, color: AppColors.teal, size: 15),
                    SizedBox(width: 4),
                    Text('Zoom Meeting',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textLight, size: 18),
        ],
      ),
    );
  }

  Widget _questionCard(BuildContext context, Map<String, dynamic> q) {
    final status = q['status'] as String? ?? 'pending';
    final isCompleted = status == 'closed';
    return TBCard(
      onTap: () async {
        await context.push('/ask-volunteer/detail', extra: q);
        _load();
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: (isCompleted ? AppColors.sage : AppColors.gold)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child:
                const Center(child: Text('🤝', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q['question'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(isCompleted ? 'COMPLETED' : 'ONGOING',
                    style: TextStyle(
                        color: isCompleted ? AppColors.sage : AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
        ],
      ),
    );
  }

  Widget _buildBookTab(bool isPremium) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TBSectionTitle(title: 'Choose Provider Type'),
          const SizedBox(height: 12),
          if (!isPremium) ...[
            const Text(
                'Free accounts can connect with community volunteers. Upgrade to Premium for verified specialists.',
                style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Opacity(
                  opacity: isPremium ? 1 : 0.5,
                  child: TBCard(
                    color: AppColors.blush,
                    onTap: isPremium
                        ? () => context.push('/consultation/specialists')
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Specialist consultations are a Premium feature. Upgrade to unlock.'),
                              ),
                            ),
                    child: Column(
                      children: [
                        if (!isPremium)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.lock,
                                  color: AppColors.gold, size: 12),
                            ),
                          ),
                        const Text('👩‍⚕️', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        const Text('Specialist',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Verified doctors',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TBCard(
                  color: AppColors.tealLight,
                  onTap: () async {
                    await context.push('/ask-volunteer');
                    _load();
                  },
                  child: const Column(
                    children: [
                      Text('🤝', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 8),
                      Text('Ask a Volunteer',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Post your question',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
