import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../mum/consultation/consultation_helpers.dart';
import '../mum/forum/forum_shared.dart';

// Used by BookingDetailCard below, which shows a mum's historical booking
// (a leftover from before the volunteer-scheduling feature was replaced by
// this open Q&A board) inline on the Consultation tab.
IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Icons.check_circle_outline;
    case 'completed':
      return Icons.task_alt;
    case 'cancelled':
      return Icons.cancel_outlined;
    case 'expired':
      return Icons.hourglass_bottom;
    default:
      return Icons.hourglass_empty;
  }
}

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
  List<Map<String, dynamic>> _requests = [];
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
      // Pending questions need action, so they surface first; everything
      // else stays sorted newest-first behind them.
      requests.sort((a, b) {
        final aPending = _isPending(a);
        final bPending = _isPending(b);
        if (aPending != bPending) return aPending ? -1 : 1;
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (aDate == null || bDate == null) return 0;
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

  bool _isPending(Map<String, dynamic> r) =>
      (r['status'] as String? ?? 'pending') == 'pending';

  List<Map<String, dynamic>> _filter(bool pending) =>
      _requests.where((r) => _isPending(r) == pending).toList();

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
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Responded'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.rose))
          : TabBarView(
              controller: _tabs,
              children: [
                _RequestList(requests: _requests, onRefresh: _load),
                _RequestList(requests: _filter(true), onRefresh: _load),
                _RequestList(requests: _filter(false), onRefresh: _load),
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
            style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 14)),
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
    final isPending = status == 'pending';
    final badgeLabel = isPending ? 'Pending' : 'Responded';
    final badgeColor = isPending ? AppColors.gold : AppColors.sage;

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
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  // True once we discover (via a fresh fetch) that another volunteer
  // claimed this thread first — locks out further replies from this side.
  bool _lockedOut = false;
  String? _myPhotoUrl;

  String? get _myId => SupabaseService.currentUser?.id;
  String? get _volunteerId => widget.request['volunteer_id'] as String?;
  bool get _isMine => _volunteerId != null && _volunteerId == _myId;
  bool get _isOpen => _volunteerId == null;
  bool get _canReply => !_lockedOut && (_isOpen || _isMine);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
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
        if (mounted) setState(() { _lockedOut = true; _loading = false; });
        return;
      }
      widget.request['volunteer_id'] = fresh['volunteer_id'];
      widget.request['status'] = fresh['status'];
      widget.request['question'] = fresh['question'];
      final msgs =
          await SupabaseService.getRequestMessages(widget.request['id'].toString());
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

  Widget _messageTile(Map<String, dynamic> msg, String mumName, String? mumPhoto) {
    final mine = msg['sender_id'] == _myId;
    final name = mine ? 'You' : mumName;
    final photo = mine ? _myPhotoUrl : mumPhoto;
    final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '');

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
          Text(msg['message'] ?? '',
              textAlign: mine ? TextAlign.right : TextAlign.left,
              style: GoogleFonts.poppins(
                  color: AppColors.textMid, fontSize: 13)),
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
                    child: Row(
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
                                    color:
                                        AppColors.textLight.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                borderSide:
                                    BorderSide(color: AppColors.rose, width: 1.5),
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
                              : const Icon(Icons.send, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        _lockedOut
                            ? 'Another volunteer already answered this question.'
                            : 'This question was claimed by another volunteer.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textLight, fontSize: 12)),
                  ),
              ],
            ),
    );
  }
}

// ── Booking Detail Card ──────────────────────────────────────────────────────
// Shows a mum's booking from before the volunteer-scheduling feature was
// replaced by the open Q&A board above. Kept only so the Consultation tab
// can still display historical bookings that were made under the old flow.
class BookingDetailCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onUpdated;
  final void Function(String id)? onMarkCompleted;
  const BookingDetailCard(
      {super.key, required this.request, this.onUpdated, this.onMarkCompleted});

  @override
  State<BookingDetailCard> createState() => _BookingDetailCardState();
}

