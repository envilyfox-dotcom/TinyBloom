import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class VolunteerMumsHelpedScreen extends StatefulWidget {
  const VolunteerMumsHelpedScreen({super.key});

  @override
  State<VolunteerMumsHelpedScreen> createState() =>
      _VolunteerMumsHelpedScreenState();
}

class _VolunteerMumsHelpedScreenState
    extends State<VolunteerMumsHelpedScreen> {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Mums Helped',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.rose))
          : _mums.isEmpty
              ? Center(
                  child: Text('No completed sessions yet.',
                      style: GoogleFonts.poppins(
                          color: AppColors.textLight, fontSize: 14)),
                )
              : RefreshIndicator(
                  color: AppColors.rose,
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
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.rose.withValues(alpha: 0.18)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                              child: const Icon(Icons.person, color: AppColors.rose),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mum['name'] as String,
                                      style: GoogleFonts.poppins(
                                          color: AppColors.textDark,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$sessionCount completed session${sessionCount == 1 ? '' : 's'} · Last: $dateStr',
                                    style: GoogleFonts.poppins(
                                        color: AppColors.textLight, fontSize: 12),
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
