import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'logs_shared.dart';

// ── Logs List Screen ──────────────────────────────────────────────
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final logs = await SupabaseService.getLogs();
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Log'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteLog(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Logs')),
      body: _loading
          ? const TBLoading()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.rose,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  const Text('Track your daily symptoms, mood and baby milestones',
                    style: TextStyle(color: AppColors.textMid, fontSize: 14)),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () async { await context.push('/logs/create'); _load(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.rose, borderRadius: BorderRadius.circular(30)),
                      child: const Text('+ New Log',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_logs.isEmpty)
                    TBEmptyState(
                      emoji: '📋', title: 'No logs yet',
                      subtitle: 'Start tracking your health today.',
                      buttonLabel: 'Add First Log',
                      onButton: () async { await context.push('/logs/create'); _load(); })
                  else
                    ..._logs.map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LogCard(
                        log: log,
                        onView: () async {
                          await context.push('/logs/${log['id']}', extra: log);
                          _load();
                        },
                        onEdit: () async {
                          await context.push('/logs/${log['id']}/edit', extra: log);
                          _load();
                        },
                        onDelete: () => _delete(log['id']),
                      ),
                    )),
                ],
              ),
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
    required this.log, required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final mood = log['mood'] as String?;
    final symptoms = asStringList(log['symptoms']);
    final date = log['logged_at'] != null ? DateTime.parse(log['logged_at']) : null;

    return TBCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moodEmoji(mood), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date != null ? DateFormat('d MMM yyyy').format(date) : 'Health Log',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (date != null)
              Text(DateFormat('EEEE').format(date),
                style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          ])),
          if (mood != null && mood.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: moodColor(mood).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20)),
              child: Text('Mood: $mood',
                style: TextStyle(color: moodColor(mood), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
        if (symptoms.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Symptoms: ', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            TextSpan(text: symptoms.join(', '),
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
          ])),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: pillButton('View',
            bg: viewColor.withValues(alpha: 0.18), fg: AppColors.roseDeep, onTap: onView)),
          const SizedBox(width: 8),
          Expanded(child: pillButton('Edit', bg: editColor, fg: Colors.white, onTap: onEdit)),
          const SizedBox(width: 8),
          Expanded(child: pillButton('Delete', bg: deleteColor, fg: Colors.white, onTap: onDelete)),
        ]),
      ]),
    );
  }
}