class _BookingDetailCardState extends State<BookingDetailCard> {
  Map<String, dynamic>? _patientProfile;
  Map<String, dynamic>? _patientPregnancy;
  int _patientWeek = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patientId = widget.request['patient_id'] as String?;
    if (patientId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    Map<String, dynamic>? profile;
    Map<String, dynamic>? pregnancy;
    try {
      profile = await SupabaseService.getProfileById(patientId);
    } catch (_) {}
    try {
      pregnancy = await SupabaseService.getPregnancyProfileByUserId(patientId);
    } catch (_) {}
    // Derived from the same fetch above rather than a second round-trip via
    // getCurrentPregnancyWeekByUserId — two independent queries risked one
    // succeeding while the other failed, showing week but not age (or vice
    // versa) even though both live on the same pregnancy_profiles row.
    final week = SupabaseService.pregnancyWeekFromProfile(pregnancy);
    if (mounted) {
      setState(() {
        _patientProfile = profile;
        _patientPregnancy = pregnancy;
        _patientWeek = week;
        _loading = false;
      });
    }
  }

  Future<void> _acceptBooking() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.updateConsultationStatus(
          widget.request['id'].toString(), 'confirmed');
      if (mounted) {
        setState(() => widget.request['status'] = 'confirmed');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking confirmed!')));
        widget.onUpdated?.call();
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

  Future<void> _declineBooking() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.cancelConsultation(
          widget.request['id'].toString(),
          reason: 'Declined by volunteer');
      if (mounted) {
        setState(() => widget.request['status'] = 'cancelled');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking declined.')));
        widget.onUpdated?.call();
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

  Future<void> _startSession() async {
    final link = widget.request['meeting_link']?.toString().trim() ?? '';
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Zoom meeting link is not available yet.')));
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid Zoom meeting link.')));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Zoom meeting link.')));
    }
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textDark)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textMid)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.rose)),
      );
    }

    final r = widget.request;
    final id = r['id']?.toString() ?? '';
    final mumName = _patientProfile?['full_name'] as String? ??
        r['_mumName'] as String? ??
        'A mum';
    final patientAge = (_patientPregnancy?['age'] as num?)?.toString() ??
        _patientProfile?['age']?.toString() ??
        '—';
    final photoUrl = _patientProfile?['profile_picture_url'] as String?;
    final status = r['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';
    final dateStr = r['scheduled_date'] != null
        ? DateFormat('d MMMM yyyy')
            .format(DateTime.parse(r['scheduled_date'].toString()))
        : '—';
    final timeStr = r['scheduled_time'] as String? ?? '—';
    final purpose = r['purpose'] as String? ?? '';
    final platform = r['platform'] as String? ?? 'Zoom Meeting';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                  const Expanded(
                    child: Text('Patient details',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.textDark)),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl != null
                        ? null
                        : Text(
                            mumName.isNotEmpty ? mumName[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.roseDeep,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _infoLine('Appointment ID', appointmentIdLabel(id, 'volunteer')),
              _infoLine('Name', mumName),
              _infoLine('Age', patientAge == '—' ? '—' : '$patientAge yrs old'),
              _infoLine(
                  'Pregnancy',
                  _patientWeek > 0
                      ? 'Week $_patientWeek · ${trimesterLabel(_patientWeek)}'
                      : '—'),
              _infoLine('Date', dateStr),
              _infoLine('Time', timeStr),
              _infoLine('Platform', platform),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('Status: ',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor(status).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(status),
                              size: 13, color: statusColor(status)),
                          const SizedBox(width: 4),
                          Text(statusLabel(status),
                              style: TextStyle(
                                  color: statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  'Descriptions: ${purpose.isEmpty ? 'No purpose specified.' : purpose}',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isConfirmed) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startSession,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.roseDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24))),
              child: const Text('Start Session',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (widget.onMarkCompleted != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => widget.onMarkCompleted!(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.roseDeep,
                  side: const BorderSide(color: AppColors.roseDeep),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Mark as Completed'),
              ),
            ),
          ],
        ] else if (isPending)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _declineBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _acceptBooking,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.roseDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24))),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Accept Booking',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
