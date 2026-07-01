import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'logs_shared.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await SupabaseService.getLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    await context.push('/logs/create');
    await _load();
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Log?',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This log will be removed permanently.',
          style: TextStyle(color: AppColors.textMid),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deleteColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Logs',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Log',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const TBLoading()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.rose,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  _HeaderCard(totalLogs: _logs.length, onAdd: _openCreate),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent Logs',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${_logs.length} total',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_logs.isEmpty)
                    TBEmptyState(
                      emoji: '📋',
                      title: 'No logs yet',
                      subtitle:
                          'Start tracking your health, mood, symptoms and baby milestones.',
                      buttonLabel: 'Add First Log',
                      onButton: _openCreate,
                    )
                  else
                    ..._logs.map(
                      (log) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LogCard(
                          log: log,
                          onView: () async {
                            await context.push('/logs/${log['id']}',
                                extra: log);
                            await _load();
                          },
                          onEdit: () async {
                            await context.push('/logs/${log['id']}/edit',
                                extra: log);
                            await _load();
                          },
                          onDelete: () => _delete(log['id']),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int totalLogs;
  final VoidCallback onAdd;

  const _HeaderCard({required this.totalLogs, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('🌸', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Logs',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Track your mood, symptoms and baby milestones in one place.',
                  style: TextStyle(
                    color: AppColors.textMid,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniBadge(Icons.favorite_border, '$totalLogs logs'),
                    _miniBadge(Icons.auto_awesome, 'Daily tracking'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.roseDeep),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.roseDeep,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LogCard({
    required this.log,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mood = log['mood'] as String?;
    final symptoms = asStringList(log['symptoms']);
    final milestones = asStringList(log['milestones']);
    final notes = (log['notes'] as String?)?.trim();
    final weight = log['weight_kg'];
    final kicks = log['kick_count'];
    final systolic = log['blood_pressure_systolic'];
    final diastolic = log['blood_pressure_diastolic'];
    final hasMeasurements = weight != null ||
        kicks != null ||
        systolic != null ||
        diastolic != null;
    final rawDate = log['logged_at'] ?? log['log_date'] ?? log['created_at'];
    final date = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;

    return TBCard(
      padding: const EdgeInsets.all(16),
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: moodColor(mood).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child:
                    Text(moodEmoji(mood), style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null
                          ? DateFormat('d MMM yyyy').format(date)
                          : 'Health Log',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date != null
                          ? DateFormat('EEEE').format(date)
                          : 'Daily update',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppColors.textLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'view') onView();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'view', child: Text('View')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (mood != null && mood.trim().isNotEmpty)
            _SectionChips(
              label: 'Mood',
              icon: Icons.mood,
              chips: [mood],
              color: moodColor(mood),
            ),
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionChips(
              label: 'Symptoms',
              icon: Icons.healing_outlined,
              chips: symptoms,
              color: AppColors.rose,
            ),
          ],
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionChips(
              label: 'Baby Milestones',
              icon: Icons.auto_awesome,
              chips: milestones,
              color: AppColors.sage,
            ),
          ],
          if (hasMeasurements) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (systolic != null || diastolic != null)
                  _MiniMetric(
                    icon: Icons.favorite_border,
                    label: 'BP',
                    value: "${systolic ?? '—'}/${diastolic ?? '—'}",
                    color: ((systolic is num && systolic >= 140) ||
                            (diastolic is num && diastolic >= 90))
                        ? Colors.redAccent
                        : AppColors.teal,
                  ),
                if (weight != null)
                  _MiniMetric(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    value: '$weight kg',
                    color: AppColors.rose,
                  ),
                if (kicks != null)
                  _MiniMetric(
                    icon: Icons.child_care_outlined,
                    label: 'Kicks',
                    value: '$kicks',
                    color: AppColors.sage,
                  ),
              ],
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                notes,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChips extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> chips;
  final Color color;

  const _SectionChips({
    required this.label,
    required this.icon,
    required this.chips,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final visibleChips = chips.where((e) => e.trim().isNotEmpty).toList();
    if (visibleChips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: visibleChips.take(6).map((chip) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chip,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
