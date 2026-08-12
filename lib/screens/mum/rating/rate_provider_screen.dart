import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../consultation/consultation_helpers.dart';

// Star-rating screen shown after a completed consultation/question, reached
// from a "Rate Dr X" / "Rate [volunteer]" notification.
class RateProviderScreen extends StatefulWidget {
  final Map<String, dynamic> notification;
  const RateProviderScreen({super.key, required this.notification});

  @override
  State<RateProviderScreen> createState() => _RateProviderScreenState();
}

class _RateProviderScreenState extends State<RateProviderScreen> {
  Map<String, dynamic>? _provider;
  bool _loading = true;
  bool _submitting = false;
  int _rating = 0;

  String get _providerId =>
      widget.notification['rating_provider_id'].toString();
  String get _providerType =>
      widget.notification['rating_provider_type'] as String? ?? 'specialist';
  String get _sourceType =>
      widget.notification['rating_source_type'] as String? ?? 'consultation';
  String get _sourceId => widget.notification['rating_source_id'].toString();
  bool get _isSpecialist => _providerType == 'specialist';
  String get _sourceLabel =>
      _sourceType == 'consultation' ? 'Appointment ID' : 'Reference ID';

  String get _displaySourceId => _sourceType == 'consultation'
      ? appointmentIdLabel(_sourceId, _providerType)
      : _sourceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? profile;
    try {
      profile = await SupabaseService.getProviderProfile(_providerId);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _provider = profile;
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? get _profileFields {
    final fields = _provider?['profiles'];
    return fields is Map<String, dynamic> ? fields : null;
  }

  String get _providerName {
    final name = _profileFields?['full_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final title = widget.notification['title']?.toString() ?? '';
    return title.replaceFirst('Rate Dr ', '').replaceFirst('Rate ', '');
  }

  String get _subtitle {
    if (_isSpecialist) {
      final specialization = _provider?['specialization'] as String?;
      if (specialization != null && specialization.trim().isNotEmpty) {
        return specialization;
      }
      return 'Specialist';
    }
    return 'Volunteer';
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    try {
      await SupabaseService.submitProviderRating(
        providerId: _providerId,
        providerType: _providerType,
        sourceType: _sourceType,
        sourceId: _sourceId,
        rating: _rating,
        notificationId: widget.notification['id']?.toString(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _copySourceId() {
    Clipboard.setData(ClipboardData(text: _displaySourceId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_sourceLabel copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _profileFields?['profile_picture_url'] as String?;
    final displayName = _isSpecialist ? 'Dr. $_providerName' : _providerName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Rate Your Experience'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TBCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  AppColors.rose.withValues(alpha: 0.15),
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                              child: photoUrl != null && photoUrl.isNotEmpty
                                  ? null
                                  : Text(
                                      _providerName.isNotEmpty
                                          ? _providerName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: AppColors.rose,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 28),
                                    ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              displayName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle,
                              style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _copySourceId,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.rose.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$_sourceLabel: $_displaySourceId',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMid,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: AppColors.textMid,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'How was your experience?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textDark),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) {
                                final starIndex = i + 1;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _rating = starIndex),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(
                                      starIndex <= _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: AppColors.gold,
                                      size: 40,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    TBButton(
                      label: 'Submit',
                      loading: _submitting,
                      onPressed: _rating == 0 ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
