import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
    final c = widget.consultation;
    final status = (c['status'] as String?) ?? 'pending';
    final profile = _provider?['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Provider';
    final role = _provider?['provider_type'] == 'specialist'
        ? (_provider?['specialization'] as String? ?? 'Specialist')
        : (_provider?['expertise'] as String? ?? 'Volunteer');
    final dateStr = c['scheduled_date'] != null
        ? DateFormat('d MMMM yyyy (EEE)').format(DateTime.parse(c['scheduled_date']))
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
                            CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.blush,
                                child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                        color: AppColors.roseDeep,
                                        fontWeight: FontWeight.w700))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(role,
                                    style: const TextStyle(
                                        color: AppColors.textMid, fontSize: 12)),
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
                        _detailRow('Date', Text(dateStr,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Time', Text(timeStr,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Platform', Text(c['platform'] as String? ?? 'Zoom Meeting',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Status', Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: statusColor(status).withValues(alpha: 0.18),
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
                              Text(purpose.isEmpty ? 'No purpose specified.' : purpose,
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
                  const SizedBox(height: 20),
                  if (status == 'confirmed' || status == 'pending')
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
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Cancel Appointment'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
