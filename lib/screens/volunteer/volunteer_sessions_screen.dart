import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';

class VolunteerSessionsScreen extends StatefulWidget {
  const VolunteerSessionsScreen({super.key});

  @override
  State<VolunteerSessionsScreen> createState() =>
      _VolunteerSessionsScreenState();
}

class _VolunteerSessionsScreenState extends State<VolunteerSessionsScreen>
    with SingleTickerProviderStateMixin {
  static const _pink = Color(0xFFE8A0B4);
  static const _roseDark = Color(0xFF9B8B86);
  static const _cardBg = Color(0xFFCB9189);

  late TabController _tabs;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
          .eq('provider_id', SupabaseService.currentUser!.id)
          .order('date');
      if (mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _upcoming => _sessions.where((s) {
        final d = DateTime.tryParse(s['date']?.toString() ?? '');
        return d != null && d.isAfter(DateTime.now());
      }).toList();

  List<Map<String, dynamic>> get _past => _sessions.where((s) {
        final d = DateTime.tryParse(s['date']?.toString() ?? '');
        return d != null && d.isBefore(DateTime.now());
      }).toList();

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
        title: Text('My Sessions',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: const Color(0xFF6B4A46))),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _pink,
          labelColor: _pink,
          unselectedLabelColor: _roseDark,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _pink,
        onPressed: () async {
          await context.push('/volunteer/sessions/new');
          _load();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : TabBarView(
              controller: _tabs,
              children: [
                _SessionList(
                    sessions: _upcoming, cardBg: _cardBg, onRefresh: _load),
                _SessionList(
                    sessions: _past, cardBg: _cardBg, onRefresh: _load),
              ],
            ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final Color cardBg;
  final Future<void> Function() onRefresh;

  const _SessionList(
      {required this.sessions, required this.cardBg, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text('No sessions here yet.',
            style: GoogleFonts.poppins(
                color: const Color(0xFF9B8B86), fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFE8A0B4),
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) =>
            _SessionCard(session: sessions[i], cardBg: cardBg),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final Color cardBg;

  const _SessionCard({required this.session, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(session['date']?.toString() ?? '');
    final dateStr =
        date != null ? DateFormat('d MMM yyyy').format(date) : 'TBD';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session['topic'] ?? 'Session',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(dateStr,
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 12),
            const Icon(Icons.access_time, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(session['time'] ?? '',
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ]),
          if (session['remarks'] != null &&
              session['remarks'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(session['remarks'],
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
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
  static const _pink = Color(0xFFE8A0B4);
  static const _cardBg = Color(0xFFCB9189);

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
          colorScheme: const ColorScheme.light(primary: _pink),
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
        'provider_id': SupabaseService.currentUser!.id,
        'provider_type': 'volunteer',
        'topic': _topicCtrl.text.trim(),
        'date': _date!.toIso8601String(),
        'time': _timeCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
        'status': 'available',
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
        title: Text('New Session',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: const Color(0xFF6B4A46))),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New Consultation',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
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
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _date != null
                            ? DateFormat('d MMM yyyy').format(_date!)
                            : 'Select Date',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _date != null
                                ? const Color(0xFF6B4A46)
                                : const Color(0xFF9B8B86)),
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
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6B4A46),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
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
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
