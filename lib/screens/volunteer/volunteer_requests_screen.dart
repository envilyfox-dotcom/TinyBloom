import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../mum/consultation/consultation_helpers.dart';
import '../mum/forum/forum_shared.dart';

// ── User Requests — open Q&A board ────────────────────────────────────────
// Any mum can post a question; any volunteer can see every question and
// reply to it (not tied to one specific volunteer).
class VolunteerRequestsScreen extends StatefulWidget {
  const VolunteerRequestsScreen({super.key});

  @override
  State<VolunteerRequestsScreen> createState() =>
      _VolunteerRequestsScreenState();
}

class _VolunteerRequestsScreenState extends State<VolunteerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _requests = [];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // patient_id references auth.users, not public.profiles, so
      // PostgREST has no FK to auto-embed profiles(full_name) through —
      // fetch the asker's name as a separate lookup instead.
      final data = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data);
      await SupabaseService.autoCloseStaleRequests(rows);
      await SupabaseService.expireStaleCallRequests(rows);

      final patientIds = rows
          .map((r) => r['patient_id'] as String?)
          .whereType<String>()
          .toSet();
      final names = <String, String>{};
      final photos = <String, String?>{};
      await Future.wait(patientIds.map((id) async {
        try {
          final profile = await SupabaseService.getProfileById(id);
          final name = profile?['full_name'] as String?;
          if (name != null) names[id] = name;
          photos[id] = profile?['profile_picture_url'] as String?;
        } catch (_) {}
      }));

      final requests = rows
          .map((r) => {
                ...r,
                'profiles': {
                  'full_name': names[r['patient_id']],
                  'profile_picture_url': photos[r['patient_id']],
                },
              })
          .toList();
      // Unclaimed questions need a volunteer most, so they surface first,
      // then actively-claimed ones, then completed ones sink to the
      // bottom — newest-first within each group.
      requests.sort((a, b) {
        final priorityCompare = _priority(a).compareTo(_priority(b));
        if (priorityCompare != 0) return priorityCompare;
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // A thread is "Completed" once closed (manually or via 48h auto-close).
  // Otherwise, "Available" means no volunteer has claimed it yet
  // (volunteer_id is still null — visible to every volunteer via RLS), and
  // "Ongoing" means a volunteer has claimed it and is actively chatting.
  String _category(Map<String, dynamic> r) {
    if ((r['status'] as String? ?? 'pending') == 'closed') return 'completed';
    return r['volunteer_id'] == null ? 'available' : 'ongoing';
  }

  int _priority(Map<String, dynamic> r) {
    switch (_category(r)) {
      case 'available':
        return 0;
      case 'ongoing':
        return 1;
      default:
        return 2;
    }
  }

  bool _matchesSearch(Map<String, dynamic> r) {
    if (_searchQuery.isEmpty) return true;
    final question = (r['question'] as String? ?? '').toLowerCase();
    final mumName =
        ((r['profiles'] as Map?)?['full_name'] as String? ?? '').toLowerCase();
    return question.contains(_searchQuery) || mumName.contains(_searchQuery);
  }

  List<Map<String, dynamic>> _filter(String category) => _requests
      .where((r) => _category(r) == category && _matchesSearch(r))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('User Requests',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.rose,
          labelColor: AppColors.rose,
          unselectedLabelColor: AppColors.textLight,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.rose))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search requests or mum\'s name',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textLight),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textLight, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.textLight, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color:
                                  AppColors.textLight.withValues(alpha: 0.3))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color:
                                  AppColors.textLight.withValues(alpha: 0.3))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.rose, width: 1.5)),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _RequestList(
                          requests: _filter('available'), onRefresh: _load),
                      _RequestList(
                          requests: _filter('ongoing'), onRefresh: _load),
                      _RequestList(
                          requests: _filter('completed'), onRefresh: _load),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Future<void> Function() onRefresh;

  const _RequestList({required this.requests, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text('No requests here.',
            style:
                GoogleFonts.poppins(color: AppColors.textLight, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: AppColors.rose,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _RequestCard(
          request: requests[i],
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Future<void> Function() onRefresh;

  const _RequestCard({required this.request, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final mumName =
        (request['profiles'] as Map?)?['full_name'] as String? ?? 'A mum';
    final status = request['status'] as String? ?? 'pending';
    final isCompleted = status == 'closed';
    final isAvailable = !isCompleted && request['volunteer_id'] == null;
    final badgeLabel =
        isCompleted ? 'Completed' : (isAvailable ? 'Available' : 'Ongoing');
    final badgeColor = isCompleted
        ? AppColors.sage
        : (isAvailable ? AppColors.infoBlue : AppColors.gold);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(request: request),
        ),
      ).then((_) => onRefresh()),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(request['question'] ?? '',
                      style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style: GoogleFonts.poppins(
                        color: badgeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(mumName,
                    style: GoogleFonts.poppins(
                        color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request Detail / Response Screen ─────────────────────────────────────────

class RequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _linkCtrl = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  // True once we discover (via a fresh fetch) that another volunteer
  // claimed this thread first — locks out further replies from this side.
  bool _lockedOut = false;
  String? _myPhotoUrl;
  bool _closing = false;
  bool _requestingCall = false;
  bool _sendingLink = false;

  String? get _myId => SupabaseService.currentUser?.id;
  String? get _volunteerId => widget.request['volunteer_id'] as String?;
  bool get _isMine => _volunteerId != null && _volunteerId == _myId;
  bool get _isOpen => _volunteerId == null;
  bool get _isClosed => widget.request['status'] == 'closed';
  bool get _canReply => !_lockedOut && !_isClosed && (_isOpen || _isMine);
  String get _callStatus => widget.request['call_status'] as String? ?? 'none';
  String? get _meetingLink => widget.request['meeting_link'] as String?;
  DateTime? get _scheduledDate =>
      DateTime.tryParse(widget.request['scheduled_date']?.toString() ?? '');
  String? get _scheduledTime => widget.request['scheduled_time'] as String?;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Re-fetch the request itself (not just messages) so a stale copy
      // passed in via navigation can't show outdated claim/status info —
      // e.g. if another volunteer claimed it since this list was loaded.
      final fresh = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .eq('id', widget.request['id'])
          .maybeSingle();
      if (fresh == null) {
        if (mounted)
          setState(() {
            _lockedOut = true;
            _loading = false;
          });
        return;
      }
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
      final msgs = await SupabaseService.getRequestMessages(
          widget.request['id'].toString());
      if (_myPhotoUrl == null && _myId != null) {
        try {
          final me = await SupabaseService.getProfileById(_myId!);
          _myPhotoUrl = me?['profile_picture_url'] as String?;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        _scrollToEnd();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_isOpen) {
        final claimed = await SupabaseService.claimAndReplyToRequest(
            widget.request['id'].toString(), text);
        if (!claimed) {
          if (mounted) {
            setState(() => _lockedOut = true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Another volunteer already answered this question.')));
          }
          return;
        }
        widget.request['volunteer_id'] = _myId;
        widget.request['status'] = 'responded';
      } else {
        await SupabaseService.sendRequestMessage(
            widget.request['id'].toString(), text);
      }
      _ctrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeChat() async {
    setState(() => _closing = true);
    try {
      await SupabaseService.closeRequestChat(widget.request['id'].toString());
      widget.request['status'] = 'closed';
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Chat closed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  // Video calls used to be pure "call me right now", which meant nothing
  // stopped a volunteer from ending up double-booked at the same time —
  // so requesting one now means proposing a specific slot instead.
  Future<(DateTime, String)?> _pickCallSlot() async {
    DateTime selectedDate = DateTime.now();
    String? selectedTime;
    // Slots this volunteer has already proposed to some mum (still
    // pending, not yet 48h stale) aren't offered again, so the same time
    // can't be double-proposed to two different mums at once.
    Set<String> heldTimes =
        await SupabaseService.getHeldCallTimesForDate(selectedDate);
    if (!mounted) return null;
    return showModalBottomSheet<(DateTime, String)?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final times =
              futureTimesForDate(defaultConsultationTimes, selectedDate)
                  .where((t) => !heldTimes.contains(t))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Propose a call time',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  Text('Date',
                      style: GoogleFonts.poppins(
                          color: AppColors.textMid, fontSize: 12)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        final newHeld =
                            await SupabaseService.getHeldCallTimesForDate(
                                picked);
                        setSheetState(() {
                          selectedDate = picked;
                          selectedTime = null;
                          heldTimes = newHeld;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.textLight.withValues(alpha: 0.3)),
                      ),
                      child: Text(DateFormat('d MMM yyyy').format(selectedDate),
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: AppColors.textDark)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Time',
                      style: GoogleFonts.poppins(
                          color: AppColors.textMid, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (times.isEmpty)
                    Text('No time slots left on this date — pick another day.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textLight))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: times
                          .map((t) => ChoiceChip(
                                label: Text(t),
                                selected: selectedTime == t,
                                onSelected: (_) =>
                                    setSheetState(() => selectedTime = t),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedTime == null
                          ? null
                          : () =>
                              Navigator.pop(ctx, (selectedDate, selectedTime!)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24))),
                      child: const Text('Request This Time'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _requestVideoCall() async {
    final slot = await _pickCallSlot();
    if (slot == null) return;
    setState(() => _requestingCall = true);
    try {
      await SupabaseService.requestVideoCall(
          widget.request['id'].toString(), slot.$1, slot.$2);
      widget.request['call_status'] = 'requested';
      widget.request['scheduled_date'] =
          slot.$1.toIso8601String().split('T').first;
      widget.request['scheduled_time'] = slot.$2;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Video call request sent — waiting for the mum to accept.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _requestingCall = false);
    }
  }

  // Volunteers tend to paste the whole Zoom invite (join link, chat link,
  // meeting ID, passcode) rather than just the URL, so the stored
  // meeting_link keeps all of that (displayed as-is to both sides) while
  // this pulls out just the http(s) link to actually launch on tap.
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

  // Posted into the chat as a normal message (so it appears in the
  // conversation like anything else either side sends) as well as saved
  // onto meeting_link (so the persistent "Join Video Call" button and the
  // My Sessions list keep working without scrolling back through history).
  Future<void> _sendMeetingLink() async {
    final pasted = _linkCtrl.text.trim();
    if (pasted.isEmpty) return;
    if (!_urlPattern.hasMatch(pasted)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t find a meeting link in what you pasted.')));
      return;
    }
    setState(() => _sendingLink = true);
    try {
      await SupabaseService.sendMeetingLink(
          widget.request['id'].toString(), pasted);
      await SupabaseService.sendRequestMessage(
          widget.request['id'].toString(), pasted);
      widget.request['meeting_link'] = pasted;
      _linkCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingLink = false);
    }
  }

  Widget _videoCallControl() {
    switch (_callStatus) {
      case 'requested':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.videocam_outlined,
                  size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Waiting for the mum to accept your video call request for ${_scheduledDate != null ? DateFormat('d MMM').format(_scheduledDate!) : ''} at ${_scheduledTime ?? ''}...',
                    style: GoogleFonts.poppins(
                        color: AppColors.textMid, fontSize: 12)),
              ),
            ],
          ),
        );
      case 'accepted':
        if (_meetingLink == null || _meetingLink!.trim().isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Mum accepted! Paste the Zoom invite (link, meeting ID, passcode — however much you\'ve got) to share it with her.',
                    style: GoogleFonts.poppins(
                        color: AppColors.textDark, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkCtrl,
                  minLines: 3,
                  maxLines: 8,
                  style: GoogleFonts.poppins(fontSize: 12),
                  decoration: InputDecoration(
                    hintText:
                        'Join Zoom Meeting\nhttps://zoom.us/j/...\n\nMeeting ID: 123 456 7890\nPasscode: abcd12',
                    hintStyle: GoogleFonts.poppins(fontSize: 12),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendingLink ? null : _sendMeetingLink,
                    icon: _sendingLink
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 16),
                    label: Text(_sendingLink ? 'Sending...' : 'Send to Mum',
                        style: GoogleFonts.poppins(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        // Once a link's been sent, the "Join Call" button attached to
        // that message in the thread (see _messageTile) is enough — no
        // need for a second, persistent one down here too.
        return const SizedBox.shrink();
      default:
        return OutlinedButton.icon(
          onPressed: _requestingCall ? null : _requestVideoCall,
          icon: _requestingCall
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.videocam_outlined, size: 16),
          label: Text(_requestingCall ? 'Requesting...' : 'Request Video Call',
              style: GoogleFonts.poppins(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.teal,
            side: const BorderSide(color: AppColors.teal),
          ),
        );
    }
  }

  Widget _messageTile(
      Map<String, dynamic> msg, String mumName, String? mumPhoto) {
    final mine = msg['sender_id'] == _myId;
    final name = mine ? 'You' : mumName;
    final photo = mine ? _myPhotoUrl : mumPhoto;
    final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '');
    final text = msg['message'] as String? ?? '';
    final messageLink = _urlPattern.firstMatch(text)?.group(0);

    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor:
          mine ? AppColors.rose.withValues(alpha: 0.15) : AppColors.tealLight,
      backgroundImage:
          (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
      child: (photo == null || photo.isEmpty)
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: mine ? AppColors.roseDeep : AppColors.teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 11))
          : null,
    );

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
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 6),
              Text(createdAt != null ? timeAgo(createdAt) : '',
                  style: GoogleFonts.poppins(
                      color: AppColors.textLight, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(text,
              textAlign: mine ? TextAlign.right : TextAlign.left,
              style:
                  GoogleFonts.poppins(color: AppColors.textMid, fontSize: 13)),
          if (messageLink != null) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _openMeetingLink(messageLink),
              icon: const Icon(Icons.videocam, size: 14),
              label:
                  Text('Join Call', style: GoogleFonts.poppins(fontSize: 12)),
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
    final mumProfile = widget.request['profiles'] as Map?;
    final mumName = mumProfile?['full_name'] as String? ?? 'A mum';
    final mumPhoto = mumProfile?['profile_picture_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('User Request',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.rose))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.18)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.request['question'] ?? '',
                            style: GoogleFonts.poppins(
                                color: AppColors.textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.circle,
                              size: 6, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(mumName,
                              style: GoogleFonts.poppins(
                                  color: AppColors.textLight, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                              _isOpen
                                  ? 'No one has replied yet — be the first!'
                                  : 'No messages yet.',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textLight, fontSize: 13)))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) =>
                              _messageTile(_messages[i], mumName, mumPhoto),
                        ),
                ),
                if (_canReply)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isMine)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _videoCallControl(),
                          ),
                        if (_isMine)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OutlinedButton.icon(
                              onPressed: _closing ? null : _closeChat,
                              icon: _closing
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline,
                                      size: 16),
                              label: Text(
                                  _closing ? 'Closing...' : 'Close Chat',
                                  style: GoogleFonts.poppins(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.roseDeep,
                                side:
                                    const BorderSide(color: AppColors.roseDeep),
                              ),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                maxLines: 4,
                                minLines: 1,
                                style: GoogleFonts.poppins(
                                    color: AppColors.textDark, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: _isOpen
                                      ? 'Type your response...'
                                      : 'Type a message...',
                                  hintStyle: GoogleFonts.poppins(
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
                              onPressed: _sending ? null : _send,
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
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        _isClosed
                            ? 'This chat has been closed.'
                            : (_lockedOut
                                ? 'Another volunteer already answered this question.'
                                : 'This question was claimed by another volunteer.'),
                        style: GoogleFonts.poppins(
                            color: AppColors.textLight, fontSize: 12)),
                  ),
              ],
            ),
    );
  }
}
