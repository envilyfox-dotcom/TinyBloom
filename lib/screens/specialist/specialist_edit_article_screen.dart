import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Edit Article (Specialists) ───────────────────────────────────────────
// Same form as SpecialistCreateArticleScreen, pre-filled for an existing
// draft/changes_requested article. Reached from the review thread's Edit
// Article button once a reviewer has requested changes — primary_group_id
// is fixed at submission and isn't editable here (see
// SupabaseService.updateArticleDraft).
class SpecialistEditArticleScreen extends StatefulWidget {
  final Map<String, dynamic> article;
  const SpecialistEditArticleScreen({super.key, required this.article});

  @override
  State<SpecialistEditArticleScreen> createState() =>
      _SpecialistEditArticleScreenState();
}

class _SpecialistEditArticleScreenState
    extends State<SpecialistEditArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  List<String> _categories = [];
  String? _primaryGroupName;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _deleting = false;
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
    _titleCtrl =
        TextEditingController(text: widget.article['title'] as String? ?? '');
    _contentCtrl = TextEditingController(
        text: widget.article['content'] as String? ?? '');
    _category = widget.article['category'] as String?;
    _trimester = widget.article['trimester'] as int?;
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
      final categories = await SupabaseService.getArticleCategories();
      final groups = await SupabaseService.getReviewGroups();
      final group = groups.firstWhere(
        (g) => g['id'] == widget.article['primary_group_id'],
        orElse: () => const {},
      );
      if (mounted) {
        setState(() {
          _categories = categories;
          _primaryGroupName = group['name'] as String?;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please choose a category.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.updateArticleDraft(
        widget.article['id'] as String,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        category: _category!,
        trimester: _trimester,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Article updated.')));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Article'),
        content: const Text(
            'Are you sure you want to remove this article? This cannot be undone.'),
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            )),
          ]),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _deleting = true);
    try {
      await SupabaseService.deleteArticleDraft(widget.article['id'] as String);
      if (mounted) context.pop('deleted');
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Article'),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: (_saving || _deleting) ? null : _delete,
          ),
        ],
      ),
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
                  child: Form(
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
                            'Fixed from submission — cannot be changed while in review.',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(_primaryGroupName ?? 'Unknown group',
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
                        label: 'Save Changes',
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ]),
                  ),
                ),
    );
  }
}
