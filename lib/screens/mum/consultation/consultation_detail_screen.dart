import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';

// ── Consultation Details ──────────────────────────────────────────
class ConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> consultation;
  const ConsultationDetailScreen({super.key, required this.consultation});
  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _patientProfile;
  Map<String, dynamic>? _patientPregnancy;
  int _patientCurrentWeek = 0;
  bool _loading = true;
  bool _cancelling = false;
  bool _approving = false;

  String _meetingLink() {
    final link = widget.consultation['meeting_link']?.toString().trim() ?? '';
    return link;
  }

  bool _canJoinMeeting(String status) {
    final normalised = status.toLowerCase();
    return normalised == 'confirmed' || normalised == 'approved';
  }

  Future<void> _joinMeeting() async {
    final link = _meetingLink();

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zoom meeting link is not available yet.'),
        ),
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

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Zoom meeting link.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _trimesterLabel(int week) {
    if (week >= 1 && week <= 12) return 'First Trimester';
    if (week >= 13 && week <= 27) return 'Second Trimester';
    if (week >= 28) return 'Third Trimester';
    return 'Unknown Trimester';
  }

  Future<void> _load() async {
    final specialistId = widget.consultation['specialist_id'] as String?;
    final patientId = widget.consultation['patient_id'] as String?;
    final provider = specialistId != null
        ? await SupabaseService.getProviderProfile(specialistId)
        : null;
    final patientProfile = patientId != null
        ? await SupabaseService.getProfileById(patientId)
        : null;
    final patientPregnancy = patientId != null
        ? await SupabaseService.getPregnancyProfileByUserId(patientId)
        : null;
    final patientCurrentWeek = patientId != null
        ? await SupabaseService.getCurrentPregnancyWeekByUserId(patientId)
        : 0;
    if (mounted)
      setState(() {
        _provider = provider;
        _patientProfile = patientProfile;
        _patientPregnancy = patientPregnancy;
        _patientCurrentWeek = patientCurrentWeek;
        _loading = false;
      });
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Consultation'),
        content:
            const Text('Are you sure you want to cancel this consultation?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Appointment'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            )),
          ]),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await SupabaseService.cancelConsultation(widget.consultation['id']);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await SupabaseService.updateConsultationStatus(
          widget.consultation['id'], 'approved');
      if (mounted) {
        widget.consultation['status'] = 'approved';
        setState(() => _approving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _approving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textMid)),
          value,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    final status = (c['status'] as String?) ?? 'pending';
    final patientName = _patientProfile?['full_name'] as String? ??
        c['patient_name'] as String? ?? 'Patient';
    final patientAge = (_patientPregnancy?['age'] as num?)?.toString() ??
        _patientProfile?['age']?.toString() ??
        '—';
    final patientCurrentWeek =
        (_patientPregnancy?['current_week'] as num?)?.toInt() ?? 0;
    final trimester = _trimesterLabel(patientCurrentWeek);
    final dateStr = c['scheduled_date'] != null
        ? DateFormat('d MMMM yyyy (EEE)')
            .format(DateTime.parse(c['scheduled_date']))
        : '—';
    final timeStr = c['scheduled_time'] as String? ?? '—';
    final purpose = c['purpose'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: _loading
          ? const TBLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consultation Details',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  const Text('View your consultation information.',
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Patient Details',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 12),
                              _detailRow(
                                  'Name',
                                  Text(patientName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13))),
                              const Divider(height: 1, color: AppColors.blush),
                              _detailRow(
                                  'Age',
                                  Text(patientAge,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13))),
                              const Divider(height: 1, color: AppColors.blush),
                              _detailRow(
                                  'Current Week',
                                  Text(
                                      patientCurrentWeek > 0
                                          ? '$patientCurrentWeek'
                                          : '—',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13))),
                              const Divider(height: 1, color: AppColors.blush),
                              _detailRow(
                                  'Trimester',
                                  Text(trimester,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13))),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow(
                            'Date',
                            Text(dateStr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow(
                            'Time',
                            Text(timeStr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow(
                            'Platform',
                            Text(c['platform'] as String? ?? 'Zoom Meeting',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow(
                            'Meeting Link',
                            Expanded(
                              child: Text(
                                _meetingLink().isEmpty
                                    ? 'Available after confirmation'
                                    : _meetingLink(),
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            )),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow(
                            'Status',
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                  color: statusColor(status)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(statusLabel(status),
                                  style: TextStyle(
                                      color: statusColor(status),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            )),
                        const Divider(height: 1, color: AppColors.blush),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Consultation Purpose',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(
                                  purpose.isEmpty
                                      ? 'No purpose specified.'
                                      : purpose,
                                  style: const TextStyle(
                                      color: AppColors.textMid, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_canJoinMeeting(status))
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Cancel Consultation'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton.icon(
                        onPressed: _joinMeeting,
                        icon: const Icon(Icons.video_call),
                        label: const Text('Join Zoom',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      )),
                    ])
                  else if (status == 'pending')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _cancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Cancel Consultation Request'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
