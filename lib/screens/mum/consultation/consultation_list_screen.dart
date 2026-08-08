import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/supabase_service.dart';
import '../../../services/auth_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/quick_chat_volunteer.dart';
import 'consultation_helpers.dart';

class ConsultationListScreen extends StatefulWidget {
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
  bool _isNextOfKin = false;
  Map<String, Map<String, dynamic>?> _providerProfiles = {};

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

  static const _typeFilterOptions = ['Pending', 'Confirmed', 'Volunteer Chats'];
  final Set<String> _selectedTypeFilters = {};

  @override
  void initState() {
    super.initState();
    _isNextOfKin = context.read<AuthProvider>().isNextOfKin;
    _tabs = TabController(length: 2, vsync: this);
    if (widget.initialTypeFilters != null) {
      _selectedTypeFilters.addAll(widget.initialTypeFilters!);
    }
    _load();
  }

  String? _error;

  String _effectiveStatus(Map<String, dynamic> item) {
    if (item['_kind'] == 'question') {
      return (item['status'] as String? ?? 'pending').toLowerCase();
    }
    return effectiveConsultationStatus(item);
  }

  String _itemCategory(Map<String, dynamic> item) {
    final status = _effectiveStatus(item);
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

  String _providerCategory(Map<String, dynamic> item) =>
      item['_kind'] == 'question' ? 'Volunteer' : 'Specialist';

  bool _isHistoryItem(Map<String, dynamic> item) {
    final category = _itemCategory(item);
    return category == 'completed' || category == 'cancelled';
  }

  List<Map<String, dynamic>> get _filteredConsultations {
    final category = _selectedFilter.toLowerCase();
    return _consultations.where((c) {
      final matchesStatus =
          _selectedFilter == 'All' || _itemCategory(c) == category;
      final matchesProvider = _selectedProviders.contains(_providerCategory(c));
      return matchesStatus && matchesProvider;
    }).toList();
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
    return false;
  }

  List<Map<String, dynamic>> get _activeConsultations => _consultations
      .where((c) => !_isHistoryItem(c) && _matchesTypeFilter(c))
      .toList();

  List<Map<String, dynamic>> get _historyConsultations => _consultations
      .where((c) => _isHistoryItem(c) && _matchesTypeFilter(c))
      .toList();

  DateTime _sortKey(Map<String, dynamic> item) {
    if (item['_kind'] != 'question') {
      final scheduled = consultationScheduledDateTime(item);
      if (scheduled != null) return scheduled;
    }
    return DateTime.tryParse(item['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _load() async {
    try {
      List<Map<String, dynamic>> c;
      if (_isNextOfKin) {
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
        final raw = await SupabaseService.getMyVolunteerQuestions();
        await SupabaseService.autoCloseStaleRequests(raw);
        questions = await enrichQuickChatQuestions(raw);
      } catch (_) {}

      final specialistConsultations =
          c.where((r) => r['consultation_type'] != 'volunteer').toList();

      final specialistIds = specialistConsultations
          .map((r) => r['specialist_id'] as String?)
          .whereType<String>()
          .toSet();
      final providerProfiles = <String, Map<String, dynamic>?>{};
      await Future.wait(specialistIds.map((id) async {
        providerProfiles[id] = await SupabaseService.getProviderProfile(id);
      }));

      if (!_isNextOfKin) {
        final mumId = SupabaseService.currentUser?.id;
        if (mumId != null) {
          for (final consultation in specialistConsultations) {
            if (effectiveConsultationStatus(consultation) != 'completed') {
              continue;
            }
            final specialistId = consultation['specialist_id'] as String?;
            if (specialistId == null) continue;
            final profile = providerProfiles[specialistId];
            final profileFields = profile?['profiles'];
            final specialistName = (profileFields is Map
                    ? profileFields['full_name'] as String?
                    : null) ??
                'Specialist';
            SupabaseService.ensureRatingNotification(
              mumId: mumId,
              providerId: specialistId,
              providerType: 'specialist',
              providerName: specialistName,
              sourceType: 'consultation',
              sourceId: consultation['id'].toString(),
            );
          }
        }
      }

      final merged = <Map<String, dynamic>>[
        ...specialistConsultations,
        ...questions.map((q) => {...q, '_kind': 'question'}),
      ];
      merged.sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));

      if (mounted) {
        setState(() {
          _consultations = merged;
          _providerProfiles = providerProfiles;
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

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final selected = _selectedFilter == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = option),
                  selectedColor: AppColors.tealLight,
                  backgroundColor: AppColors.white,
                  side: BorderSide(
                    color: selected
                        ? AppColors.teal
                        : AppColors.textLight.withValues(alpha: 0.25),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.teal : AppColors.textMid,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  checkmarkColor: AppColors.teal,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _providerOptions.map((option) {
              final selected = _selectedProviders.contains(option);
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                onSelected: (checked) => setState(() {
                  if (checked) {
                    _selectedProviders.add(option);
                  } else if (_selectedProviders.length > 1) {
                    _selectedProviders.remove(option);
                  }
                }),
                selectedColor: AppColors.tealLight,
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: selected
                      ? AppColors.teal
                      : AppColors.textLight.withValues(alpha: 0.25),
                ),
                labelStyle: TextStyle(
                  color: selected ? AppColors.teal : AppColors.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                checkmarkColor: AppColors.teal,
              );
            }).toList(),
          ),
        ],
      ),
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
                Column(
                  children: [
                    if (!_loading &&
                        _error == null &&
                        _consultations.isNotEmpty)
                      _filterBar(),
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
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 4, 16, 16),
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

  String? _providerName(Map<String, dynamic> c) {
    final id = c['specialist_id'] as String?;
    if (id == null) return null;
    final provider = _providerProfiles[id];
    final profile = provider?['profiles'];
    final name =
        profile is Map ? (profile['full_name']?.toString().trim() ?? '') : '';
    if (name.isEmpty) return null;
    return provider?['provider_type'] == 'specialist' ? 'Dr. $name' : name;
  }

  String? _providerPhotoUrl(Map<String, dynamic> c) {
    final id = c['specialist_id'] as String?;
    if (id == null) return null;
    final profile = _providerProfiles[id]?['profiles'];
    final url = profile is Map
        ? (profile['profile_picture_url']?.toString() ?? '')
        : '';
    return url.trim().isEmpty ? null : url.trim();
  }

  Future<void> _joinMeeting(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid meeting link.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the meeting link.')),
      );
    }
  }

  String _scheduleText(Map<String, dynamic> c) {
    final dateRaw = c['scheduled_date']?.toString();
    if (dateRaw == null || dateRaw.isEmpty) return '';
    final date = DateTime.tryParse(dateRaw);
    final dateText =
        date != null ? DateFormat('d MMM yyyy').format(date) : dateRaw;
    final time = (c['scheduled_time'] as String? ?? '').trim();
    return time.isEmpty ? dateText : '$dateText, $time';
  }

  Widget _itemCard(Map<String, dynamic> item) {
    if (item['_kind'] == 'question') {
      return QuickChatPreviewCard(question: item, onReload: _load);
    }

    final c = item;
    final status = _effectiveStatus(c);
    final providerName = _providerName(c);
    final photoUrl = _providerPhotoUrl(c);
    final schedule = _scheduleText(c);
    final purpose = (c['purpose'] as String? ?? '').trim();
    final platform = (c['platform'] as String? ?? 'Zoom Meeting').trim();
    final meetingLink = (c['meeting_link'] as String? ?? '').trim();
    final canJoin =
        status.toLowerCase() == 'confirmed' && meetingLink.isNotEmpty;

    return TBCard(
      onTap: () async {
        await context.push('/consultation/detail', extra: c);
        _load();
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              image: photoUrl != null
                  ? DecorationImage(
                      image:
                          CachedNetworkImageProvider(photoUrl, maxWidth: 200),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl != null
                ? null
                : Center(child: statusIconWidget(status)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        consultationTypeLabel(
                            c['consultation_type'] as String?),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: statusColor(status),
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (providerName != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                if (schedule.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: AppColors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          schedule,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textMid, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (purpose.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    purpose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 6),
                if (canJoin)
                  SizedBox(
                    height: 30,
                    child: ElevatedButton.icon(
                      onPressed: () => _joinMeeting(meetingLink),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.video_call, size: 15),
                      label: const Text(
                        'Join Zoom Meeting',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.video_call,
                          color: AppColors.teal, size: 14),
                      const SizedBox(width: 4),
                      Text(platform,
                          style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
