import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';

Color statusColor(String status) {
  switch (status) {
    case 'confirmed':
      return AppColors.sage;
    case 'completed':
      return AppColors.teal;
    case 'cancelled':
      return Colors.red;
    default:
      return AppColors.gold;
  }
}

String statusEmoji(String status) {
  switch (status) {
    case 'confirmed':
      return '✅';
    case 'completed':
      return '✔️';
    case 'cancelled':
      return '❌';
    default:
      return '⏳';
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'confirmed':
      return 'Confirmed';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Pending Approval';
  }
}

String consultationTypeLabel(String? type) {
  if (type == null || type.isEmpty) return 'Consultation 1-1';
  return '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
}

// ── Shared provider card (Select Specialist / Select Volunteer) ────
Widget providerCard(
    BuildContext context, Map<String, dynamic> provider, String type) {
  final profile = provider['profiles'] as Map<String, dynamic>? ?? {};
  final isSpecialist = type == 'specialist';
  final name = profile['full_name'] as String? ??
      (isSpecialist ? 'Doctor' : 'Volunteer');
  final role = isSpecialist
      ? (provider['specialization'] as String? ?? 'Specialist')
      : (provider['expertise'] as String? ?? 'Volunteer');
  final rating = (provider['rating'] as num?)?.toStringAsFixed(1);
  final years = provider['years_experience'];
  final helpsWith = (provider['helps_with'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];
  final availableToday = (provider['available_today'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];
  final accent = isSpecialist ? AppColors.teal : AppColors.sage;

  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(role,
                        style: const TextStyle(
                            color: AppColors.textMid, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (rating != null) ...[
                        const Icon(Icons.star, color: AppColors.gold, size: 15),
                        const SizedBox(width: 4),
                        Text(rating,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                      if (years != null) ...[
                        const SizedBox(width: 8),
                        Text('•  $years Years Experience',
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12)),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (helpsWith.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Helps with:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            ...helpsWith.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('•  $h',
                      style: const TextStyle(
                          color: AppColors.textMid, fontSize: 13)),
                )),
          ],
          if (availableToday.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Available Today:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableToday
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.rose.withValues(alpha: 0.4))),
                          child: Text(t,
                              style: const TextStyle(
                                  color: AppColors.roseDeep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList()),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/consultation/book',
                  extra: {'provider': provider, 'type': type}),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5B56),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24))),
              child: Text(isSpecialist ? 'Select Specialist' : 'Select Volunteer',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}
