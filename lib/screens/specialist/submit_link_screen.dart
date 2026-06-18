import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Submit Article Link (Specialists) ──────────────────────────────
// Lets a specialist share an external article with a title so mums know
// what it's about. Submissions go live immediately in Recommended Articles
// and the Education tab.
class SubmitLinkScreen extends StatefulWidget {
  const SubmitLinkScreen({super.key});
  @override
  State<SubmitLinkScreen> createState() => _SubmitLinkScreenState();
}

class _SubmitLinkScreenState extends State<SubmitLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  List<Map<String, dynamic>> _myLinks = [];
  bool _loading = true;
  bool _submitting = false;
  int? _trimester;

  static const _trimesterOptions = [
    {'value': 1, 'label': '1st Trimester'},
    {'value': 2, 'label': '2nd Trimester'},
    {'value': 3, 'label': '3rd Trimester'},
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _titleCtrl.dispose(); _urlCtrl.dispose(); _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final links = await SupabaseService.getMySubmittedLinks();
    if (mounted) setState(() { _myLinks = links; _loading = false; });
  }

  String? _validateUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a link';
    final uri = Uri.tryParse(v);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Enter a valid http(s) link';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await SupabaseService.submitArticleLink(
        title: _titleCtrl.text.trim(),
        url: _urlCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        trimester: _trimester,
      );
      _titleCtrl.clear(); _urlCtrl.clear(); _categoryCtrl.clear();
      setState(() => _trimester = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link submitted! Mums can see it now.')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Link'),
        content: const Text('Are you sure you want to remove this link?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Link'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteArticleLink(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Article Link')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Share an article',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Add a link and a title so mums know what it\'s about.',
            style: TextStyle(color: AppColors.textMid, fontSize: 13)),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Link (URL)', hintText: 'https://...'),
                validator: _validateUrl,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)', hintText: 'e.g. Nutrition'),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Relevant Trimester (optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textMid)),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Mums will see this in Recommended Articles based on their current week.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: _trimesterOptions.map((t) {
                  final value = t['value'] as int;
                  final sel = _trimester == value;
                  return FilterChip(
                    label: Text(t['label'] as String, style: TextStyle(fontSize: 12,
                      color: sel ? AppColors.teal : AppColors.textMid,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    selected: sel,
                    onSelected: (_) => setState(() => _trimester = sel ? null : value),
                    selectedColor: AppColors.tealLight,
                    checkmarkColor: AppColors.teal,
                    backgroundColor: AppColors.white,
                    side: BorderSide(color: sel ? AppColors.teal : AppColors.textLight.withValues(alpha: 0.3)),
                  );
                }).toList()),
              const SizedBox(height: 16),
              TBButton(label: 'Submit Link', loading: _submitting, onPressed: _submit),
            ]),
          ),
          const SizedBox(height: 28),
          const Text('Your Submitted Links',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          if (_loading)
            const TBLoading()
          else if (_myLinks.isEmpty)
            const TBEmptyState(
              emoji: '🔗', title: 'No links yet',
              subtitle: 'Articles you submit will show up here.')
          else
            ..._myLinks.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TBCard(
                onTap: () => launchUrl(Uri.parse(link['url']), mode: LaunchMode.externalApplication),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('🔗', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(link['url'] ?? '',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (link['trimester'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Trimester ${link['trimester']}',
                          style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _delete(link['id']),
                  ),
                ]),
              ),
            )),
        ]),
      ),
    );
  }
}
