import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../mum/consultation/consultation_helpers.dart';
import 'volunteer_requests_screen.dart';

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
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  int _completedSessionsCount = 0;
  int _mumsHelpedCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    Map<String, dynamic>? profile;
    List<Map<String, dynamic>> sessions = [];
    List<Map<String, dynamic>> requests = [];

    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}

    try {
      final data = await SupabaseService.client
          .from('consultations')
          .select()
          .eq('specialist_id', SupabaseService.currentUser!.id)
          .gte('scheduled_date',
              DateTime.now().toIso8601String().split('T').first)
          .order('scheduled_date');
      final now = DateTime.now();
      // A mum's booking only counts as an upcoming consultation once it's
      // been accepted — while pending it belongs on the Request tab instead,
      // and a declined/cancelled one never counts as a session at all. A
      // same-day appointment whose time has already passed isn't "upcoming"
      // either, even though its date still matches today.
      sessions = List<Map<String, dynamic>>.from(data).where((s) {
        final isBooking = s['patient_id'] != null;
        if (isBooking) {
          final status = s['status'] as String? ?? 'pending';
          if (status == 'pending' || status == 'cancelled') return false;
        }
        final date = DateTime.tryParse(s['scheduled_date']?.toString() ?? '');
        if (date == null) return false;
        final timeStr = s['scheduled_time'] as String?;
        final at = timeStr != null ? slotDateTime(date, timeStr) : null;
        return (at ?? date).isAfter(now);
      }).take(5).toList();
    } catch (_) {}

    try {
      // Open Q&A board — every volunteer sees every unclaimed question plus
      // any they've personally claimed, not just ones directed at them
      // specifically. "Ongoing" here matches the Request page's Ongoing tab:
      // anything not yet closed, whether unclaimed or actively being
      // chatted about. patient_id references auth.users, not
      // public.profiles, so there's no FK for PostgREST to auto-embed
      // profiles(full_name) through — look the name up separately.
      final data = await SupabaseService.client
          .from('volunteer_requests')
          .select()
          .neq('status', 'closed')
          .order('created_at', ascending: false)
          .limit(5);
      final rows = List<Map<String, dynamic>>.from(data);
      await SupabaseService.autoCloseStaleRequests(rows);
      rows.removeWhere((r) => r['status'] == 'closed');

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

    int completedCount = 0;
    int mumsHelpedCount = 0;
    try {
      final data = await SupabaseService.client
          .from('consultations')
          .select('patient_id')
          .eq('specialist_id', SupabaseService.currentUser!.id)
          .eq('status', 'completed');
      final rows = List<Map<String, dynamic>>.from(data);
      completedCount = rows.length;
      mumsHelpedCount = rows
          .map((r) => r['patient_id'] as String?)
          .whereType<String>()
          .toSet()
          .length;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _profile = profile;
        _upcomingSessions = sessions;
        _pendingRequests = requests;
        _completedSessionsCount = completedCount;
        _mumsHelpedCount = mumsHelpedCount;
        _loading = false;
      });
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.poppins(fontSize: 14, color: _roseDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: _roseDark)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                Text('Logout', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
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
                      _buildTopBar(context),
                      const SizedBox(height: 20),
                      _buildGreeting(firstName),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildQuickActions(context),
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

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 32,
          errorBuilder: (_, __, ___) => Text(
            'TinyBloom',
            style: GoogleFonts.poppins(
                color: _pink, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        // Logout button — top right per wireframe
        TextButton(
          onPressed: () => _logout(context),
          style: TextButton.styleFrom(
            foregroundColor: _roseDark,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: Text(
            'Logout',
            style: GoogleFonts.poppins(
                fontSize: 13, color: _roseDark, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hi, $firstName 👋',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        Text('Thank you for supporting mums today.',
            style: GoogleFonts.poppins(fontSize: 13, color: _roseDark)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('Sessions\nCompleted', '$_completedSessionsCount',
            Icons.check_circle_outline,
            onTap: () => context
                .push('/volunteer/sessions', extra: {'completedOnly': true})),
        const SizedBox(width: 12),
        _statCard('Mums\nHelped', '$_mumsHelpedCount', Icons.favorite_outline,
            onTap: () => context.push('/volunteer/mums-helped')),
        const SizedBox(width: 12),
        _statCard('Ongoing\nRequests', '${_pendingRequests.length}',
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

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        Row(
          children: [
            _actionButton(context, 'My Consultations',
                Icons.calendar_today_outlined, '/volunteer/sessions'),
            const SizedBox(width: 12),
            _actionButton(context, 'Requests', Icons.inbox_outlined,
                '/volunteer/requests'),
            const SizedBox(width: 12),
            _actionButton(context, 'Forum', Icons.forum_outlined, '/forum'),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(
      BuildContext context, String label, IconData icon, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
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
              Icon(icon, color: _pink, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500)),
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
          ..._upcomingSessions.map((s) => _sessionCard(s)),
      ],
    );
  }

  Widget _sessionCard(Map<String, dynamic> session) {
    final date = session['scheduled_date'] != null
        ? DateTime.tryParse(session['scheduled_date'].toString())
        : null;
    final dateStr =
        date != null ? '${date.day}/${date.month}/${date.year}' : 'TBD';
    return Container(
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
                Text(session['purpose'] ?? 'Consultation',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textDark)),
                Text('$dateStr · ${session['scheduled_time'] ?? ''}',
                    style: GoogleFonts.poppins(fontSize: 11, color: _roseDark)),
              ],
            ),
          ),
        ],
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
