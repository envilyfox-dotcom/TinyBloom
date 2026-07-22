import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import 'consultation_helpers.dart';

// ── Confirm Consultation ──────────────────────────────────────────
class ConfirmConsultationScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final String type;
  final DateTime date;
  final String time;
  final String purpose;
  const ConfirmConsultationScreen({
    super.key,
    required this.provider,
    required this.type,
    required this.date,
    required this.time,
    required this.purpose,
  });
  @override
  State<ConfirmConsultationScreen> createState() =>
      _ConfirmConsultationScreenState();
}

class _ConfirmConsultationScreenState extends State<ConfirmConsultationScreen> {
  bool _submitting = false;
  bool _submitted = false;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      await SupabaseService.bookConsultation({
        'specialist_id': widget.provider['user_id'],
        'consultation_type': widget.type,
        'scheduled_date': widget.date.toIso8601String().split('T').first,
        'scheduled_time': widget.time.split('-').first.trim(),
        'purpose': widget.purpose.isEmpty ? null : widget.purpose,
        'platform': 'Zoom Meeting',
        'meeting_link':
            'https://zoom.us/j/${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      });
      if (mounted) {
        setState(() {
          _submitted = true;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String get _listingRoute => widget.type == 'volunteer'
      ? '/consultation/volunteers'
      : '/consultation/specialists';

  // Once a booking is confirmed, going "back" (app bar arrow or hardware
  // back) must not return to the date/time form underneath -- that screen
  // still holds the now-booked date/time selected, and re-pressing "Confirm
  // Booking" there would submit a second booking for the same slot. Instead
  // send the user to the same place the "Done" button goes.
  void _leave() {
    if (_submitted) {
      context.go(_listingRoute);
    } else {
      context.pop();
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textMid,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.provider['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Provider';
    final photoUrl = profile['profile_picture_url'] as String?;
    final isSpecialist = widget.type == 'specialist';
    final role = isSpecialist
        ? (widget.provider['specialization'] as String? ?? 'Specialist')
        : (widget.provider['expertise'] as String? ?? 'Volunteer');

    return PopScope(
      canPop: !_submitted,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _submitted) context.go(_listingRoute);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: _leave,
          ),
          title: const Text(
            'Confirm Consultation',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Consultation',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review your consultation details.',
                style: TextStyle(color: AppColors.textMid, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.rose.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => openProviderProfile(
                                context, widget.provider, isSpecialist),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.blush,
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(photoUrl,
                                          maxWidth: 200)
                                      : null,
                              child: photoUrl != null && photoUrl.isNotEmpty
                                  ? null
                                  : Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.roseDeep,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  role,
                                  style: const TextStyle(
                                    color: AppColors.textMid,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.blush),
                    _detailRow(
                      'Date',
                      DateFormat('d MMMM yyyy (EEE)').format(widget.date),
                    ),
                    const Divider(height: 1, color: AppColors.blush),
                    _detailRow('Time', widget.time.split('-').first.trim()),
                    const Divider(height: 1, color: AppColors.blush),
                    _detailRow('Platform', 'Zoom Meeting'),
                    const Divider(height: 1, color: AppColors.blush),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consultation Purpose',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.purpose.isEmpty
                                ? 'No purpose specified.'
                                : widget.purpose,
                            style: const TextStyle(
                              color: AppColors.textMid,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_submitted) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Consultation request sent!',
                    style: TextStyle(
                      color: AppColors.sage,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(_listingRoute),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm Booking',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
