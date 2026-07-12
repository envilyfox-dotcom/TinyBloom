import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Edit Article (Specialists) ───────────────────────────────────────────
// Same form/design as SpecialistCreateArticleScreen, pre-filled for an
// existing draft/changes_requested article. Reached from the review
// thread's Edit Article button once a reviewer has requested changes —
// primary_group_id is fixed at submission and isn't editable here (see
// SupabaseService.updateArticleDraft).
class SpecialistEditArticleScreen extends StatefulWidget {
  final Map<String, dynamic> article;
  const SpecialistEditArticleScreen({super.key, required this.article});

  @override
  State<SpecialistEditArticleScreen> createState() =>
      _SpecialistEditArticleScreenState();
}

const _quickEmojis = [
  '😀', '😊', '😍', '🥰', '😴', '😢', '🎉', '👍',
  '❤️', '🤰', '👶', '🍼', '🌸', '✨', '🙏', '💪',
];

class _SpecialistEditArticleScreenState
    extends State<SpecialistEditArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  final _contentFocus = FocusNode();

  List<String> _categories = [];
  String? _primaryGroupName;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _deleting = false;
  bool _uploadingImage = false;
  int? _trimester;
  String? _category;

  static const _trimesterOptions = [
    {'value': 1, 'label': '1st Trimester'},
    {'value': 2, 'label': '2nd Trimester'},
    {'value': 3, 'label': '3rd Trimester'},
  ];

  // Submitting for review is only valid while the article hasn't cleared
  // the pipeline yet (mirrors resubmit_content's own status guard) — once
  // it's mid-review/buffer, editing here just logs a change, it doesn't
  // resubmit anything.
  bool get _canSubmit {
    final status = widget.article['status'] as String?;
    return status == 'draft' || status == 'changes_requested';
  }

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
    _contentFocus.dispose();
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

  // ── Formatting toolbar ────────────────────────────────────────────
  void _wrapSelection(String left, [String? right]) {
    right ??= left;
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$left$selected$right');
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + left.length)
          : TextSelection(
              baseOffset: start + left.length,
              extentOffset: start + left.length + selected.length),
    );
    _contentFocus.requestFocus();
  }

  void _insertAtCursor(String insert) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, insert);
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _contentFocus.requestFocus();
  }

  Future<void> _pickEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _quickEmojis
                .map((e) => GestureDetector(
                      onTap: () => Navigator.pop(context, e),
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (emoji != null) _insertAtCursor(emoji);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final url = await SupabaseService.uploadArticleImage(
          bytes, ext.length <= 4 ? ext : 'jpg');
      _insertAtCursor('\n![image]($url)\n');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _uploadingImage = false);
  }

  Future<void> _save({required bool submitForReview}) async {
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
      if (submitForReview) {
        await SupabaseService.submitContentForReview(
            widget.article['id'] as String);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(submitForReview
                ? 'Submitted for review!'
                : 'Article updated.')));
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

  Widget _toolbarButton({required Widget child, VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: const Text('Edit Article',
              style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        centerTitle: true,
        elevation: 0,
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
                  padding: EdgeInsets.fromLTRB(
                      20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Text('Title',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                            if (_primaryGroupName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.tealLight,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text(_primaryGroupName!,
                                    style: const TextStyle(
                                        color: AppColors.teal,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            hintText: 'Insert your title here...',
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                  color: AppColors.rose, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter a title'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        const Text('Description',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    AppColors.textLight.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    _toolbarButton(
                                      onPressed: () => _wrapSelection('**'),
                                      child: const Text('B',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: AppColors.textDark)),
                                    ),
                                    _toolbarButton(
                                      onPressed: () => _wrapSelection('*'),
                                      child: const Text('I',
                                          style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: AppColors.textDark)),
                                    ),
                                    _toolbarButton(
                                      onPressed: () => _wrapSelection('++'),
                                      child: const Text('U',
                                          style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: AppColors.textDark)),
                                    ),
                                    const Spacer(),
                                    _toolbarButton(
                                      onPressed: _pickEmoji,
                                      child: const Icon(
                                          Icons.emoji_emotions_outlined,
                                          color: AppColors.textMid,
                                          size: 22),
                                    ),
                                    _toolbarButton(
                                      onPressed:
                                          _uploadingImage ? null : _pickImage,
                                      child: _uploadingImage
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.teal))
                                          : const Icon(Icons.image_outlined,
                                              color: AppColors.textMid,
                                              size: 22),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  color: AppColors.textLight
                                      .withValues(alpha: 0.2)),
                              TextFormField(
                                controller: _contentCtrl,
                                focusNode: _contentFocus,
                                maxLines: 8,
                                decoration: const InputDecoration(
                                  hintText: 'Insert your content here...',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Please write the article content'
                                        : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _save(submitForReview: false),
                                child: const Text('Save Changes'),
                              ),
                            ),
                            if (_canSubmit) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: TBButton(
                                  label: 'Submit for Review',
                                  loading: _saving,
                                  onPressed: () =>
                                      _save(submitForReview: true),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
