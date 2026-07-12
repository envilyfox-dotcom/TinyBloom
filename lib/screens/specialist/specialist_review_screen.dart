import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(date);
}

// ── Review tab (Specialists) ─────────────────────────────────────────────
// Replaces the community Forum tab for specialists. Shows the peer-review
// queue for their specialty group(s) plus their own submissions.
// See Article_System_specialist.md §3-5.
class SpecialistReviewScreen extends StatefulWidget {
  const SpecialistReviewScreen({super.key});
  @override
  State<SpecialistReviewScreen> createState() =>
      _SpecialistReviewScreenState();
}

class _SpecialistReviewScreenState extends State<SpecialistReviewScreen> {
  int _tab = 0;
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _mine = [];

  @override
  void initState() {
    super.initState();
    _load();
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
                  backgroundImage:
                      authorPhoto != null ? NetworkImage(authorPhoto) : null,
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
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Needs Action')),
                  ButtonSegment(value: 1, label: Text('All Visible')),
                  ButtonSegment(value: 2, label: Text('My Submissions')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            Expanded(
              child: _loading
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
                      child: lists[_tab].isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                const SizedBox(height: 60),
                                TBEmptyState(
                                  emoji: emptyEmojis[_tab],
                                  title: 'Nothing here',
                                  subtitle: emptyMessages[_tab],
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: lists[_tab].length,
                              itemBuilder: (ctx, i) => _item(lists[_tab][i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
