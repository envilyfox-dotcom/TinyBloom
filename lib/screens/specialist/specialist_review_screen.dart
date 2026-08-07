import 'dart:async';
import '../../utils/singapore_time.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/specialist_group_cache.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(toSingaporeTime(date));
}

// ── Review tab (Specialists) ─────────────────────────────────────────────
// Replaces the community Forum tab for specialists. Shows the peer-review
// queue for their specialty group(s) plus their own submissions.
// See Article_System_specialist.md §3-5.
class SpecialistReviewScreen extends StatefulWidget {
  const SpecialistReviewScreen({super.key});
  @override
  State<SpecialistReviewScreen> createState() => _SpecialistReviewScreenState();
}

class _SpecialistReviewScreenState extends State<SpecialistReviewScreen> {
  static const _tabLabels = ['Needs Review', 'All Visible', 'My Submissions'];

  int _tab = 0;
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _mine = [];

  final _searchCtrl = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  Timer? _searchDebounce;

  String? _myName;
  String? _mySpecialization;
  Map<String, dynamic>? _myPrimaryGroup;
  List<Map<String, dynamic>> _mySecondaryGroups = [];
  Map<int, List<String>> _groupSpecialties = {};
  bool _groupInfoLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadGroupInfo();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 250), () => _searchQuery.value = v);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchQuery.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applySearch(
      List<Map<String, dynamic>> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;

    return items.where((item) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final authorName = ((item['author'] as Map<String, dynamic>?)?['full_name']
              as String? ??
          '')
          .toLowerCase();
      return title.contains(q) || authorName.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final queue = await SupabaseService.getReviewQueue();
      final mine = await SupabaseService.getMyArticleSubmissions();
      if (mounted) {
        setState(() {
          _queue = queue;
          _mine = mine;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  // Backs the "?" info button. A doctor's specialization is fixed at
  // registration and can't be changed from the app, so their primary/
  // secondary group standing never changes for the life of the session —
  // cache it after the first fetch instead of re-hitting the network (and
  // racing the info button) every time this screen remounts.
  Future<void> _loadGroupInfo() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId != null && SpecialistGroupCache.isValidFor(userId)) {
      setState(() {
        _myName = SpecialistGroupCache.name;
        _mySpecialization = SpecialistGroupCache.specialization;
        _myPrimaryGroup = SpecialistGroupCache.primaryGroup;
        _mySecondaryGroups = SpecialistGroupCache.secondaryGroups;
        _groupSpecialties = SpecialistGroupCache.groupSpecialties;
        _groupInfoLoading = false;
      });
      return;
    }

    try {
      final profile = await SupabaseService.getProfile();
      final specialistProfile = await SupabaseService.getMySpecialistProfile();
      final primaryGroup = await SupabaseService.getMyPrimaryGroup();
      final secondaryGroups = primaryGroup != null
          ? await SupabaseService.getSecondaryGroupsFor(
              primaryGroup['id'] as int)
          : <Map<String, dynamic>>[];

      final groupIds = {
        if (primaryGroup != null) primaryGroup['id'] as int,
        ...secondaryGroups.map((g) => g['id'] as int),
      };
      final specialtiesByGroup = <int, List<String>>{};
      await Future.wait(groupIds.map((id) async {
        specialtiesByGroup[id] = await SupabaseService.getSpecialtiesForGroup(id);
      }));

      final name = profile?['full_name'] as String?;
      final specialization = specialistProfile?['specialization'] as String?;

      if (userId != null) {
        SpecialistGroupCache.save(
          userId: userId,
          name: name,
          specialization: specialization,
          primaryGroup: primaryGroup,
          secondaryGroups: secondaryGroups,
          groupSpecialties: specialtiesByGroup,
        );
      }

      if (mounted) {
        setState(() {
          _myName = name;
          _mySpecialization = specialization;
          _myPrimaryGroup = primaryGroup;
          _mySecondaryGroups = secondaryGroups;
          _groupSpecialties = specialtiesByGroup;
          _groupInfoLoading = false;
        });
      }
    } catch (_) {
      // Non-critical — the info button just won't have data to show.
      if (mounted) setState(() => _groupInfoLoading = false);
    }
  }

  void _showGroupInfo() {
    if (_groupInfoLoading) return;
    showDialog(
      context: context,
      builder: (ctx) => _GroupInfoDialog(
        name: _myName,
        specialization: _mySpecialization,
        primaryGroup: _myPrimaryGroup,
        secondaryGroups: _mySecondaryGroups,
        groupSpecialties: _groupSpecialties,
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'pending_approval_1':
        return 'Awaiting 1st approval';
      case 'pending_approval_2':
        return 'Awaiting 2nd approval';
      case 'changes_requested':
        return 'Changes requested';
      case 'publish_buffer':
        return 'In publish buffer';
      case 'emergency_pending':
        return 'Flagged for recall';
      case 'published':
        return 'Published';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return AppColors.teal;
      case 'publish_buffer':
        return AppColors.sage;
      case 'changes_requested':
      case 'emergency_pending':
        return Colors.redAccent;
      case 'draft':
        return AppColors.textLight;
      default:
        return AppColors.gold;
    }
  }

  Widget _item(Map<String, dynamic> item) {
    final status = item['status'] as String? ?? '';
    final needsAction = item['needs_action'] == true;
    final author = item['author'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] as String? ?? 'Author';
    final authorPhoto = author?['profile_picture_url'] as String?;
    final authorSpecialization = (author?['specialist_profiles']
        as Map<String, dynamic>?)?['specialization'] as String?;
    final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: () async {
          await context.push('/specialist/review/thread',
              extra: item['id'] as String);
          if (mounted) _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                  backgroundImage: authorPhoto != null
                      ? CachedNetworkImageProvider(authorPhoto, maxWidth: 200)
                      : null,
                  child: authorPhoto == null
                      ? Text(
                          authorName.isNotEmpty
                              ? authorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.roseDeep,
                              fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textDark)),
                      Text(
                        [
                          if (authorSpecialization != null)
                            authorSpecialization,
                          if (createdAt != null) _timeAgo(createdAt),
                        ].join(' • '),
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textLight, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item['title'] as String? ?? 'Untitled',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              if (needsAction)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text('Needs your action',
                      style: TextStyle(
                          color: AppColors.roseDeep,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsAction = _queue.where((q) => q['needs_action'] == true).toList();

    final lists = [needsAction, _queue, _mine];
    final emptyMessages = [
      'Nothing needs your attention right now.',
      'No content is currently in review for your group.',
      'Articles you write will show up here.',
    ];
    final emptyEmojis = ['✅', '📋', '📝'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review')),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      // The body's TBLoading (below) stays up until group info is ready too,
      // so this and the rest of the page always appear together in one
      // shot — no separate spinner-in-a-button loading state of its own.
      floatingActionButton: _groupInfoLoading
          ? null
          : FloatingActionButton(
              heroTag: 'review_group_info',
              mini: true,
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              onPressed: _showGroupInfo,
              shape: const CircleBorder(),
              child: const Icon(Icons.question_mark_rounded, size: 18),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (context, value, _) => TextFormField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by title or author',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textLight),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textLight),
                            onPressed: () {
                              _searchCtrl.clear();
                              _searchDebounce?.cancel();
                              _searchQuery.value = '';
                            },
                          ),
                    fillColor: AppColors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabLabels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final label = _tabLabels[index];
                    final selected = _tab == index;

                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _tab = index),
                      selectedColor: AppColors.tealLight,
                      backgroundColor: AppColors.white,
                      side: BorderSide(
                        color: selected
                            ? AppColors.infoBlue
                            : AppColors.textLight.withValues(alpha: 0.25),
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.infoBlue
                            : AppColors.textMid,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      checkmarkColor: AppColors.infoBlue,
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: _loading || _groupInfoLoading
                  ? const TBLoading()
                  : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 40),
                                const SizedBox(height: 12),
                                Text('Couldn\'t load: $_loadError',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.textMid)),
                                const SizedBox(height: 16),
                                TBButton(label: 'Retry', onPressed: _load),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.rose,
                          onRefresh: _load,
                          child: ValueListenableBuilder<String>(
                            valueListenable: _searchQuery,
                            builder: (context, query, _) {
                              final currentList = lists[_tab];
                              final filtered =
                                  _applySearch(currentList, query);

                              if (currentList.isEmpty) {
                                return ListView(
                                  padding: const EdgeInsets.all(20),
                                  children: [
                                    const SizedBox(height: 60),
                                    TBEmptyState(
                                      emoji: emptyEmojis[_tab],
                                      title: 'Nothing here',
                                      subtitle: emptyMessages[_tab],
                                    ),
                                  ],
                                );
                              }

                              if (filtered.isEmpty) {
                                return ListView(
                                  padding: const EdgeInsets.all(20),
                                  children: const [
                                    SizedBox(height: 60),
                                    TBEmptyState(
                                      emoji: '🔍',
                                      title: 'No matches found',
                                      subtitle:
                                          'Try a different title or author name.',
                                    ),
                                  ],
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) => _item(filtered[i]),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group info dialog ────────────────────────────────────────────────────
// Explains, in plain terms, which review groups this specialist belongs to
// and what each grants them — primary group membership allows both approval
// slots, secondary group membership allows only the second. See
// Article_System_specialist.md §2-3.
class _GroupInfoDialog extends StatelessWidget {
  final String? name;
  final String? specialization;
  final Map<String, dynamic>? primaryGroup;
  final List<Map<String, dynamic>> secondaryGroups;
  final Map<int, List<String>> groupSpecialties;

  const _GroupInfoDialog({
    required this.name,
    required this.specialization,
    required this.primaryGroup,
    required this.secondaryGroups,
    required this.groupSpecialties,
  });

  String _groupLabel(Map<String, dynamic>? group) {
    if (group == null) return 'Unassigned';
    return 'Group ${group['id']}: ${group['name']}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                      child: const Icon(Icons.medical_services_rounded,
                          color: AppColors.roseDeep, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (name != null && name!.isNotEmpty)
                                'Dr $name'
                              else
                                'Your profile',
                              if (specialization != null &&
                                  specialization!.isNotEmpty)
                                specialization!,
                            ].join(' • '),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textDark),
                          ),
                          Text(
                            _groupLabel(primaryGroup),
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textLight,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                TBCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.checklist_rounded,
                              color: AppColors.sage, size: 20),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Primary group',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textDark)),
                              Text('First and Second review',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (primaryGroup != null)
                        _GroupDropdown(
                          group: primaryGroup!,
                          specialties: groupSpecialties[primaryGroup!['id']] ?? [],
                          color: AppColors.sage,
                        )
                      else
                        const Text('Unassigned',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.sage)),
                      const SizedBox(height: 6),
                      const Text(
                        'This is the main group that allows for first and '
                        'second approval between one another.',
                        style:
                            TextStyle(color: AppColors.textMid, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TBCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.visibility_rounded,
                              color: AppColors.teal, size: 20),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Secondary Group',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textDark)),
                              Text('Second review only',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (secondaryGroups.isEmpty)
                        const Text('None',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.teal))
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final group in secondaryGroups)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _GroupDropdown(
                                  group: group,
                                  specialties:
                                      groupSpecialties[group['id']] ?? [],
                                  color: AppColors.teal,
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      const Text(
                        'The secondary grouping allows you to review their '
                        'submission for second approval.',
                        style:
                            TextStyle(color: AppColors.textMid, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A group name that expands, on tap of its chevron, into the list of member
// specialties for that review group — see Article_System_specialist.md §2.
class _GroupDropdown extends StatefulWidget {
  final Map<String, dynamic> group;
  final List<String> specialties;
  final Color color;

  const _GroupDropdown({
    required this.group,
    required this.specialties,
    required this.color,
  });

  @override
  State<_GroupDropdown> createState() => _GroupDropdownState();
}

class _GroupDropdownState extends State<_GroupDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Group ${widget.group['id']}: ${widget.group['name']}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: widget.color),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: widget.color,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.specialties.isEmpty
                  ? const [
                      Text('No specialties listed',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 12))
                    ]
                  : widget.specialties
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('•  $s',
                                style: const TextStyle(
                                    color: AppColors.textMid, fontSize: 12)),
                          ))
                      .toList(),
            ),
          ),
      ],
    );
  }
}
