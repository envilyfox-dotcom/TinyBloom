import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/service_id.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';
import '../forum/forum_shared.dart';

// ── My Question — view (and, while pending, amend) a question the mum
// posted to the open volunteer Q&A board.
class VolunteerQuestionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const VolunteerQuestionDetailScreen({super.key, required this.request});

  @override
  State<VolunteerQuestionDetailScreen> createState() =>
      _VolunteerQuestionDetailScreenState();
}

class _VolunteerQuestionDetailScreenState
    extends State<VolunteerQuestionDetailScreen> {
  late final TextEditingController _ctrl;
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _editing = false;
  bool _saving = false;
  bool _sending = false;
  bool _loadingThread = true;
  List<Map<String, dynamic>> _messages = [];
  String? _myPhotoUrl;
  String? _volunteerPhotoUrl;
  bool _respondingToCall = false;

  bool get _isClosed => widget.request['status'] == 'closed';
  String get _callStatus => widget.request['call_status'] as String? ?? 'none';
  String? get _meetingLink => widget.request['meeting_link'] as String?;
  DateTime? get _scheduledDate =>
      DateTime.tryParse(widget.request['scheduled_date']?.toString() ?? '');
  String? get _scheduledTime => widget.request['scheduled_time'] as String?;
  // Amending the original question is only sensible before anyone's
  // claimed it — once a volunteer is chatting (or the chat's closed),
  // changing the question out from under the conversation would be
  // confusing, and RLS blocks it server-side too.
  bool get _canEdit => widget.request['status'] == 'pending';
  String? get _myId => SupabaseService.currentUser?.id;
  // A volunteer has claimed this thread once volunteer_id is set — only
  // then is there anyone on the other end for a follow-up to reach.
  bool get _hasVolunteer => widget.request['volunteer_id'] != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.request['question'] as String? ?? '');
    _loadThread();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    try {
      // Re-fetch the request itself (not just messages) so this screen
      // picks up status/volunteer_id changes made elsewhere — the
      // volunteer closing the chat, or the 48h auto-close kicking in.
      final fresh = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .eq('id', widget.request['id'])
          .maybeSingle();
      if (fresh != null) {
        final freshRow = Map<String, dynamic>.from(fresh);
        await SupabaseService.autoCloseStaleRequests([freshRow]);
        await SupabaseService.expireStaleCallRequests([freshRow]);
        widget.request['volunteer_id'] = freshRow['volunteer_id'];
        widget.request['status'] = freshRow['status'];
        widget.request['question'] = freshRow['question'];
        widget.request['call_status'] = freshRow['call_status'];
        widget.request['meeting_link'] = freshRow['meeting_link'];
        widget.request['scheduled_date'] = freshRow['scheduled_date'];
        widget.request['scheduled_time'] = freshRow['scheduled_time'];
      }
      final msgs = await SupabaseService.getRequestMessages(
          widget.request['id'].toString());
      if (_myPhotoUrl == null && _myId != null) {
        try {
          final me = await SupabaseService.getProfileById(_myId!);
          _myPhotoUrl = me?['profile_picture_url'] as String?;
        } catch (_) {}
      }
      final volunteerId = widget.request['volunteer_id'] as String?;
      if (_volunteerPhotoUrl == null && volunteerId != null) {
        try {
          final vol = await SupabaseService.getProfileById(volunteerId);
          _volunteerPhotoUrl = vol?['profile_picture_url'] as String?;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loadingThread = false;
        });
        _scrollToEnd();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendRequestMessage(
          widget.request['id'].toString(), text);
      _replyCtrl.clear();
      await _loadThread();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _acceptVideoCall() async {
    setState(() => _respondingToCall = true);
    try {
      await SupabaseService.acceptVideoCall(widget.request['id'].toString());
      widget.request['call_status'] = 'accepted';
      // Posted as a real chat message (not just the "waiting" banner,
      // which disappears once the volunteer sends the link) so the
      // agreed date/time stays visible in the thread for both sides.
      if (_scheduledDate != null && _scheduledTime != null) {
        await SupabaseService.sendRequestMessage(
            widget.request['id'].toString(),
            'You have accepted the video call for '
            '${DateFormat('d MMM yyyy').format(_scheduledDate!)} at $_scheduledTime.');
        await _loadThread();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _respondingToCall = false);
    }
  }

  Future<void> _declineVideoCall() async {
    setState(() => _respondingToCall = true);
    try {
      await SupabaseService.declineVideoCall(widget.request['id'].toString());
      widget.request['call_status'] = 'declined';
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _respondingToCall = false);
    }
  }

  // The volunteer's stored meeting_link keeps the whole pasted invite
  // (join link, meeting ID, passcode) rather than just a bare URL, so
  // pull out just the http(s) link to actually launch on tap.
  static final _urlPattern = RegExp(r'https?://\S+');

  Future<void> _openMeetingLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the video call link.')));
    }
  }

  Widget _videoCallControl() {
    switch (_callStatus) {
      case 'requested':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _scheduledDate != null && _scheduledTime != null
                        ? 'Your volunteer wants to start a video call on ${DateFormat('d MMM yyyy').format(_scheduledDate!)} at $_scheduledTime.'
                        : 'Your volunteer wants to start a video call.',
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _respondingToCall ? null : _declineVideoCall,
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TBButton(
                        label: 'Accept',
                        loading: _respondingToCall,
                        onPressed: _respondingToCall ? null : _acceptVideoCall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case 'accepted':
        if (_meetingLink == null || _meetingLink!.trim().isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                  'You accepted — waiting for your volunteer to send the video call link.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            ),
          );
        }
        // Once a link's been sent, the "Join Call" button attached to
        // that message in the thread (see _messageTile) is enough — no
        // need for a second, persistent one down here too.
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your question can\'t be empty.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.updateVolunteerQuestion(
          widget.request['id'].toString(), text);
      setState(() {
        widget.request['question'] = text;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Question updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _messageTile(Map<String, dynamic> msg) {
    final mine = msg['sender_id'] == _myId;
    final name = mine ? 'You' : 'Volunteer';
    final photo = mine ? _myPhotoUrl : _volunteerPhotoUrl;
    final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '');
    final text = msg['message'] as String? ?? '';
    final messageLink = _urlPattern.firstMatch(text)?.group(0);

    final volunteerId = widget.request['volunteer_id']?.toString();

    Widget avatar = CircleAvatar(
      radius: 14,
      backgroundColor:
          mine ? AppColors.rose.withValues(alpha: 0.15) : AppColors.tealLight,
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? CachedNetworkImageProvider(photo, maxWidth: 200)
          : null,
      child: (photo == null || photo.isEmpty)
          ? Text(name[0],
              style: TextStyle(
                  color: mine ? AppColors.roseDeep : AppColors.teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 11))
          : null,
    );

    if (!mine && volunteerId != null) {
      avatar = GestureDetector(
        onTap: () =>
            context.push('/volunteer/profile-view', extra: volunteerId),
        child: avatar,
      );
    }

    final textBlock = Expanded(
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 6),
              Text(createdAt != null ? timeAgo(createdAt) : '',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(text,
              textAlign: mine ? TextAlign.right : TextAlign.left,
              style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
          if (messageLink != null) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _openMeetingLink(messageLink),
              icon: const Icon(Icons.videocam, size: 14),
              label: const Text('Join Call', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine
            ? [textBlock, const SizedBox(width: 10), avatar]
            : [avatar, const SizedBox(width: 10), textBlock],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.request['status'] as String? ?? 'pending';
    final isCompleted = _isClosed;
    final requestId = formatRequestId(widget.request['request_number']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Question'),
        actions: [
          if (_canEdit && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textDark),
              tooltip: 'Amend question',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TBCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _editing
                            ? TextField(
                                controller: _ctrl,
                                maxLines: 5,
                                autofocus: true,
                                style: const TextStyle(fontSize: 15),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              )
                            : Text(widget.request['question'] as String? ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (!_editing) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                (isCompleted ? AppColors.sage : AppColors.gold)
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCompleted ? 'Completed' : 'Ongoing',
                            style: TextStyle(
                                color: isCompleted
                                    ? AppColors.sage
                                    : AppColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!_editing && requestId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Request ID: $requestId',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 11)),
                  ],
                  if (_editing) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _editing = false;
                                      _ctrl.text = widget.request['question']
                                              as String? ??
                                          '';
                                    }),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TBButton(
                            label: 'Save',
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: _loadingThread
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.rose))
                : _messages.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: TBEmptyState(
                          emoji: statusEmoji(status),
                          title: 'Waiting for a response',
                          subtitle:
                              'A community volunteer will reply here once they\'ve seen your question. You can still edit it until then.',
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _messageTile(_messages[i]),
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
            child: _isClosed
                ? const Text('This chat has been closed.',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_hasVolunteer)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                              'No volunteer has picked this up yet — they\'ll see anything you add here once they do.',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 11)),
                        ),
                      _videoCallControl(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyCtrl,
                              maxLines: 4,
                              minLines: 1,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: const TextStyle(
                                    color: AppColors.textLight, fontSize: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppColors.textLight
                                          .withValues(alpha: 0.3)),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(
                                      color: AppColors.rose, width: 1.5),
                                ),
                                filled: true,
                                fillColor: AppColors.cream,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: _sending ? null : _sendReply,
                            style: IconButton.styleFrom(
                                backgroundColor: AppColors.rose,
                                padding: const EdgeInsets.all(14)),
                            icon: _sending
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send,
                                    color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
