import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';

class VolunteerMumsHelpedScreen extends StatefulWidget {
  const VolunteerMumsHelpedScreen({super.key});

  @override
  State<VolunteerMumsHelpedScreen> createState() =>
      _VolunteerMumsHelpedScreenState();
}

class _VolunteerMumsHelpedScreenState
    extends State<VolunteerMumsHelpedScreen> {
  static const _pink = Color(0xFFE8A0B4);
  static const _roseDark = Color(0xFF9B8B86);
  static const _cardBg = Color(0xFFCB9189);

  List<Map<String, dynamic>> _mums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('consultations')
          .select('patient_id, scheduled_date')
          .eq('specialist_id', SupabaseService.currentUser!.id)
          .eq('status', 'completed');
      final rows = List<Map<String, dynamic>>.from(data);

      // Group by mum: session count + most recent completed session date.
      final byMum = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final patientId = row['patient_id'] as String?;
        if (patientId == null) continue;
        final date = row['scheduled_date']?.toString();
        final existing = byMum[patientId];
        if (existing == null) {
          byMum[patientId] = {'sessionCount': 1, 'lastDate': date};
        } else {
          existing['sessionCount'] = (existing['sessionCount'] as int) + 1;
          final lastDate = existing['lastDate'] as String?;
          if (date != null && (lastDate == null || date.compareTo(lastDate) > 0)) {
            existing['lastDate'] = date;
          }
        }
      }

      final mums = <Map<String, dynamic>>[];
      for (final entry in byMum.entries) {
        final profile = await SupabaseService.getProfileById(entry.key);
        mums.add({
          'id': entry.key,
          'name': profile?['full_name'] as String? ?? 'Mum',
          'sessionCount': entry.value['sessionCount'],
          'lastDate': entry.value['lastDate'],
        });
      }
      mums.sort((a, b) =>
          (b['lastDate'] as String? ?? '').compareTo(a['lastDate'] as String? ?? ''));

      if (mounted) {
        setState(() {
          _mums = mums;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
          onPressed: () => context.pop(),
        ),
        title: Text('Mums Helped',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: const Color(0xFF6B4A46))),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _mums.isEmpty
              ? Center(
                  child: Text('No completed sessions yet.',
                      style: GoogleFonts.poppins(
                          color: _roseDark, fontSize: 14)),
                )
              : RefreshIndicator(
                  color: _pink,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mums.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final mum = _mums[i];
                      final date = DateTime.tryParse(
                          mum['lastDate']?.toString() ?? '');
                      final dateStr = date != null
                          ? DateFormat('d MMM yyyy').format(date)
                          : 'Unknown date';
                      final sessionCount = mum['sessionCount'] as int;
                      return Container(
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mum['name'] as String,
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$sessionCount completed session${sessionCount == 1 ? '' : 's'} · Last: $dateStr',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
