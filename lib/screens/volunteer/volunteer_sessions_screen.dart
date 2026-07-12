import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
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
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('consultations')
          .select()
          .eq('specialist_id', SupabaseService.currentUser!.id)
          .order('scheduled_date');
      // A mum's booking (has a patient_id) only belongs here once it's been
      // accepted — while pending it's a request, surfaced on the Request tab
      // instead, so it doesn't show as a session before it's confirmed.
      // A declined/cancelled booking never becomes a session at all.
      final sessions = List<Map<String, dynamic>>.from(data).where((s) {
        final isBooking = s['patient_id'] != null;
        if (!isBooking) return true;
        final status = s['status'] as String? ?? 'pending';
        return status != 'pending' && status != 'cancelled';
      }).toList();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _upcoming => _sessions.where((s) {
        final d = DateTime.tryParse(s['scheduled_date']?.toString() ?? '');
        return d != null && d.isAfter(DateTime.now());
      }).toList();

  List<Map<String, dynamic>> get _past => _sessions.where((s) {
        final d = DateTime.tryParse(s['scheduled_date']?.toString() ?? '');
        return d != null && d.isBefore(DateTime.now());
      }).toList();

  List<Map<String, dynamic>> get _completed => _sessions
      .where((s) => (s['status'] as String? ?? '') == 'completed')
      .toList();

  Future<void> _markCompleted(String id) async {
    try {
      await SupabaseService.updateConsultationStatus(id, 'completed');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

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
        title: Text(widget.completedOnly ? 'Completed Sessions' : 'My Sessions',
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
                  Tab(text: 'Past'),
                  Tab(text: 'Completed'),
                ],
              ),
      ),
      floatingActionButton: widget.completedOnly
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.rose,
              onPressed: () async {
                await context.push('/volunteer/sessions/new');
                _load();
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.rose))
          : widget.completedOnly
              ? _SessionList(sessions: _completed, onRefresh: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SessionList(sessions: _upcoming, onRefresh: _load),
                    _SessionList(
                        sessions: _past,
                        onRefresh: _load,
                        onMarkCompleted: _markCompleted),
                    _SessionList(sessions: _completed, onRefresh: _load),
                  ],
                ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final Future<void> Function() onRefresh;
  final void Function(String id)? onMarkCompleted;

  const _SessionList(
      {required this.sessions, required this.onRefresh, this.onMarkCompleted});

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
        itemBuilder: (ctx, i) {
          final session = sessions[i];
          // A mum's booking gets the same rich "Patient details" card used on
          // the Request tab; a self-published session keeps the simple card.
          if (session['patient_id'] != null) {
            return BookingDetailCard(
              request: session,
              onUpdated: onRefresh,
              onMarkCompleted: onMarkCompleted,
            );
          }
          return _SessionCard(session: session, onMarkCompleted: onMarkCompleted);
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final void Function(String id)? onMarkCompleted;

  const _SessionCard({required this.session, this.onMarkCompleted});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(session['scheduled_date']?.toString() ?? '');
    final dateStr =
        date != null ? DateFormat('d MMM yyyy').format(date) : 'TBD';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session['purpose'] ?? 'Session',
              style: GoogleFonts.poppins(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(dateStr,
                style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
            const SizedBox(width: 12),
            Icon(Icons.access_time, size: 13, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(session['scheduled_time'] ?? '',
                style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
          ]),
          if (session['meeting_link'] != null &&
              session['meeting_link'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(session['meeting_link'],
                style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
          ],
          if (onMarkCompleted != null &&
              (session['status'] as String? ?? '') != 'completed') ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => onMarkCompleted!(session['id'] as String),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose,
                  side: BorderSide(color: AppColors.rose),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Mark as Completed',
                    style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── New Session Form ──────────────────────────────────────────────────────────

class NewVolunteerSessionScreen extends StatefulWidget {
  const NewVolunteerSessionScreen({super.key});

  @override
  State<NewVolunteerSessionScreen> createState() =>
      _NewVolunteerSessionScreenState();
}

class _NewVolunteerSessionScreenState extends State<NewVolunteerSessionScreen> {
  final _topicCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _timeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.rose),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _publish() async {
    if (_topicCtrl.text.isEmpty || _date == null || _timeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in topic, date and time.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('consultations').insert({
        'specialist_id': SupabaseService.currentUser!.id,
        'consultation_type': 'volunteer',
        'purpose': _topicCtrl.text.trim(),
        'scheduled_date': _date!.toIso8601String().split('T').first,
        'scheduled_time': _timeCtrl.text.trim(),
        'meeting_link': _remarksCtrl.text.trim(),
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Session published!')));
        context.pop();
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
        title: Text('New Session',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New Consultation',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _field('Consultation Topic', _topicCtrl),
              const SizedBox(height: 12),
              // Date picker
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date',
                      style:
                          GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.textLight.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _date != null
                            ? DateFormat('d MMM yyyy').format(_date!)
                            : 'Select Date',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _date != null
                                ? AppColors.textDark
                                : AppColors.textLight),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field('Time (e.g. 8pm, 1hr)', _timeCtrl),
              const SizedBox(height: 12),
              _field('Remarks / Zoom link', _remarksCtrl, maxLines: 3),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
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
                    : Text('Publish Session',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.textLight.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.textLight.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.rose, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
