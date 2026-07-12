import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/article_content.dart';

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(date);
}

// A single item in the merged "Checks" timeline — either an approval/reject/
// suggestion row or an edit-history row, sorted together by time so edits
// show up in context with the reviews around them.
class _TimelineItem {
  final DateTime time;
  final bool isEdit;
  final Map<String, dynamic> data;
  _TimelineItem({required this.time, required this.isEdit, required this.data});
}

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
  final _commentFocusNode = FocusNode();
  // The discussion comment being replied to — the comment box above the
  // discussion feed doubles as the reply box, with a "Replying to X" chip
  // shown above it while set (mirrors the Educational Post comment flow).
  Map<String, dynamic>? _replyingTo;

  // Inline reply composer for a flagged (suggestion/issue) entry — same
  // tap-to-reveal-inline-input interaction as the discussion feed, instead
  // of a modal dialog. Only one entry's composer is open at a time.
  final _issueReplyCtrl = TextEditingController();
  final _issueReplyFocus = FocusNode();
  String? _replyingToApprovalId;

  // Post verification panel state.
  String? _verificationChoice; // 'suggestion' | 'issues' | null
  final _suggestionCtrl = TextEditingController();
  final _issueReasonCtrl = TextEditingController();
  String _issueCategory = 'clinical';

  bool _historyExpanded = false;

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
    _commentFocusNode.dispose();
    _issueReplyCtrl.dispose();
    _issueReplyFocus.dispose();
    _suggestionCtrl.dispose();
    _issueReasonCtrl.dispose();
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

  // Non-superseded approvals (plain or with-suggestion) granted so far,
  // clamped to 2 — self-corrects across every status, including after an
  // emergency recall supersedes approvals and the count drops back down.
  int get _checksCount {
    final approvals =
        List<Map<String, dynamic>>.from(_content?['approvals'] ?? []);
    final count = approvals
        .where((a) => a['decision'] == 'approve' && a['superseded'] != true)
        .length;
    return count.clamp(0, 2);
  }

  Color get _checksColor =>
      _checksCount >= 2 ? AppColors.teal : AppColors.gold;

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

  void _selectVerification(String choice) {
    setState(() =>
        _verificationChoice = _verificationChoice == choice ? null : choice);
  }

  Future<void> _sendSuggestion() async {
    final comment = _suggestionCtrl.text.trim();
    if (comment.isEmpty) return;
    await _run(() => SupabaseService.approveContentWithSuggestion(
        widget.contentId, _stage, comment));
    _suggestionCtrl.clear();
    if (mounted) setState(() => _verificationChoice = null);
  }

  Future<void> _sendIssue() async {
    final reason = _issueReasonCtrl.text.trim();
    if (reason.isEmpty) return;
    await _run(() => SupabaseService.rejectContent(
        widget.contentId, _stage, _issueCategory, reason));
    _issueReasonCtrl.clear();
    if (mounted) setState(() => _verificationChoice = null);
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

  Future<void> _editArticle() async {
    final result = await context.push<Object?>('/specialist/edit-article',
        extra: _content);
    if (result == 'deleted') {
      if (mounted) context.pop();
    } else if (result == true) {
      await _load();
    }
  }

  int get _unresolvedIssueCount => List<Map<String, dynamic>>.from(
          _content?['approvals'] ?? [])
      .where((a) => a['decision'] == 'reject' && a['resolved'] != true)
      .length;

  // Only the author can resolve an issue (turn its "X" into a checklist —
  // enforced server-side too by resolve_review_issue). Other primary/
  // secondary reviewers can still reply, but it's posted as a normal
  // discussion comment and never flips the issue's resolved state. Since
  // resolve_review_issue now also accepts suggestion rows, this same flow
  // covers both a rejection issue and an "approved with suggestion" note.
  // Reply UI is inline (tap Reply -> composer opens in place), matching
  // the discussion feed's reply interaction instead of a modal dialog.
  void _startIssueReply(String approvalId) {
    setState(() => _replyingToApprovalId = approvalId);
    FocusScope.of(context).requestFocus(_issueReplyFocus);
  }

  void _cancelIssueReply() {
    _issueReplyCtrl.clear();
    setState(() => _replyingToApprovalId = null);
  }

  Future<void> _submitIssueReply(String approvalId) async {
    final reply = _issueReplyCtrl.text.trim();
    if (reply.isEmpty) return;
    final isAuthor = _isAuthor;
    _issueReplyCtrl.clear();
    setState(() => _replyingToApprovalId = null);
    if (isAuthor) {
      await _run(() => SupabaseService.resolveReviewIssue(approvalId, reply));
    } else {
      await _run(() => SupabaseService.postReviewComment(
          widget.contentId, reply,
          approvalId: approvalId));
    }
  }

  String _topLevelParentId(Map<String, dynamic> comment) =>
      (comment['parent_comment_id'] as String?) ?? comment['id'] as String;

  void _startReply(Map<String, dynamic> comment) {
    setState(() => _replyingTo = comment);
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  Future<void> _postComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    final parentId =
        _replyingTo == null ? null : _topLevelParentId(_replyingTo!);
    _commentCtrl.clear();
    setState(() => _replyingTo = null);
    await SupabaseService.postReviewComment(widget.contentId, body,
        parentCommentId: parentId);
    final comments = await SupabaseService.getReviewComments(widget.contentId);
    if (mounted) setState(() => _comments = comments);
  }

  // Why an approval was superseded (approvals.superseded_reason) — set by
  // edit_article_content (no longer — edits leave approvals alone) and
  // trigger_emergency_pending, the only RPC that still voids an approval
  // outside its own reject/reset flow.
  String _supersededReasonLabel(String reason) {
    switch (reason) {
      case 'edited':
        return 'Article edited';
      case 'emergency_recall':
        return 'Recalled during publish buffer';
      default:
        return reason;
    }
  }

  IconData _supersededReasonIcon(String reason) {
    switch (reason) {
      case 'edited':
        return Icons.edit_outlined;
      case 'emergency_recall':
        return Icons.flag_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _actionsForStatus(String status) {
    if (_isAuthor) {
      if (status == 'published') {
        return const SizedBox.shrink();
      }
      // Editing is always available to the author pre-publish, not just
      // after a rejection — edit_article_content no longer resets the
      // review, so the button doesn't need to wait for a changes_requested
      // warning first.
      final editButton = OutlinedButton.icon(
        onPressed: _acting ? null : _editArticle,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Edit Article'),
      );
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
            Row(children: [
              Expanded(child: editButton),
              const SizedBox(width: 12),
              Expanded(
                child: TBButton(
                  label: 'Submit',
                  loading: _acting,
                  onPressed:
                      (_acting || unresolved > 0) ? null : _resubmit,
                ),
              ),
            ]),
          ],
        );
      }
      return SizedBox(width: double.infinity, child: editButton);
    }

    if (status == 'pending_approval_1' || status == 'pending_approval_2') {
      if (status == 'pending_approval_2' && _stage1ApproverId == _myId) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
              'Awaiting second approval. Each qualified user can only approve one time.',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
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
      return _postVerificationPanel();
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

  // Checkbox-styled action row shared by the three "Post verification"
  // options — visually a checklist, but "Approved" fires immediately
  // (matching the pre-redesign single-tap behavior) while the other two
  // toggle open a comment box gated behind a Send button.
  Widget _verificationRow({
    required String label,
    required bool checked,
    required bool showApprovalChip,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                color: checked ? AppColors.infoBlue : AppColors.textLight,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            if (showApprovalChip)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('+1 Approval',
                    style: TextStyle(
                        color: AppColors.infoBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _postVerificationPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textLight.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post verification',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          _verificationRow(
            label: 'Approved',
            checked: false,
            showApprovalChip: true,
            onTap: _acting ? null : _approve,
          ),
          const Divider(height: 24),
          _verificationRow(
            label: 'Approved with suggestion',
            checked: _verificationChoice == 'suggestion',
            showApprovalChip: true,
            onTap: _acting ? null : () => _selectVerification('suggestion'),
          ),
          if (_verificationChoice == 'suggestion') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _suggestionCtrl,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Comment required'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TBButton(
                label: 'Send',
                loading: _acting,
                color: AppColors.infoBlue,
                onPressed: _suggestionCtrl.text.trim().isEmpty
                    ? null
                    : _sendSuggestion,
              ),
            ),
          ],
          const Divider(height: 24),
          _verificationRow(
            label: 'Issues',
            checked: _verificationChoice == 'issues',
            showApprovalChip: false,
            onTap: _acting ? null : () => _selectVerification('issues'),
          ),
          if (_verificationChoice == 'issues') ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Clinical'),
                selected: _issueCategory == 'clinical',
                onSelected: (_) => setState(() => _issueCategory = 'clinical'),
              ),
              ChoiceChip(
                label: const Text('Non-clinical'),
                selected: _issueCategory == 'non_clinical',
                onSelected: (_) =>
                    setState(() => _issueCategory = 'non_clinical'),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _issueReasonCtrl,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Comment required'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TBButton(
                label: 'Send',
                loading: _acting,
                outline: true,
                color: Colors.red,
                onPressed:
                    _issueReasonCtrl.text.trim().isEmpty ? null : _sendIssue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCard(String status) {
    final author = _content!['author'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] as String? ?? 'Author';
    final authorPhoto = author?['profile_picture_url'] as String?;
    final authorSpecialization = (author?['specialist_profiles']
        as Map<String, dynamic>?)?['specialization'] as String?;
    final createdAt = DateTime.tryParse(_content!['created_at'] as String? ?? '');
    final bufferStartedAt = _content!['buffer_started_at'] != null
        ? DateTime.tryParse(_content!['buffer_started_at'] as String)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
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
                        if (authorSpecialization != null) authorSpecialization,
                        if (createdAt != null) _timeAgo(createdAt),
                      ].join(' • '),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _checksColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text('$_checksCount/2 checks',
                    style: TextStyle(
                        color: _checksColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(_content!['title'] as String? ?? 'Untitled',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (bufferStartedAt != null && status == 'publish_buffer') ...[
            const SizedBox(height: 6),
            Text(
              // TESTING: matches the interval '0 minutes' override in
              // testing_instant_publish_buffer.sql. Revert to
              // Duration(hours: 24) alongside that migration.
              'Goes live ${bufferStartedAt.add(Duration.zero).toLocal()}',
              style:
                  const TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          ArticleContent(
              data: _content!['content'] as String? ?? '',
              style: const TextStyle(
                  color: AppColors.textMid, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  // Shared avatar + bubble frame for both the flagged feed and History
  // entries — reviewer identity/timestamp look the same either way, only
  // the body content and (for the flagged feed) the border color differ.
  Widget _entryBubble(Map<String, dynamic>? reviewer, DateTime? createdAt,
      Widget body,
      {Color? borderColor}) {
    final reviewerName = reviewer?['full_name'] as String? ?? 'Specialist';
    final reviewerPhoto = reviewer?['profile_picture_url'] as String?;
    final reviewerSpecialization = (reviewer?['specialist_profiles']
        as Map<String, dynamic>?)?['specialization'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
            backgroundImage:
                reviewerPhoto != null ? NetworkImage(reviewerPhoto) : null,
            child: reviewerPhoto == null
                ? Text(
                    reviewerName.isNotEmpty
                        ? reviewerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 12))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: borderColor ??
                        AppColors.textLight.withValues(alpha: 0.3),
                    width: borderColor != null ? 1.5 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                              text: reviewerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          if (reviewerSpecialization != null)
                            TextSpan(
                                text: '  $reviewerSpecialization',
                                style: const TextStyle(
                                    color: AppColors.textLight, fontSize: 11)),
                        ])),
                      ),
                      Text(createdAt != null ? _timeAgo(createdAt) : '',
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  body,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Approved with suggestion" and "Issues" entries — the always-visible
  // feed below Post verification. Comment icon = suggestion (Reply and
  // Resolve is offered but optional — resolving it never gates anything).
  // Warning icon = issue/rejection (Reply and Resolve is only offered while
  // changes_requested, and resolving + resubmitting is required before the
  // pipeline can advance to another approval).
  Widget _flaggedEntry(Map<String, dynamic> a) {
    final status = _content!['status'] as String? ?? '';
    final isReject = a['decision'] == 'reject';
    final resolved = a['resolved'] == true;
    // Only the reviewer who sent it (to clarify) or the content's author
    // (to resolve) can reply — every other specialist can just read it.
    // Once published, the thread is closed to new replies entirely.
    final isSender = a['reviewer_id'] == _myId;
    final canReply = !resolved &&
        status != 'published' &&
        (_isAuthor || isSender) &&
        (isReject ? status == 'changes_requested' : true);
    final issueReplies =
        _comments.where((c) => c['approval_id'] == a['id']).toList();
    final reviewer = a['reviewer'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(a['created_at'] as String? ?? '');

    return _entryBubble(
      reviewer,
      createdAt,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a['superseded'] == true && a['superseded_reason'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _supersededReasonIcon(
                          a['superseded_reason'] as String),
                      size: 12,
                      color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                      _supersededReasonLabel(
                          a['superseded_reason'] as String),
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 1),
                child: Icon(
                    isReject
                        ? Icons.warning_amber_rounded
                        : Icons.mode_comment_outlined,
                    size: 14,
                    color: isReject ? AppColors.gold : AppColors.infoBlue),
              ),
              Expanded(
                child: Text(
                  isReject
                      ? '${a['reject_category']}: ${a['reason'] ?? ''}'
                      : a['reason'] as String? ?? '',
                  style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          for (final r in issueReplies)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 12),
                  children: [
                    TextSpan(
                      text:
                          '${r['author_id'] == _content!['created_by'] ? '★ ' : ''}${(r['profiles']?['full_name'] as String?) ?? 'Specialist'}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: r['body'] as String? ?? ''),
                  ],
                ),
              ),
            ),
          if (a['resolution_reply'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 12),
                  children: [
                    TextSpan(
                      text: '★ $_authorName: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: a['resolution_reply'] as String? ?? ''),
                  ],
                ),
              ),
            ),
          if (canReply)
            _replyingToApprovalId == a['id']
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _issueReplyCtrl,
                            focusNode: _issueReplyFocus,
                            autofocus: true,
                            maxLines: 3,
                            minLines: 1,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: _isAuthor
                                  ? 'What did you change?'
                                  : 'Your reply',
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelIssueReply,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close,
                                size: 16, color: AppColors.textLight),
                          ),
                        ),
                        GestureDetector(
                          onTap: _acting
                              ? null
                              : () =>
                                  _submitIssueReply(a['id'] as String),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.send,
                                size: 18, color: AppColors.rose),
                          ),
                        ),
                      ],
                    ),
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: _acting
                          ? null
                          : () => _startIssueReply(a['id'] as String),
                      child: Text(_isAuthor ? 'Reply and Resolve' : 'Reply',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
        ],
      ),
      borderColor: isReject ? Colors.redAccent : AppColors.infoBlue,
    );
  }

  // Every approval/reject decision, in the same plain style regardless of
  // whether it also carried a comment (suggestions/issues are additionally
  // shown, with their comment and Reply-and-Resolve controls, in the
  // flagged feed above) — this is just the bare "what happened" record.
  Widget _historyApprovalEntry(Map<String, dynamic> a) {
    final reviewer = a['reviewer'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(a['created_at'] as String? ?? '');
    final isReject = a['decision'] == 'reject';

    return _entryBubble(
      reviewer,
      createdAt,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 1),
            child: Icon(
                isReject ? Icons.cancel_outlined : Icons.check_circle,
                size: 14,
                color: isReject ? Colors.redAccent : AppColors.teal),
          ),
          Expanded(
            child: Text(
              '${isReject ? 'Rejected' : 'Approved'} stage ${a['stage']}${a['superseded'] == true ? ' (superseded)' : ''}',
              style:
                  const TextStyle(color: AppColors.textMid, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editHistoryEntry(Map<String, dynamic> e) {
    const labels = {
      'title': 'Title',
      'content': 'Content',
      'category': 'Category',
      'trimester': 'Trimester',
    };
    final changed = List<String>.from(e['changed_fields'] ?? []);
    final createdAt = DateTime.tryParse(e['created_at'] as String? ?? '');
    final changedLabel = changed.map((c) => labels[c] ?? c).join(', ');

    Widget diffRow(String fieldKey, String label) {
      if (!changed.contains(fieldKey)) return const SizedBox.shrink();
      final oldVal = e['old_$fieldKey']?.toString() ?? '';
      final newVal = e['new_$fieldKey']?.toString() ?? '';
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 2),
              Text('Before: ${oldVal.isEmpty ? '(empty)' : oldVal}',
                  style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough)),
              Text('After: ${newVal.isEmpty ? '(empty)' : newVal}',
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textLight.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(Icons.edit_note, color: AppColors.textLight),
        title: Text('Article edited — $changedLabel',
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(createdAt != null ? _timeAgo(createdAt) : '',
            style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        children: [
          diffRow('title', 'Title'),
          diffRow('content', 'Content'),
          diffRow('category', 'Category'),
          diffRow('trimester', 'Trimester'),
        ],
      ),
    );
  }

  // Always-visible feed of "Approved with suggestion" and "Issues" entries,
  // sitting directly below Post verification (review_article_2.png).
  Widget _flaggedFeed() {
    final approvals =
        List<Map<String, dynamic>>.from(_content!['approvals'] ?? [])
            .where((a) =>
                a['decision'] == 'reject' || a['has_suggestion'] == true)
            .toList()
          ..sort((a, b) => (a['created_at'] as String)
              .compareTo(b['created_at'] as String));
    if (approvals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final a in approvals) _flaggedEntry(a)],
    );
  }

  // Collapsible "History" — every approve/reject decision (plain style,
  // "Approved stage X" / "Rejected stage X", no comment/reply controls)
  // plus edit-history entries. Suggestions/issues are ALSO shown, with their
  // comment and Reply-and-Resolve controls, in the flagged feed above.
  Widget _historySection() {
    final approvals =
        List<Map<String, dynamic>>.from(_content!['approvals'] ?? []);
    final editHistory =
        List<Map<String, dynamic>>.from(_content!['article_edit_history'] ?? []);
    final items = <_TimelineItem>[
      for (final a in approvals)
        _TimelineItem(
            time: DateTime.tryParse(a['created_at'] as String? ?? '') ??
                DateTime.now(),
            isEdit: false,
            data: a),
      for (final e in editHistory)
        _TimelineItem(
            time: DateTime.tryParse(e['created_at'] as String? ?? '') ??
                DateTime.now(),
            isEdit: true,
            data: e),
    ]..sort((a, b) => a.time.compareTo(b.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _historyExpanded = !_historyExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Text('History',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(width: 8),
                Icon(
                    _historyExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textLight),
              ],
            ),
          ),
        ),
        if (_historyExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: items.isEmpty
                ? const Text('No reviews yet.',
                    style:
                        TextStyle(color: AppColors.textLight, fontSize: 13))
                : Column(
                    children: [
                      for (final item in items)
                        item.isEdit
                            ? _editHistoryEntry(item.data)
                            : _historyApprovalEntry(item.data),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _discussionTile(
      Map<String, dynamic> comment, List<Map<String, dynamic>> replies) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _discussionEntry(comment),
          for (final r in replies)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 10),
              child: _discussionEntry(r),
            ),
        ],
      ),
    );
  }

  Widget _discussionEntry(Map<String, dynamic> c) {
    final name = (c['profiles']?['full_name'] as String?) ?? 'Specialist';
    final photoUrl = c['profiles']?['profile_picture_url'] as String?;
    final isAuthorComment = c['author_id'] == _content!['created_by'];
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.rose.withValues(alpha: 0.15),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.roseDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.textLight.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${isAuthorComment ? '★ ' : ''}$name',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(createdAt != null ? _timeAgo(createdAt) : '',
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11)),
                ]),
                const SizedBox(height: 2),
                Text(c['body'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textMid, fontSize: 13)),
                if (_content!['status'] != 'published')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () => _startReply(c),
                      child: const Text('Reply',
                          style: TextStyle(
                              color: AppColors.teal,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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
    final generalComments =
        _comments.where((c) => c['approval_id'] == null).toList();
    final topLevelComments =
        generalComments.where((c) => c['parent_comment_id'] == null).toList();
    final generalRepliesByParent = <String, List<Map<String, dynamic>>>{};
    for (final c in generalComments) {
      final parentId = c['parent_comment_id'] as String?;
      if (parentId != null) {
        generalRepliesByParent.putIfAbsent(parentId, () => []).add(c);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Thread')),
      body: RefreshIndicator(
        color: AppColors.rose,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          children: [
            _headerCard(status),
            const SizedBox(height: 20),
            _actionsForStatus(status),
            const SizedBox(height: 20),
            _flaggedFeed(),
            const SizedBox(height: 20),
            _historySection(),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Discussion',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            if (status != 'published') ...[
              if (_replyingTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${(_replyingTo!['profiles']?['full_name'] as String?) ?? 'comment'}',
                                style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyingTo = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ),
                      // Matches the send IconButton's width below, so the
                      // close icon lands above the comment box's edge
                      // instead of overlapping the send button beneath it.
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? 'Write a reply...'
                            : 'Add a comment'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.rose),
                  onPressed: _postComment,
                ),
              ]),
              const SizedBox(height: 16),
            ],
            if (topLevelComments.isEmpty)
              const Text('No comments yet.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13))
            else
              ...topLevelComments.map((c) => _discussionTile(
                  c, generalRepliesByParent[c['id']] ?? [])),
          ],
        ),
      ),
    );
  }
}
