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
  int? _myGroupId;
  final _commentCtrl = TextEditingController();

  String? get _myId => SupabaseService.currentUser?.id;
  bool get _isAuthor => _content != null && _content!['created_by'] == _myId;
  String get _authorName =>
      (_content?['author']?['full_name'] as String?) ?? 'Author';

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
      final myGroup = await SupabaseService.getMyPrimaryGroup();
      if (mounted) {
        setState(() {
          _content = content;
          _comments = comments;
          _myGroupId = myGroup?['id'] as int?;
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

  // The reviewer who currently holds the active (non-superseded) stage-1
  // approval — approval 2 must come from someone else (Article_System
  // §3.3, §7.1). Used to hide the stage-2 buttons from that same reviewer
  // instead of letting them hit the server-side rejection.
  String? get _stage1ApproverId {
    final active = List<Map<String, dynamic>>.from(_content?['approvals'] ?? [])
        .where((a) =>
            a['stage'] == 1 &&
            a['decision'] == 'approve' &&
            a['superseded'] != true)
        .toList()
      ..sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));
    return active.isEmpty ? null : active.last['reviewer_id'] as String?;
  }

  // True if a prior approval 1 was voided — currently only happens via a
  // clinical emergency-pending recall during the publish buffer
  // (Article_System §3.5), which sends content back to pending_approval_1.
  // Distinguishes that case from a content item that simply hasn't reached
  // approval 1 yet, for the secondary-group notice below.
  bool get _hasSupersededStage1Approval =>
      List<Map<String, dynamic>>.from(_content?['approvals'] ?? []).any((a) =>
          a['stage'] == 1 && a['decision'] == 'approve' && a['superseded'] == true);

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

  int get _unresolvedIssueCount => List<Map<String, dynamic>>.from(
          _content?['approvals'] ?? [])
      .where((a) => a['decision'] == 'reject' && a['resolved'] != true)
      .length;

  // Only the author can resolve an issue (turn its "X" into a checklist —
  // enforced server-side too by resolve_review_issue). Other primary/
  // secondary reviewers can still reply, but it's posted as a normal
  // discussion comment and never flips the issue's resolved state.
  Future<void> _replyToIssue(String approvalId) async {
    final isAuthor = _isAuthor;
    final replyCtrl = TextEditingController();
    final reply = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply to issue'),
        content: TextField(
          controller: replyCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
              labelText:
                  isAuthor ? 'What did you change?' : 'Your reply'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (replyCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, replyCtrl.text.trim());
            },
            child: Text(isAuthor ? 'Solve Issue' : 'Reply'),
          ),
        ],
      ),
    );
    if (reply == null) return;
    if (isAuthor) {
      await _run(() => SupabaseService.resolveReviewIssue(approvalId, reply));
    } else {
      await _run(() => SupabaseService.postReviewComment(
          widget.contentId, reply,
          approvalId: approvalId));
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
        final unresolved = _unresolvedIssueCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unresolved == 0
                  ? 'All issues resolved'
                  : '$unresolved issue${unresolved == 1 ? '' : 's'} remaining',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: unresolved == 0 ? AppColors.teal : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            TBButton(
              label: 'Submit',
              loading: _acting,
              onPressed:
                  (_acting || unresolved > 0) ? null : _resubmit,
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    if (status == 'pending_approval_1' || status == 'pending_approval_2') {
      if (status == 'pending_approval_2' && _stage1ApproverId == _myId) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
              'You already reviewed this at approval 1 — a different reviewer is needed for approval 2.',
              style: TextStyle(color: Colors.red, fontSize: 12)),
        );
      }
      // Approval 1 is primary-group only (Article_System §3.2). A
      // secondary-group reviewer can still see this thread — including
      // after an emergency-pending clinical recall supersedes approval 1
      // and sends it back here — but isn't in the approval-1 reviewer pool,
      // so show a notice instead of buttons that would just error server-side.
      if (status == 'pending_approval_1' &&
          _myGroupId != _content!['primary_group_id']) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _hasSupersededStage1Approval
                ? 'A prior approval was superseded and this reset to approval 1. Only primary-group reviewers can act on it now — you\'ll be able to review it again once it reaches approval 2.'
                : 'This item is awaiting approval 1, which only primary-group reviewers can grant. You\'ll be able to review it once it reaches approval 2.',
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        );
      }
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
    final generalComments =
        _comments.where((c) => c['approval_id'] == null).toList();
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
            const Text('History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (approvals.isEmpty)
              const Text('No reviews yet.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13))
            else
              ...approvals.map((a) {
                final isReject = a['decision'] == 'reject';
                final resolved = a['resolved'] == true;
                final canReply =
                    status == 'changes_requested' && isReject && !resolved;
                final issueReplies =
                    _comments.where((c) => c['approval_id'] == a['id']).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TBCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          !isReject
                              ? Icons.check_circle_outline
                              : resolved
                                  ? Icons.checklist
                                  : Icons.cancel_outlined,
                          color: !isReject || resolved
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
                              for (final r in issueReplies)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                          color: AppColors.textMid,
                                          fontSize: 12),
                                      children: [
                                        TextSpan(
                                          text:
                                              '${r['author_id'] == _content!['created_by'] ? '★ ' : ''}${(r['profiles']?['full_name'] as String?) ?? 'Specialist'}: ',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                        TextSpan(
                                            text: r['body'] as String? ?? ''),
                                      ],
                                    ),
                                  ),
                                ),
                              // Always rendered last: solving an issue
                              // disables further replies, so this is
                              // guaranteed to be the final word on it.
                              if (a['resolution_reply'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                          color: AppColors.textMid,
                                          fontSize: 12),
                                      children: [
                                        TextSpan(
                                          text: '★ $_authorName: ',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                        TextSpan(
                                            text: a['resolution_reply']
                                                    as String? ??
                                                ''),
                                      ],
                                    ),
                                  ),
                                ),
                              if (canReply)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 28),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap),
                                    onPressed: _acting
                                        ? null
                                        : () =>
                                            _replyToIssue(a['id'] as String),
                                    child: const Text('Reply',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 28),
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
            const SizedBox(height: 20),
            const Text('Discussion',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (generalComments.isEmpty)
              const Text('No comments yet.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13))
            else
              ...generalComments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['author_id'] == _content!['created_by'] ? '★ ' : ''}${(c['profiles']?['full_name'] as String?) ?? 'Specialist'}',
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
          ],
        ),
      ),
    );
  }
}
