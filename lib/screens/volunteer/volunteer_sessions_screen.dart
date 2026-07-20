import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/service_id.dart';
import '../mum/consultation/consultation_helpers.dart';
import 'volunteer_requests_screen.dart';

class VolunteerSessionsScreen extends StatefulWidget {
  final int initialTab;
  final bool completedOnly;
  const VolunteerSessionsScreen(
      {super.key, this.initialTab = 0, this.completedOnly = false});

  @override
  State<VolunteerSessionsScreen> createState() =>
      _VolunteerSessionsScreenState();
}

class _VolunteerSessionsScreenState extends State<VolunteerSessionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // Sessions here are video calls requested in an ask-a-volunteer chat
  // thread — a call only becomes a session once the mum has accepted it;
  // a pending or declined request stays in the chat only.
  Future<void> _load() async {
    try {
      final callRows = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .eq('call_status', 'accepted')
          .order('last_activity_at', ascending: false);
      final calls = List<Map<String, dynamic>>.from(callRows);
      await Future.wait(calls.map((c) async {
        final patientId = c['patient_id'] as String?;
        if (patientId == null) return;
        Map<String, dynamic>? profile;
        Map<String, dynamic>? pregnancy;
        try {
          profile = await SupabaseService.getProfileById(patientId);
        } catch (_) {}
        try {
          pregnancy = await SupabaseService.getPregnancyProfileByUserId(patientId);
        } catch (_) {}
        c['_mumName'] = profile?['full_name'] as String?;
        c['_mumPhoto'] = profile?['profile_picture_url'] as String?;
        c['_mumAge'] = (pregnancy?['age'] as num?)?.toString() ??
            profile?['age']?.toString();
        c['_mumWeek'] = SupabaseService.pregnancyWeekFromProfile(pregnancy);
      }));

      if (mounted) {
        setState(() {
          _sessions = calls;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _upcoming =>
      _sessions.where((s) => (s['status'] as String? ?? '') != 'closed').toList();

  List<Map<String, dynamic>> get _completed => _sessions
      .where((s) => (s['status'] as String? ?? '') == 'closed')
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
        title: Text(
            widget.completedOnly ? 'Completed Consultations' : 'Consultations',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
        bottom: widget.completedOnly
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: AppColors.rose,
                labelColor: AppColors.rose,
                unselectedLabelColor: AppColors.textLight,
                labelStyle: GoogleFonts.poppins(fontSize: 13),
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.rose))
          : widget.completedOnly
              ? _SessionList(sessions: _completed, onRefresh: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SessionList(sessions: _upcoming, onRefresh: _load),
                    _SessionList(sessions: _completed, onRefresh: _load),
                  ],
                ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final Future<void> Function() onRefresh;

  const _SessionList({required this.sessions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text('No sessions here yet.',
            style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: AppColors.rose,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) =>
            _VideoCallSessionCard(session: sessions[i], onRefresh: onRefresh),
      ),
    );
  }
}

// A video call from an ask-a-volunteer chat thread, once the mum has
// accepted it. Tapping the card (or "Send meeting link") opens the chat
// itself, so there's one place — RequestDetailScreen — that owns pasting
// and updating the Zoom link rather than duplicating that here.
class _VideoCallSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final Future<void> Function() onRefresh;

  const _VideoCallSessionCard({required this.session, required this.onRefresh});

  Future<void> _openChat(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RequestDetailScreen(request: session)),
      ).then((_) => onRefresh());

  // meeting_link holds the whole pasted invite (join link, meeting ID,
  // passcode), not just a bare URL, so pull out just the http(s) link to
  // actually launch on tap.
  static final _urlPattern = RegExp(r'https?://\S+');

  Future<void> _joinCall(BuildContext context) async {
    final text = session['meeting_link']?.toString().trim() ?? '';
    final match = _urlPattern.firstMatch(text)?.group(0);
    final uri = match != null ? Uri.tryParse(match) : null;
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the video call link.')));
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
    final mumName = session['_mumName'] as String? ?? 'A mum';
    final photoUrl = session['_mumPhoto'] as String?;
    final age = session['_mumAge'] as String?;
    final week = session['_mumWeek'] as int? ?? 0;
    final isClosed = session['status'] == 'closed';
    final meetingLink = session['meeting_link'] as String?;
    final hasLink = meetingLink != null && meetingLink.trim().isNotEmpty;
    final scheduledDate =
        DateTime.tryParse(session['scheduled_date']?.toString() ?? '');
    final dateStr =
        scheduledDate != null ? DateFormat('d MMMM yyyy').format(scheduledDate) : '—';
    final timeStr = session['scheduled_time'] as String? ?? '—';
    // "Confirmed"/"Completed" mirror the legacy booking card's status
    // vocabulary so the two card types read consistently in this list.
    final statusKey = isClosed ? 'completed' : 'confirmed';

    return GestureDetector(
      onTap: () => _openChat(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.22)),
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
                      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl != null
                          ? null
                          : Text(
                              mumName.isNotEmpty ? mumName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _infoLine(
                    'Request ID', formatRequestId(session['request_number'])),
                _infoLine('Name', mumName),
                _infoLine('Age', age == null ? '—' : '$age yrs old'),
                _infoLine(
                    'Pregnancy',
                    week > 0
                        ? 'Week $week · ${trimesterLabel(week)}'
                        : '—'),
                _infoLine('Date', dateStr),
                _infoLine('Time', timeStr),
                _infoLine('Platform', 'Zoom Meeting'),
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
                            color: statusColor(statusKey).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                isClosed
                                    ? Icons.task_alt
                                    : Icons.check_circle_outline,
                                size: 13,
                                color: statusColor(statusKey)),
                            const SizedBox(width: 4),
                            Text(statusLabel(statusKey),
                                style: TextStyle(
                                    color: statusColor(statusKey),
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
                    'Descriptions: ${(session['question'] as String? ?? '').isEmpty ? 'No purpose specified.' : session['question']}',
                    style:
                        const TextStyle(color: AppColors.textMid, fontSize: 13)),
              ],
            ),
          ),
          if (!isClosed) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: hasLink
                  ? ElevatedButton(
                      onPressed: () => _joinCall(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24))),
                      child: const Text('Join Video Call',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    )
                  : OutlinedButton(
                      onPressed: () => _openChat(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: const BorderSide(color: AppColors.teal),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Send Meeting Link',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
