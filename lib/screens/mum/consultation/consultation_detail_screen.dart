import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';

class ConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> consultation;
  const ConsultationDetailScreen({super.key, required this.consultation});

  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

// A reschedule within this window of the consultation's start time is
// blocked — too close to the appointment for the specialist to realistically
// review and re-approve a new slot before it (or the original one) begins.
const Duration _minRescheduleNotice = Duration(minutes: 30);

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  Map<String, dynamic>? _provider;
  bool _loading = true;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final specialistId = widget.consultation['specialist_id'] as String?;
    final provider = specialistId != null
        ? await SupabaseService.getProviderProfile(specialistId)
        : null;
    if (mounted) {
      setState(() {
        _provider = provider;
        _loading = false;
      });
    }
  }

  Future<void> _joinMeeting() async {
    final link = (widget.consultation['meeting_link'] as String? ?? '').trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Zoom meeting link is not available yet.')),
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid meeting link.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the meeting link.')),
      );
    }
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

    final reason = await _promptCancellationReason();
    if (reason == null) return;

    setState(() => _cancelling = true);
    try {
      await SupabaseService.cancelConsultation(widget.consultation['id'],
          reason: reason);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reschedule() async {
    final provider = _provider;
    if (provider == null) return;
    final c = widget.consultation;
    final type = c['consultation_type'] as String? ??
        (provider['provider_type'] == 'specialist' ? 'specialist' : 'volunteer');
    context.push('/consultation/book', extra: {
      'provider': provider,
      'type': type,
      'consultation': c,
    });
  }

  // Matches the forum's "+ New Post" bottom sheet design so cancellation
  // flows feel consistent with the rest of the app.
  Future<String?> _promptCancellationReason() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason for Cancellation',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                  'Let your specialist know why you\'re cancelling this appointment.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13)),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'e.g. Something came up, need to reschedule...'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please share a reason before cancelling.'
                    : null,
              ),
              const SizedBox(height: 16),
              TBButton(
                label: 'Confirm Cancellation',
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(sheetContext, ctrl.text.trim());
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
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
    // Next-of-kin can only view the linked mum's consultations — cancelling
    // is her own action, so the Cancel button is hidden entirely for them.
    final isNextOfKin = context.watch<AuthProvider>().isNextOfKin;
    final c = widget.consultation;
    // Once the slot is over, effectiveConsultationStatus already reports
    // 'completed' — so gating on 'confirmed' here also takes care of
    // hiding the Join button once the meeting time has passed.
    final status = effectiveConsultationStatus(c);
    final meetingLink = (c['meeting_link'] as String? ?? '').trim();
    final showJoin =
        !isNextOfKin && status == 'confirmed' && meetingLink.isNotEmpty;
    final showCancel =
        !isNextOfKin && (status == 'confirmed' || status == 'pending');
    // Same eligibility as Cancel, plus a cutoff: once the appointment is
    // less than 30 minutes away (or already started), rescheduling is no
    // longer allowed — the button stays visible but greyed out so it's
    // clear the option existed and just closed, rather than vanishing.
    final scheduledAt = consultationScheduledDateTime(c);
    final tooCloseToReschedule = scheduledAt != null &&
        scheduledAt.difference(DateTime.now()) <= _minRescheduleNotice;
    final showReschedule = showCancel && _provider != null;
    // Still 'pending' in the database, but the slot has passed — the
    // specialist never responded in time, so it now reads as cancelled.
    // Distinguished from a deliberate cancel so the mum gets the right
    // explanation rather than a bare "Cancelled" with no reason.
    final wasNeverAccepted =
        (c['status'] as String? ?? '').toLowerCase() == 'pending' &&
            status == 'cancelled';
    final profile = _provider?['profiles'] as Map<String, dynamic>? ?? {};
    final isSpecialist = _provider?['provider_type'] == 'specialist';
    final name = profile['full_name'] as String? ?? 'Provider';
    final photoUrl = profile['profile_picture_url'] as String?;
    final specialistId = c['specialist_id'] as String?;
    final displayName = isSpecialist ? 'Dr. $name' : name;
    final role = isSpecialist
        ? (_provider?['specialization'] as String? ?? 'Specialist')
        : (_provider?['expertise'] as String? ?? 'Volunteer');
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
                          child: Row(children: [
                            GestureDetector(
                                onTap: specialistId == null
                                    ? null
                                    : () => openProviderProfile(
                                        context,
                                        {'user_id': specialistId},
                                        isSpecialist),
                                child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.blush,
                                    backgroundImage: photoUrl != null &&
                                            photoUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(photoUrl,
                                            maxWidth: 200)
                                        : null,
                                    child: photoUrl != null &&
                                            photoUrl.isNotEmpty
                                        ? null
                                        : Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: AppColors.roseDeep,
                                                fontWeight: FontWeight.w700)))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                Text(role,
                                    style: const TextStyle(
                                        color: AppColors.textMid,
                                        fontSize: 12)),
                              ],
                            )),
                          ]),
                        ),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow(
                            'Appointment ID',
                            appointmentIdValue(context, c['id'],
                                c['consultation_type'] as String?)),
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
                        if (status == 'cancelled' &&
                            (c['cancellation_reason'] as String? ?? '')
                                .isNotEmpty) ...[
                          const Divider(height: 1, color: AppColors.blush),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reason for Cancellation',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.red)),
                                const SizedBox(height: 6),
                                Text(c['cancellation_reason'] as String,
                                    style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (wasNeverAccepted) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$displayName did not respond to your consultation request in time, so it was cancelled. Please book another specialist.',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (showReschedule) ...[
                    SizedBox(
                      width: double.infinity,
                      child: Tooltip(
                        message: tooCloseToReschedule
                            ? 'Too close to the appointment time to reschedule.'
                            : '',
                        child: OutlinedButton.icon(
                          onPressed:
                              tooCloseToReschedule ? null : _reschedule,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: AppColors.teal,
                            disabledForegroundColor:
                                AppColors.teal.withValues(alpha: 0.35),
                            side: BorderSide(
                                color: tooCloseToReschedule
                                    ? AppColors.teal.withValues(alpha: 0.35)
                                    : AppColors.teal),
                          ),
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label: const Text('Reschedule'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'You can only reschedule up to 30 minutes before your consultation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textLight.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showJoin || showCancel)
                    Row(
                      children: [
                        if (showJoin)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _joinMeeting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.video_call, size: 18),
                              label: const Text('Join Zoom'),
                            ),
                          ),
                        if (showJoin && showCancel) const SizedBox(width: 12),
                        if (showCancel)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancelling ? null : _cancel,
                              style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14)),
                              child: _cancelling
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('Cancel Appointment'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
