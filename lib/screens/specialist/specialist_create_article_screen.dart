import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Create Article (Specialists) ────────────────────────────────────────
// Replaces the old instant-publish "Submit Article Link" screen. Every
// article now starts as a draft and must pass the two-stage peer review
// pipeline (see Article_System_specialist.md) before it goes live.
class SpecialistCreateArticleScreen extends StatefulWidget {
  const SpecialistCreateArticleScreen({super.key});
  @override
  State<SpecialistCreateArticleScreen> createState() =>
      _SpecialistCreateArticleScreenState();
}

class _SpecialistCreateArticleScreenState
    extends State<SpecialistCreateArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  Map<String, dynamic>? _myGroup;
  List<String> _categories = [];
  List<Map<String, dynamic>> _mySubmissions = [];
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  int? _trimester;
  String? _category;

  static const _trimesterOptions = [
    {'value': 1, 'label': '1st Trimester'},
    {'value': 2, 'label': '2nd Trimester'},
    {'value': 3, 'label': '3rd Trimester'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final group = await SupabaseService.getMyPrimaryGroup();
      final categories = await SupabaseService.getArticleCategories();
      final mine = await SupabaseService.getMyArticleSubmissions();
      if (mounted) {
        setState(() {
          _myGroup = group;
          _categories = categories;
          _mySubmissions = mine;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save({required bool submitForReview}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_myGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Set your specialty in your profile before creating an article.')));
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please choose a category.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await SupabaseService.createArticleDraft(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        primaryGroupId: _myGroup!['id'] as int,
        category: _category!,
        trimester: _trimester,
      );
      if (submitForReview) {
        await SupabaseService.submitContentForReview(created['id'] as String);
      }
      _titleCtrl.clear();
      _contentCtrl.clear();
      setState(() {
        _trimester = null;
        _category = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(submitForReview
                ? 'Submitted for review!'
                : 'Draft saved.')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _submitDraft(Map<String, dynamic> article) async {
    try {
      await SupabaseService.submitContentForReview(article['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submitted for review!')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteDraft(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Draft'),
        content: const Text('Are you sure you want to remove this draft?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
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
      await SupabaseService.deleteArticleDraft(id);
      _load();
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'pending_approval_1':
        return 'Awaiting 1st approval';
      case 'pending_approval_2':
        return 'Awaiting 2nd approval';
      case 'changes_requested':
        return 'Changes requested';
      case 'publish_buffer':
        return 'In publish buffer';
      case 'emergency_pending':
        return 'Flagged for recall';
      case 'published':
        return 'Live';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return AppColors.teal;
      case 'changes_requested':
      case 'emergency_pending':
        return Colors.redAccent;
      case 'draft':
        return AppColors.textLight;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Article')),
      body: _loading
          ? const TBLoading()
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text('Couldn\'t load: $_loadError',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMid)),
                        const SizedBox(height: 16),
                        TBButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Write an article',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text(
                      'This will go through peer review before it\'s visible to mums.',
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contentCtrl,
                        maxLines: 8,
                        decoration: const InputDecoration(
                            labelText: 'Article content',
                            alignLabelWithHint: true),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please write the article content'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Category',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textMid)),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Pick from the categories already used on the Learn tab.',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      if (_categories.isEmpty)
                        const Text('No categories exist yet.',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12))
                      else
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((c) {
                              final sel = _category == c;
                              return ChoiceChip(
                                label: Text(c,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: sel
                                            ? AppColors.teal
                                            : AppColors.textMid,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                                selected: sel,
                                onSelected: (_) =>
                                    setState(() => _category = c),
                                selectedColor: AppColors.tealLight,
                                backgroundColor: AppColors.white,
                                side: BorderSide(
                                    color: sel
                                        ? AppColors.teal
                                        : AppColors.textLight
                                            .withValues(alpha: 0.3)),
                              );
                            }).toList()),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Primary Review Group',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textMid)),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Determined automatically from your specialty.',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      if (_myGroup == null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                              'No specialty set on your profile yet — set it under Edit Profile before you can submit an article.',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(_myGroup!['name'] as String? ?? '',
                              style: const TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Relevant Trimester (optional)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textMid)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _trimesterOptions.map((t) {
                            final value = t['value'] as int;
                            final sel = _trimester == value;
                            return FilterChip(
                              label: Text(t['label'] as String,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: sel
                                          ? AppColors.teal
                                          : AppColors.textMid,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                              selected: sel,
                              onSelected: (_) => setState(
                                  () => _trimester = sel ? null : value),
                              selectedColor: AppColors.tealLight,
                              checkmarkColor: AppColors.teal,
                              backgroundColor: AppColors.white,
                              side: BorderSide(
                                  color: sel
                                      ? AppColors.teal
                                      : AppColors.textLight
                                          .withValues(alpha: 0.3)),
                            );
                          }).toList()),
                      const SizedBox(height: 20),
                      TBButton(
                        label: 'Submit for Review',
                        loading: _saving,
                        onPressed: () => _save(submitForReview: true),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _save(submitForReview: false),
                          child: const Text('Save Draft'),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  const Text('Your Submissions',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_mySubmissions.isEmpty)
                    const TBEmptyState(
                        emoji: '📝',
                        title: 'No submissions yet',
                        subtitle: 'Articles you write will show up here.')
                  else
                    ..._mySubmissions.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TBCard(
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                                a['status'] as String? ?? '')
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        _statusLabel(
                                            a['status'] as String? ?? ''),
                                        style: TextStyle(
                                          color: _statusColor(
                                              a['status'] as String? ?? ''),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (a['status'] == 'draft')
                                IconButton(
                                  icon: const Icon(Icons.send_outlined,
                                      color: AppColors.teal, size: 20),
                                  tooltip: 'Submit for review',
                                  onPressed: () => _submitDraft(a),
                                ),
                              if (a['status'] == 'draft' ||
                                  a['status'] == 'changes_requested')
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () =>
                                      _deleteDraft(a['id'] as String),
                                ),
                            ]),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
