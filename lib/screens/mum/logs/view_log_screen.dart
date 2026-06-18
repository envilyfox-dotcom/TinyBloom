import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'logs_shared.dart';

// ── View Log Screen ───────────────────────────────────────────────
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
      if (context.mounted) context.pop();
    }
  }

  Widget _bulletList(List<String> items) {
    if (items.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.textLight, fontSize: 13));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('•  $s', style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = log;
    if (entry == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: logsAppBar(context),
        body: const Center(child: Text('Log not found.')),
      );
    }

    final id = entry['id'] as String;
    final mood = entry['mood'] as String?;
    final symptoms = asStringList(entry['symptoms']);
    final milestones = asStringList(entry['milestones']);
    final notes = (entry['notes'] as String?) ?? '';
    final date = entry['logged_at'] != null ? DateTime.parse(entry['logged_at']) : null;
    final weight = entry['weight_kg'];
    final kicks = entry['kick_count'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: logsAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(date != null ? DateFormat('d MMMM yyyy').format(date) : 'Health Log',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
          const SizedBox(height: 20),
          TBCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  _bulletList(symptoms),
                ])),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mood', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(moodEmoji(mood), style: const TextStyle(fontSize: 28)),
                ]),
              ]),
              const SizedBox(height: 20),
              const Text('Baby Milestones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              _bulletList(milestones),
              const SizedBox(height: 20),
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Text(notes.isEmpty ? 'No notes added.' : notes,
                style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
              if (weight != null) ...[
                const SizedBox(height: 20),
                const Text('Weight', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                Text('$weight kg', style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
              ],
              if (kicks != null) ...[
                const SizedBox(height: 20),
                const Text('Baby Movement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                Text('$kicks kicks', style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: pillButton('Edit',
              bg: editColor, fg: Colors.white,
              onTap: () async {
                await context.push('/logs/$id/edit', extra: entry);
                if (context.mounted) context.pop();
              })),
            const SizedBox(width: 12),
            Expanded(child: pillButton('Delete',
              bg: deleteColor, fg: Colors.white,
              onTap: () => _delete(context, id))),
          ]),
        ]),
      ),
    );
  }
}
