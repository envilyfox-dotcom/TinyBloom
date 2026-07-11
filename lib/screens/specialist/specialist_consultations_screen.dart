import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../mum/consultation/consultation_helpers.dart';

// ── Specialist Consultation Tab ─────────────────────────────────────
// Lists every pending/confirmed consultation for the logged-in
// specialist, soonest first, with the same details shown on
// SpecialistConsultationDetailScreen surfaced directly on each card.
class SpecialistConsultationsScreen extends StatefulWidget {
  const SpecialistConsultationsScreen({super.key});

  @override
  State<SpecialistConsultationsScreen> createState() =>
      _SpecialistConsultationsScreenState();
}

class _SpecialistConsultationsScreenState
    extends State<SpecialistConsultationsScreen> {
  static const _tagOptions = ['All Available', 'Cancelled', 'Expired', 'Done'];

  List<Map<String, dynamic>> _consultations = [];
  final Map<String, Map<String, dynamic>> _patientProfiles = {};
  final Map<String, Map<String, dynamic>?> _patientPregnancies = {};
  final Map<String, int> _patientWeeks = {};
  bool _loading = true;
  final Set<String> _busyIds = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedTag = 'All Available';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredConsultations {
    final query = _searchQuery.trim().toLowerCase();

    return _consultations.where((c) {
      final key = _effectiveStatusKey(c);
      final matchesTag = switch (_selectedTag) {
        'Cancelled' => key == 'cancelled',
        'Expired' => key == 'expired',
        'Done' => key == 'done',
        _ => key == 'pending' || key == 'confirmed',
      };
      if (!matchesTag) return false;
      if (query.isEmpty) return true;

      final patientId = c['patient_id'] as String?;
      final name = patientId != null
          ? (_patientProfiles[patientId]?['full_name'] as String?)
          : null;
      final patientName = name ?? (c['patient_name'] as String?) ?? '';
      final apptId = appointmentIdLabel(c['id']);

      return patientName.toLowerCase().contains(query) ||
          apptId.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> consultations = [];
    try {
      consultations = await SupabaseService.getConsultations();
    } catch (_) {}

    consultations = consultations.where((c) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      return status == 'pending' ||
          status == 'confirmed' ||
          status == 'cancelled' ||
          status == 'expired';
    }).toList();

    final patientIds = consultations
        .map((c) => c['patient_id'] as String?)
        .whereType<String>()
        .toSet();

    await Future.wait(patientIds.map((id) async {
      try {
        final profile = await SupabaseService.getProfileById(id);
        if (profile != null) _patientProfiles[id] = profile;
      } catch (_) {}
      try {
        _patientPregnancies[id] =
            await SupabaseService.getPregnancyProfileByUserId(id);
      } catch (_) {}
      try {
        _patientWeeks[id] =
            await SupabaseService.getCurrentPregnancyWeekByUserId(id);
      } catch (_) {}
    }));

    consultations.sort((a, b) {
      final aInactive = _isInactiveKey(_effectiveStatusKey(a));
      final bInactive = _isInactiveKey(_effectiveStatusKey(b));
      if (aInactive != bInactive) return aInactive ? 1 : -1;

      final aTime = _scheduledDateTime(a);
      final bTime = _scheduledDateTime(b);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      // Active appointments: soonest first. Expired/cancelled: most recent first.
      return aInactive ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
    });

    if (mounted) {
      setState(() {
        _consultations = consultations;
        _loading = false;
      });
    }
  }

  DateTime? _scheduledDateTime(Map<String, dynamic> c) {
    final scheduled = c['scheduled_date'];
    if (scheduled == null) return null;
    try {
      final date = DateTime.parse(scheduled.toString());
      final timeStr = c['scheduled_time'] as String?;
      if (timeStr == null || timeStr.isEmpty) {
        return DateTime(date.year, date.month, date.day);
      }
      return slotDateTime(date, timeStr) ??
          DateTime(date.year, date.month, date.day);
    } catch (_) {
      return null;
    }
  }

  // A pending consultation whose scheduled time has already passed without
  // the specialist approving it reads as "Expired"; a confirmed one that has
  // already passed reads as "Done" — both distinct from a patient-initiated
  // "Cancelled".
  String _effectiveStatusKey(Map<String, dynamic> consultation) {
    final status = (consultation['status'] as String? ?? 'pending').toLowerCase();
    if (status == 'cancelled') return 'cancelled';

    final scheduled = _scheduledDateTime(consultation);
    final isPast = scheduled != null && scheduled.isBefore(DateTime.now());
    if (status == 'pending' && isPast) return 'expired';
    if (status == 'confirmed' && isPast) return 'done';
    return status;
  }

  bool _isInactiveKey(String key) =>
      key == 'expired' || key == 'cancelled' || key == 'done';

  Future<void> _startSession(Map<String, dynamic> consultation) async {
    final link = consultation['meeting_link']?.toString().trim() ?? '';
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zoom meeting link is not available yet.')),
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Zoom meeting link.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Zoom meeting link.')),
      );
    }
  }

  Future<void> _approve(Map<String, dynamic> consultation) async {
    final id = consultation['id']?.toString();
    if (id == null) return;

    setState(() => _busyIds.add(id));
    try {
      await SupabaseService.updateConsultationStatus(id, 'confirmed');
      if (mounted) setState(() => consultation['status'] = 'confirmed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _busyIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredConsultations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Consultation',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search patient or appointment ID',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textLight),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textLight),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    fillColor: AppColors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tagOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = _tagOptions[index];
                      final selected = _selectedTag == tag;

                      return ChoiceChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedTag = tag),
                        selectedColor: AppColors.blush,
                        backgroundColor: AppColors.white,
                        side: BorderSide(
                          color: selected
                              ? AppColors.rose
                              : AppColors.textLight.withValues(alpha: 0.25),
                        ),
                        labelStyle: TextStyle(
                          color:
                              selected ? AppColors.roseDeep : AppColors.textMid,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        checkmarkColor: AppColors.roseDeep,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const TBLoading()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.rose,
                    child: filtered.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              TBEmptyState(
                                emoji: '🩺',
                                title: _consultations.isEmpty
                                    ? 'No consultations yet'
                                    : 'No matches found',
                                subtitle: _consultations.isEmpty
                                    ? 'Your upcoming patient consultations will show here.'
                                    : 'Try a different search or tag filter.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final consultation = filtered[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _consultationCard(consultation),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _consultationCard(Map<String, dynamic> consultation) {
    final id = consultation['id']?.toString() ?? '';
    final patientId = consultation['patient_id'] as String?;
    final patientProfile = patientId != null ? _patientProfiles[patientId] : null;
    final patientPregnancy =
        patientId != null ? _patientPregnancies[patientId] : null;
    final patientWeek = patientId != null ? (_patientWeeks[patientId] ?? 0) : 0;

    final patientName = patientProfile?['full_name'] as String? ??
        consultation['patient_name'] as String? ??
        'Patient';
    final patientAge = (patientPregnancy?['age'] as num?)?.toString() ??
        patientProfile?['age']?.toString() ??
        '—';
    final photoUrl = patientProfile?['profile_picture_url'] as String?;
    final effectiveKey = _effectiveStatusKey(consultation);
    final dateStr = consultation['scheduled_date'] != null
        ? DateFormat('d MMMM yyyy')
            .format(DateTime.parse(consultation['scheduled_date']))
        : '—';
    final timeStr = consultation['scheduled_time'] as String? ?? '—';
    final purpose = consultation['purpose'] as String? ?? '';
    final cancellationReason =
        consultation['cancellation_reason'] as String? ?? '';
    final platform = consultation['platform'] as String? ?? 'Zoom Meeting';
    final busy = _busyIds.contains(id);

    return GestureDetector(
      onTap: () async {
        await context.push('/consultation/detail', extra: consultation);
        _load();
      },
      child: Container(
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
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl != null
                      ? null
                      : Text(
                          patientName.isNotEmpty
                              ? patientName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.roseDeep,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoLine('Appointment ID', appointmentIdLabel(id)),
            _infoLine('Name', patientName),
            _infoLine('Age', patientAge == '—' ? '—' : '$patientAge yrs old'),
            _infoLine('Pregnancy',
                patientWeek > 0 ? 'Week $patientWeek · ${trimesterLabel(patientWeek)}' : '—'),
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
                  _statusBadge(effectiveKey),
                ],
              ),
            ),
            const SizedBox(height: 8),
            effectiveKey == 'cancelled'
                ? Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Reason for Cancellation: ',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        TextSpan(
                            text: cancellationReason.isEmpty
                                ? 'No reason given.'
                                : cancellationReason,
                            style: const TextStyle(
                                color: AppColors.textDark, fontSize: 13)),
                      ],
                    ),
                  )
                : Text(
                    'Descriptions: ${purpose.isEmpty ? 'No purpose specified.' : purpose}',
                    style:
                        const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 16),
            if (effectiveKey == 'confirmed')
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startSession(consultation),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.roseDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text('Start Session',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              )
            else if (effectiveKey == 'pending')
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : () => _approve(consultation),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.roseDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Approve Appointment',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Expired/Cancelled are display-only concepts local to this tab — layered
  // on top of the shared statusColor/statusLabel used elsewhere in the app
  // (pending = gold, confirmed = sage) so those screens are unaffected.
  Widget _statusBadge(String key) {
    String label;
    Color color;
    final outline = key == 'cancelled';

    switch (key) {
      case 'expired':
        label = 'Expired';
        color = Colors.red;
        break;
      case 'cancelled':
        label = 'Cancelled';
        color = Colors.red;
        break;
      case 'done':
        label = 'Done';
        color = AppColors.teal;
        break;
      default:
        label = statusLabel(key);
        color = statusColor(key);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: outline ? Border.all(color: color, width: 1.4) : null,
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
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
}
