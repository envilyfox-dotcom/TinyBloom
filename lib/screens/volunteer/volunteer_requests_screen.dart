import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';

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
    try {
      final data = await SupabaseService.client
          .from('volunteer_requests')
          .select('*, profiles(full_name)')
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filter(String status) =>
      _requests.where((r) => r['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF6B4A46)),
          onPressed: () => context.pop(),
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
                    requests: _filter('pending'),
                    cardBg: _cardBg,
                    onRefresh: _load),
                _RequestList(
                    requests: _filter('responded'),
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
    final mumName =
        (request['profiles'] as Map?)?['full_name'] as String? ?? 'A mum';
    final isResponded = request['status'] == 'responded';

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
                  child: Text(request['question'] ?? '',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResponded
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isResponded ? 'Responded' : 'Pending',
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
}
