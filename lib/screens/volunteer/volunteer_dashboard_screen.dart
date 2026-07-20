import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/availability_format.dart';
import '../../utils/service_id.dart';
import '../mum/consultation/consultation_helpers.dart';
import 'volunteer_requests_screen.dart';
import 'volunteer_services_screen.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  static const _pink = AppColors.rose;
  static const _roseDark = AppColors.textLight;
  static const _bg = AppColors.background;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _volunteerProfile;
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _myServices = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  int _totalServicesCount = 0;
  int _totalConsultationsCount = 0;
  int _totalOngoingRequestsCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    Map<String, dynamic>? profile;
    Map<String, dynamic>? volunteerProfile;
    List<Map<String, dynamic>> sessions = [];
    List<Map<String, dynamic>> myServices = [];
    List<Map<String, dynamic>> requests = [];
    int totalServicesCount = 0;
    int totalConsultationsCount = 0;
    int totalOngoingRequestsCount = 0;

    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}

    try {
      volunteerProfile = await SupabaseService.getMyVolunteerProfile();
    } catch (_) {}

    try {
      // Same source as the "My Consultations" tab: a video call from an
      // ask-a-volunteer chat thread, once the mum has accepted it and
      // before the chat's closed. A same-day call whose slot has already
      // passed isn't "upcoming" either, even though its date still
      // matches today.
      final data = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .eq('call_status', 'accepted')
          .neq('status', 'closed')
          .order('scheduled_date');
      final now = DateTime.now();
      final upcoming = List<Map<String, dynamic>>.from(data).where((r) {
        final date = DateTime.tryParse(r['scheduled_date']?.toString() ?? '');
        if (date == null) return false;
        final timeStr = r['scheduled_time'] as String?;
        final at = timeStr != null ? slotDateTime(date, timeStr) : null;
        return (at ?? date).isAfter(now);
      }).toList();
      totalConsultationsCount = upcoming.length;
      final rows = upcoming.take(5).toList();

      final patientIds = rows
          .map((r) => r['patient_id'] as String?)
          .whereType<String>()
          .toSet();
      final names = <String, String>{};
      await Future.wait(patientIds.map((id) async {
        try {
          final profile = await SupabaseService.getProfileById(id);
          final name = profile?['full_name'] as String?;
          if (name != null) names[id] = name;
        } catch (_) {}
      }));
      sessions =
          rows.map((r) => {...r, '_mumName': names[r['patient_id']]}).toList();
    } catch (_) {}

    try {
      // Sessions/services this volunteer has published themselves (e.g. a
      // Zoom talk), so they get a reminder + quick access from their own
      // dashboard rather than having to dig into the Services tab.
      final data = await SupabaseService.client
          .from('volunteer_services')
          .select()
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .eq('status', 'available');
      final rows = List<Map<String, dynamic>>.from(data);
      rows.sort((a, b) {
        final aDate = DateTime.tryParse(
            (a['availability'] as String? ?? '').split(' | ').first);
        final bDate = DateTime.tryParse(
            (b['availability'] as String? ?? '').split(' | ').first);
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
      totalServicesCount = rows.length;
      myServices = rows.take(5).toList();
    } catch (_) {}

    try {
      // "Ongoing" here matches the Request page's Ongoing tab: a request a
      // volunteer has actually claimed (volunteer_id set) and isn't closed
      // yet. Unclaimed questions are "Available" instead — they show up on
      // the Request page's Available tab, not counted here. patient_id
      // references auth.users, not public.profiles, so there's no FK for
      // PostgREST to auto-embed profiles(full_name) through — look the name
      // up separately.
      final data = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .neq('status', 'closed')
          .not('volunteer_id', 'is', null)
          .order('created_at', ascending: false);
      final allRows = List<Map<String, dynamic>>.from(data);
      await SupabaseService.autoCloseStaleRequests(allRows);
      await SupabaseService.expireStaleCallRequests(allRows);
      allRows.removeWhere((r) => r['status'] == 'closed');
      totalOngoingRequestsCount = allRows.length;
      final rows = allRows.take(5).toList();

      final patientIds = rows
          .map((r) => r['patient_id'] as String?)
          .whereType<String>()
          .toSet();
      final names = <String, String>{};
      await Future.wait(patientIds.map((id) async {
        try {
          final profile = await SupabaseService.getProfileById(id);
          final name = profile?['full_name'] as String?;
          if (name != null) names[id] = name;
        } catch (_) {}
      }));

      requests = rows
          .map((r) => {
                ...r,
                'profiles': {'full_name': names[r['patient_id']]},
              })
          .toList();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _profile = profile;
        _volunteerProfile = volunteerProfile;
        _upcomingSessions = sessions;
        _myServices = myServices;
        _pendingRequests = requests;
        _totalServicesCount = totalServicesCount;
        _totalConsultationsCount = totalConsultationsCount;
        _totalOngoingRequestsCount = totalOngoingRequestsCount;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = _profile?['full_name'] as String? ??
        auth.profile?['full_name'] as String? ??
        'Volunteer';
    final firstName = name.split(' ').first;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _pink))
            : RefreshIndicator(
                color: _pink,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, firstName),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildMyServices(context),
                      const SizedBox(height: 24),
                      _buildUpcomingSessions(context),
                      const SizedBox(height: 24),
                      _buildPendingRequests(context),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  Widget _buildHeader(BuildContext context, String firstName) {
    final isVerified = _volunteerProfile?['is_verified'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_greeting, $firstName! 🌸',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMid, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.push('/volunteer/profile'),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _pink.withValues(alpha: 0.15),
                backgroundImage:
                    _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl != null
                    ? null
                    : Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'V',
                        style: const TextStyle(
                            color: AppColors.roseDeep,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isVerified ? Icons.verified : Icons.volunteer_activism,
                  color: AppColors.teal, size: 13),
              const SizedBox(width: 4),
              Text(isVerified ? 'Verified Volunteer' : 'Volunteer',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('Total\nServices', '$_totalServicesCount',
            Icons.medical_services_outlined,
            onTap: () => context.push('/volunteer/services')),
        const SizedBox(width: 12),
        _statCard('Total\nConsultations', '$_totalConsultationsCount',
            Icons.calendar_today_outlined,
            onTap: () => context.push('/volunteer/sessions')),
        const SizedBox(width: 12),
        _statCard('Total Ongoing\nRequests', '$_totalOngoingRequestsCount',
            Icons.inbox_outlined,
            onTap: () => context.push('/volunteer/requests')),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: _pink.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: _pink, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 10, color: _roseDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSessions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming Consultations',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            TextButton(
              onPressed: () => context.push('/volunteer/sessions'),
              child: Text('See all',
                  style: GoogleFonts.poppins(fontSize: 12, color: _pink)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_upcomingSessions.isEmpty)
          _emptyCard('No upcoming consultations.')
        else
          ..._upcomingSessions.map((s) => _sessionCard(context, s)),
      ],
    );
  }

  Widget _sessionCard(BuildContext context, Map<String, dynamic> session) {
    final date = session['scheduled_date'] != null
        ? DateTime.tryParse(session['scheduled_date'].toString())
        : null;
    final dateStr =
        date != null ? '${date.day}/${date.month}/${date.year}' : 'TBD';
    final mumName = session['_mumName'] as String? ?? 'A mum';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(request: session),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: _pink.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.video_call_outlined, color: _pink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Video call with $mumName',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textDark)),
                  Text('$dateStr · ${session['scheduled_time'] ?? ''}',
                      style:
                          GoogleFonts.poppins(fontSize: 11, color: _roseDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyServices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming Services',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            TextButton(
              onPressed: () => context.push('/volunteer/services'),
              child: Text('See all',
                  style: GoogleFonts.poppins(fontSize: 12, color: _pink)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_myServices.isEmpty)
          _emptyCard('No sessions posted yet. Tap + on the Services tab.')
        else
          ..._myServices.map((s) => _myServiceCard(context, s)),
      ],
    );
  }

  Widget _myServiceCard(BuildContext context, Map<String, dynamic> service) {
    final serviceId = formatServiceId(service['service_number']);
    final title = service['title'] as String? ?? 'Session';
    final availability = service['availability'] as String? ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ServiceFormScreen(mode: ServiceMode.edit, service: service),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: _pink.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_available_outlined,
                  color: AppColors.infoBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textDark)),
                  if (serviceId.isNotEmpty)
                    Text('Service ID: $serviceId',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _roseDark)),
                  if (availability.isNotEmpty)
                    Text(formatAvailabilityDisplay(availability),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _roseDark)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequests(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ongoing Requests',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            TextButton(
              onPressed: () => context.push('/volunteer/requests'),
              child: Text('See all',
                  style: GoogleFonts.poppins(fontSize: 12, color: _pink)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_pendingRequests.isEmpty)
          _emptyCard('No ongoing requests right now. 🎉')
        else
          ..._pendingRequests.map((r) => _requestCard(context, r)),
      ],
    );
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> request) {
    final mumName =
        (request['profiles'] as Map?)?['full_name'] as String? ?? 'A mum';
    final title = request['question'] as String? ?? '';
    final requestId = formatRequestId(request['request_number']);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(request: request),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: _pink.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            if (requestId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Request ID: $requestId',
                  style: GoogleFonts.poppins(
                      color: AppColors.textLight, fontSize: 11)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(mumName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _pink.withValues(alpha: 0.2)),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: _roseDark)),
    );
  }
}
