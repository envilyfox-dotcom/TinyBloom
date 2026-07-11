import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../mum/consultation/consultation_helpers.dart';

class VolunteerRequestsScreen extends StatefulWidget {
  const VolunteerRequestsScreen({super.key});

  @override
  State<VolunteerRequestsScreen> createState() =>
      _VolunteerRequestsScreenState();
}

class _VolunteerRequestsScreenState extends State<VolunteerRequestsScreen>
    with SingleTickerProviderStateMixin {
  static const _pink = Color(0xFFE8A0B4);
  static const _roseDark = Color(0xFF9B8B86);
  static const _cardBg = Color(0xFFCB9189);

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
    final merged = <Map<String, dynamic>>[];

    try {
      final data = await SupabaseService.client
          .from('volunteer_requests')
          .select('*, profiles(full_name)')
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .order('created_at', ascending: false);
      merged.addAll(List<Map<String, dynamic>>.from(data)
          .map((r) => {...r, '_kind': 'question'}));
    } catch (_) {}

    try {
      final bookings = await SupabaseService.client
          .from('consultations')
          .select()
          .eq('specialist_id', SupabaseService.currentUser!.id)
          .eq('consultation_type', 'volunteer')
          .not('patient_id', 'is', null)
          .order('created_at', ascending: false);
      final bookingList = List<Map<String, dynamic>>.from(bookings);

      final patientIds =
          bookingList.map((b) => b['patient_id'] as String?).whereType<String>().toSet();
      final names = <String, String>{};
      await Future.wait(patientIds.map((id) async {
        try {
          final profile = await SupabaseService.getProfileById(id);
          final name = profile?['full_name'] as String?;
          if (name != null) names[id] = name;
        } catch (_) {}
      }));

      merged.addAll(bookingList.map((b) => {
            ...b,
            '_kind': 'booking',
            '_mumName': names[b['patient_id']] ?? 'A mum',
          }));
    } catch (_) {}

    merged.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    if (mounted) {
      setState(() {
        _requests = merged;
        _loading = false;
      });
    }
  }

  bool _isPending(Map<String, dynamic> r) =>
      (r['status'] as String? ?? 'pending') == 'pending';

  List<Map<String, dynamic>> _filter(bool pending) =>
      _requests.where((r) => _isPending(r) == pending).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF6B4A46)),
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
                fontWeight: FontWeight.w600, color: const Color(0xFF6B4A46))),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _pink,
          labelColor: _pink,
          unselectedLabelColor: _roseDark,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Responded'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : TabBarView(
              controller: _tabs,
              children: [
                _RequestList(
                    requests: _requests, cardBg: _cardBg, onRefresh: _load),
                _RequestList(
                    requests: _filter(true), cardBg: _cardBg, onRefresh: _load),
                _RequestList(
                    requests: _filter(false),
                    cardBg: _cardBg,
                    onRefresh: _load),
              ],
            ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Color cardBg;
  final Future<void> Function() onRefresh;

  const _RequestList(
      {required this.requests, required this.cardBg, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text('No requests here.',
            style: GoogleFonts.poppins(
                color: const Color(0xFF9B8B86), fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFE8A0B4),
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) =>
            _RequestCard(request: requests[i], cardBg: cardBg),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Color cardBg;

  const _RequestCard({required this.request, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final isBooking = request['_kind'] == 'booking';
    final mumName = isBooking
        ? (request['_mumName'] as String? ?? 'A mum')
        : (request['profiles'] as Map?)?['full_name'] as String? ?? 'A mum';
    final status = request['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final title = isBooking
        ? '📅 Booking · ${request['purpose'] ?? 'Consultation'}'
        : (request['question'] ?? '');
    final badgeLabel = isBooking ? statusLabel(status) : (isPending ? 'Pending' : 'Responded');
    final badgeColor = isBooking
        ? statusColor(status)
        : (isPending ? Colors.orange : Colors.green);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(request: request),
        ),
      ).then((_) {}),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.white70),
                const SizedBox(width: 4),
                Text(mumName,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12)),
                if (isBooking && request['scheduled_date'] != null) ...[
                  const SizedBox(width: 8),
                  Text(
                      '${DateFormat('d MMM').format(DateTime.tryParse(request['scheduled_date'].toString()) ?? DateTime.now())} · ${request['scheduled_time'] ?? ''}',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                ],
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
  static const _pink = Color(0xFFE8A0B4);
  static const _cardBg = Color(0xFFCB9189);

  final _ctrl = TextEditingController();
  bool _saving = false;
  // Requests loaded from the Request tab are tagged '_kind: booking'; a
  // consultation opened directly from the Consultation tab isn't tagged but
  // still carries a patient_id, so it reads as a booking too.
  bool get _isBooking =>
      widget.request['_kind'] == 'booking' ||
      widget.request['patient_id'] != null;

  @override
  void initState() {
    super.initState();
    if (widget.request['response'] != null) {
      _ctrl.text = widget.request['response'];
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isResponded => widget.request['status'] == 'responded';

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('volunteer_requests').update({
        'response': _ctrl.text.trim(),
        'status': 'responded',
      }).eq('id', widget.request['id']);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Response sent!')));
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    if (_isBooking) return _buildBookingDetail(context);

    final mumName =
        (widget.request['profiles'] as Map?)?['full_name'] as String? ??
            'A mum';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF6B4A46)),
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
                fontWeight: FontWeight.w600, color: const Color(0xFF6B4A46))),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.request['question'] ?? '',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.circle, size: 6, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(mumName,
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    enabled: !_isResponded,
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _isResponded ? null : 'Type your response...',
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isResponded) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Send Response',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetail(BuildContext context) {
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
        title: const Text('Booking Request',
            style:
                TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: BookingDetailCard(
          request: widget.request,
          onUpdated: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

// ── Booking Detail Card ──────────────────────────────────────────────────────
// The "Patient details" card shared between the Request tab's full-page
// detail screen and the Consultation tab's inline list, so both show the
// exact same layout instead of drifting apart.
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
  static const _pink = Color(0xFFE8A0B4);

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
        child: Center(child: CircularProgressIndicator(color: _pink)),
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
              _infoLine('Appointment ID', appointmentIdLabel(id)),
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
                      child: Text(statusLabel(status),
                          style: TextStyle(
                              color: statusColor(status),
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
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
