import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'logs_shared.dart';

class ViewLogScreen extends StatelessWidget {
  final Map<String, dynamic>? log;
  const ViewLogScreen({super.key, this.log});

  Future<void> _delete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Log'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.deleteLog(id);
      if (context.mounted) context.pop();
    }
  }

  Widget _bulletList(List<String> items) {
    if (items.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(color: AppColors.textLight, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.blush.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                s,
                style: const TextStyle(
                  color: AppColors.roseDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = log;
    if (entry == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'View Log',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(child: Text('Log not found.')),
      );
    }

    final id = entry['id'] as String;
    final mood = entry['mood'] as String?;
    final symptoms = asStringList(entry['symptoms']);
    final milestones = asStringList(entry['milestones']);
    final notes = (entry['notes'] as String?) ?? '';
    final date =
        entry['logged_at'] != null ? DateTime.parse(entry['logged_at']) : null;
    final weight = entry['weight_kg'];
    final kicks = entry['kick_count'];
    final systolic = entry['blood_pressure_systolic'];
    final diastolic = entry['blood_pressure_diastolic'];
    final hasBloodPressure = systolic != null || diastolic != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'View Log',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date != null
                  ? DateFormat('d MMMM yyyy').format(date)
                  : 'Health Log',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 24),
            ),
            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE').format(date),
                style: const TextStyle(color: AppColors.textMid, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            TBCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailHeader(mood),
                  const SizedBox(height: 20),
                  _section('Symptoms', _bulletList(symptoms)),
                  const SizedBox(height: 18),
                  _section('Baby Milestones', _bulletList(milestones)),
                  const SizedBox(height: 18),
                  _section(
                    'Notes',
                    Text(
                      notes.isEmpty ? 'No notes added.' : notes,
                      style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                  if (weight != null || kicks != null || hasBloodPressure) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (hasBloodPressure)
                          Expanded(
                            child: _metricCard(
                              icon: Icons.favorite_border,
                              label: 'Blood Pressure',
                              value:
                                  "${systolic ?? '—'}/${diastolic ?? '—'} mmHg",
                            ),
                          ),
                        if (hasBloodPressure &&
                            (weight != null || kicks != null))
                          const SizedBox(width: 10),
                        if (weight != null)
                          Expanded(
                            child: _metricCard(
                              icon: Icons.monitor_weight_outlined,
                              label: 'Weight',
                              value: '$weight kg',
                            ),
                          ),
                        if (weight != null && kicks != null)
                          const SizedBox(width: 12),
                        if (kicks != null)
                          Expanded(
                            child: _metricCard(
                              icon: Icons.child_care,
                              label: 'Movement',
                              value: '$kicks kicks',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: pillButton(
                    'Edit',
                    bg: editColor,
                    fg: Colors.white,
                    onTap: () async {
                      await context.push('/logs/$id/edit', extra: entry);
                      if (context.mounted) context.pop();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pillButton(
                    'Delete',
                    bg: deleteColor,
                    fg: Colors.white,
                    onTap: () => _delete(context, id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailHeader(String? mood) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: moodColor(mood).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(moodEmoji(mood), style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mood == null || mood.isEmpty
                ? 'Mood not recorded'
                : 'Feeling $mood',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.roseDeep, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textLight, fontSize: 11),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
