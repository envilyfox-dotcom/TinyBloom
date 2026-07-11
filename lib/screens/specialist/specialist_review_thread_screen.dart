import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Review thread (Specialists) ──────────────────────────────────────────
// The specialist-only thread for one piece of content: state, approval
// history, comments, and the approve/reject/emergency-pending actions.
// See Article_System_specialist.md §3-5. All state-changing actions call
// the security-definer RPCs in supabase_service.dart — this screen never
// writes `status`/approvals rows directly.
class SpecialistReviewThreadScreen extends StatefulWidget {
  final String contentId;
  const SpecialistReviewThreadScreen({super.key, required this.contentId});

  @override
  State<SpecialistReviewThreadScreen> createState() =>
      _SpecialistReviewThreadScreenState();
}

class _SpecialistReviewThreadScreenState
    extends State<SpecialistReviewThreadScreen> {
  Map<String, dynamic>? _content;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  String? _loadError;
  bool _acting = false;
  final _commentCtrl = TextEditingController();

  String? get _myId => SupabaseService.currentUser?.id;
  bool get _isAuthor => _content != null && _content!['created_by'] == _myId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final content =
          await SupabaseService.getReviewThreadContent(widget.contentId);
      final comments =
          await SupabaseService.getReviewComments(widget.contentId);
      if (mounted) {
        setState(() {
          _content = content;
          _comments = comments;
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _acting = false);
  }

  int get _stage {
    final status = _content?['status'] as String? ?? '';
    return status == 'pending_approval_1' ? 1 : 2;
  }

  Future<void> _approve() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve stage $_stage?'),
        content: const Text(
            'This will advance the content to the next step of the review pipeline.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirm == true) {
      await _run(() =>
          SupabaseService.approveContent(widget.contentId, _stage));
    }
  }

  Future<void> _reject() async {
    final result = await _showCategoryReasonDialog(
      title: 'Reject content',
      confirmLabel: 'Reject',
    );
    if (result != null) {
      await _run(() => SupabaseService.rejectContent(
          widget.contentId, _stage, result['category']!, result['reason']!));
    }
  }

  Future<void> _flagEmergency() async {
    final result = await _showCategoryReasonDialog(
      title: 'Flag for emergency review',
      confirmLabel: 'Flag',
    );
    if (result != null) {
      await _run(() => SupabaseService.triggerEmergencyPending(
          widget.contentId, result['category']!, result['reason']!));
    }
  }

  Future<Map<String, String>?> _showCategoryReasonDialog({
    required String title,
    required String confirmLabel,
  }) async {
    String category = 'clinical';
    final reasonCtrl = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text('Clinical'),
                  selected: category == 'clinical',
                  onSelected: (_) => setDialogState(() => category = 'clinical'),
                ),
                ChoiceChip(
                  label: const Text('Non-clinical'),
                  selected: category == 'non_clinical',
                  onSelected: (_) =>
                      setDialogState(() => category = 'non_clinical'),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Reason (required)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx,
                    {'category': category, 'reason': reasonCtrl.text.trim()});
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resubmit() async {
    await _run(() => SupabaseService.submitContentForReview(widget.contentId));
  }

  Future<void> _editAndResubmit() async {
    final titleCtrl =
        TextEditingController(text: _content?['title'] as String? ?? '');
    final contentCtrl =
        TextEditingController(text: _content?['content'] as String? ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit article', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
            const SizedBox(height: 16),
            TBButton(
              label: 'Save',
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _run(() async {
        await SupabaseService.updateArticleContent(widget.contentId,
            title: titleCtrl.text.trim(), content: contentCtrl.text.trim());
        await SupabaseService.submitContentForReview(widget.contentId);
      });
    }
  }

  Future<void> _postComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    _commentCtrl.clear();
    await SupabaseService.postReviewComment(widget.contentId, body);
    final comments = await SupabaseService.getReviewComments(widget.contentId);
    if (mounted) setState(() => _comments = comments);
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
        return 'Live';
      default:
        return status;
    }
  }

  Widget _actionsForStatus(String status) {
    if (_isAuthor) {
      if (status == 'changes_requested') {
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _acting ? null : _resubmit,
              child: const Text('Resubmit as-is'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TBButton(
                label: 'Edit & Resubmit',
                loading: _acting,
                onPressed: _editAndResubmit),
          ),
        ]);
      }
      return const SizedBox.shrink();
    }

    if (status == 'pending_approval_1' || status == 'pending_approval_2') {
      return Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _acting ? null : _reject,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TBButton(
              label: 'Approve', loading: _acting, onPressed: _approve),
        ),
      ]);
    }

    if (status == 'publish_buffer' || status == 'emergency_pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _acting ? null : _flagEmergency,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Flag for emergency review'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: TBLoading());
    }
    if (_loadError != null || _content == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Thread')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(
                    _loadError != null
                        ? 'Couldn\'t load: $_loadError'
                        : 'This content could not be found.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMid)),
                const SizedBox(height: 16),
                TBButton(label: 'Retry', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }
    final status = _content!['status'] as String? ?? '';
    final approvals =
        List<Map<String, dynamic>>.from(_content!['approvals'] ?? []);
    final bufferStartedAt = _content!['buffer_started_at'] != null
        ? DateTime.tryParse(_content!['buffer_started_at'] as String)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Thread')),
      body: RefreshIndicator(
        color: AppColors.rose,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_content!['title'] as String? ?? 'Untitled',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(_statusLabel(status),
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            if (bufferStartedAt != null && status == 'publish_buffer') ...[
              const SizedBox(height: 8),
              Text(
                'Goes live ${bufferStartedAt.add(const Duration(hours: 24)).toLocal()}',
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Text(_content!['content'] as String? ?? '',
                style: const TextStyle(
                    color: AppColors.textMid, fontSize: 14, height: 1.5)),
            const SizedBox(height: 20),
            _actionsForStatus(status),
            const SizedBox(height: 28),
            const Text('Approval History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (approvals.isEmpty)
              const Text('No reviews yet.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13))
            else
              ...approvals.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TBCard(
                      child: Row(children: [
                        Icon(
                          a['decision'] == 'approve'
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: a['decision'] == 'approve'
                              ? AppColors.teal
                              : Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stage ${a['stage']} • ${a['decision']}${a['superseded'] == true ? ' (superseded)' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              if (a['reason'] != null)
                                Text(
                                  '${a['reject_category']}: ${a['reason']}',
                                  style: const TextStyle(
                                      color: AppColors.textLight, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  )),
            const SizedBox(height: 28),
            const Text('Discussion',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (_comments.isEmpty)
              const Text('No comments yet.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13))
            else
              ..._comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (c['profiles']?['full_name'] as String?) ??
                              'Specialist',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(c['body'] as String? ?? '',
                            style: const TextStyle(
                                color: AppColors.textMid, fontSize: 13)),
                      ],
                    ),
                  )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(hintText: 'Add a comment'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.rose),
                onPressed: _postComment,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
