import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';

// Opens an article: launches the external link if the article has a `url`
// (specialist-submitted), otherwise pushes the in-app detail screen.
//
// Guarded against rapid double-taps: a fast double tap can fire two
// `context.push()` calls before the first navigation completes, which makes
// the Navigator try to register two pages with the same key and crash with
// "!keyReservation.contains(key)". A short cooldown avoids that.
DateTime? _lastArticleOpen;
void _openArticle(BuildContext context, Map<String, dynamic> article) {
  final now = DateTime.now();
  if (_lastArticleOpen != null && now.difference(_lastArticleOpen!) < const Duration(milliseconds: 600)) {
    return;
  }
  _lastArticleOpen = now;

  final url = article['url'] as String?;
  if (url != null && url.isNotEmpty) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    context.push('/education/${article['id']}', extra: article);
  }
}

// ── FAQ Screen ────────────────────────────────────────────────────
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  List<Map<String, dynamic>> _faqs = [];
  bool _loading = true;
  String _selectedCat = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final faqs = await SupabaseService.getFaqs();
    if (mounted) {
      setState(() {
        _faqs = faqs;
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = {
      'All',
      ..._faqs.map((f) => f['category'] as String? ?? 'General')
    };
    return cats.toList();
  }

  List<Map<String, dynamic>> get _filtered => _selectedCat == 'All'
      ? _faqs
      : _faqs.where((f) => f['category'] == _selectedCat).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: _loading
          ? const TBLoading()
          : Column(
              children: [
                // Category chips
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    children: _categories
                        .map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat),
                                selected: _selectedCat == cat,
                                onSelected: (_) =>
                                    setState(() => _selectedCat = cat),
                                selectedColor: AppColors.tealLight,
                                checkmarkColor: AppColors.teal,
                                labelStyle: TextStyle(
                                    color: _selectedCat == cat
                                        ? AppColors.teal
                                        : AppColors.textMid,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                backgroundColor: AppColors.white,
                                side: BorderSide(
                                    color: _selectedCat == cat
                                        ? AppColors.teal
                                        : AppColors.textLight.withValues(alpha: 0.3)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final faq = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TBCard(
                          padding: EdgeInsets.zero,
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            iconColor: AppColors.teal,
                            collapsedIconColor: AppColors.textLight,
                            title: Text(faq['question'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            children: [
                              Text(faq['answer'] ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 14,
                                      height: 1.6)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Education Screen ──────────────────────────────────────────────
class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});
  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String _search = '';
  String _selectedCat = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await SupabaseService.getArticles();
    if (mounted) {
      setState(() {
        _articles = a;
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = {
      'All',
      ..._articles.map((a) => a['category'] as String? ?? 'General')
    };
    return cats.toList();
  }

  List<Map<String, dynamic>> get _filtered => _articles.where((a) {
        final matchCat = _selectedCat == 'All' || a['category'] == _selectedCat;
        final matchSearch = _search.isEmpty ||
            (a['title'] as String? ?? '')
                .toLowerCase()
                .contains(_search.toLowerCase());
        return matchCat && matchSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Educational Content')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search articles...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textLight),
                fillColor: AppColors.white,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: _categories
                  .map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: _selectedCat == cat,
                          onSelected: (_) => setState(() => _selectedCat = cat),
                          selectedColor: AppColors.tealLight,
                          checkmarkColor: AppColors.teal,
                          labelStyle: TextStyle(
                              color: _selectedCat == cat
                                  ? AppColors.teal
                                  : AppColors.textMid,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          backgroundColor: AppColors.white,
                          side: BorderSide(
                              color: _selectedCat == cat
                                  ? AppColors.teal
                                  : AppColors.textLight.withValues(alpha: 0.3)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const TBLoading()
                : _filtered.isEmpty
                    ? const TBEmptyState(
                        emoji: '📚',
                        title: 'No articles found',
                        subtitle: 'Try a different search or category.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final article = _filtered[i];
                          final isLink = (article['url'] as String?)?.isNotEmpty == true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TBCard(
                              onTap: () => _openArticle(context, article),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                        color: AppColors.blush,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Center(
                                        child: Text(isLink ? '🔗' : '📄',
                                            style: const TextStyle(fontSize: 28))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(article['title'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        if (article['category'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: AppColors.tealLight,
                                                borderRadius:
                                                    BorderRadius.circular(50)),
                                            child: Text(article['category'],
                                                style: const TextStyle(
                                                    color: AppColors.teal,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        if (article['excerpt'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(article['excerpt'],
                                              style: const TextStyle(
                                                  color: AppColors.textLight,
                                                  fontSize: 12),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: AppColors.textLight, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Article Detail ────────────────────────────────────────────────
class ArticleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article['category'] ?? 'Article')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article['category'] != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(50)),
                child: Text(article['category'],
                    style: const TextStyle(
                        color: AppColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            Text(article['title'] ?? '',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 22)),
            const SizedBox(height: 16),
            if ((article['url'] as String?)?.isNotEmpty == true) ...[
              if (article['excerpt'] != null) ...[
                Text(article['excerpt'],
                    style: const TextStyle(
                        color: AppColors.textMid, fontSize: 15, height: 1.7)),
                const SizedBox(height: 20),
              ],
              TBButton(
                label: 'Open Article',
                icon: Icons.open_in_new,
                onPressed: () => launchUrl(Uri.parse(article['url']),
                    mode: LaunchMode.externalApplication),
              ),
            ] else
              Text(
                  article['content'] ??
                      article['excerpt'] ??
                      'No content available.',
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 15, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

// ── Consultation Screen ───────────────────────────────────────────
class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});
  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _consultations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  String? _error;

  Future<void> _load() async {
    try {
      final c = await SupabaseService.getConsultations();
      if (mounted) {
        setState(() {
          _consultations = c;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultations'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.textLight,
          tabs: const [Tab(text: 'My Consultations'), Tab(text: 'Book New')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 1: My consultations
          _loading
              ? const TBLoading()
              : _error != null
                  ? TBEmptyState(
                      emoji: '⚠️',
                      title: 'Couldn\'t load consultations',
                      subtitle: _error!,
                      buttonLabel: 'Retry',
                      onButton: () { setState(() => _loading = true); _load(); })
                  : _consultations.isEmpty
                  ? TBEmptyState(
                      emoji: '👩‍⚕️',
                      title: 'No consultations yet',
                      subtitle: isPremium
                          ? 'Book a consultation with a specialist or volunteer.'
                          : 'Book a consultation with a volunteer.',
                      buttonLabel: 'Book Now',
                      onButton: () => _tabs.animateTo(1))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _consultations.length,
                      itemBuilder: (ctx, i) {
                        final c = _consultations[i];
                        final status = c['status'] ?? 'pending';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TBCard(
                            onTap: () async {
                              await context.push('/consultation/detail', extra: c);
                              _load();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: _statusColor(status)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Center(
                                      child: Text(_statusEmoji(status),
                                          style:
                                              const TextStyle(fontSize: 20))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          _consultationTypeLabel(
                                              c['consultation_type'] as String?),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      Text(status.toUpperCase(),
                                          style: TextStyle(
                                              color: _statusColor(status),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppColors.textLight, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

          // Tab 2: Book new — everyone can reach volunteers; specialists are premium-only.
          _buildBookTab(isPremium),
        ],
      ),
    );
  }

  Widget _buildBookTab(bool isPremium) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TBSectionTitle(title: 'Choose Provider Type'),
          const SizedBox(height: 12),
          if (!isPremium) ...[
            const Text(
                'Free accounts can connect with community volunteers. Upgrade to Premium for verified specialists.',
                style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TBCard(
                  color: AppColors.blush,
                  onTap: () => context.push('/consultation/specialists'),
                  child: Column(
                    children: [
                      if (!isPremium)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.star, color: AppColors.gold, size: 12),
                          ),
                        ),
                      const Text('👩‍⚕️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      const Text('Specialist',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Verified doctors',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TBCard(
                  color: AppColors.tealLight,
                  onTap: () => context.push('/consultation/volunteers'),
                  child: const Column(
                    children: [
                      Text('🤝', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 8),
                      Text('Volunteer',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Community support',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

Color _statusColor(String status) {
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

String _statusEmoji(String status) {
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

String _statusLabel(String status) {
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

String _consultationTypeLabel(String? type) {
  if (type == null || type.isEmpty) return 'Consultation 1-1';
  return '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
}

// ── Consultation Details ──────────────────────────────────────────
class ConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> consultation;
  const ConsultationDetailScreen({super.key, required this.consultation});
  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  Map<String, dynamic>? _provider;
  bool _loading = true;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final specialistId = widget.consultation['specialist_id'] as String?;
    final provider = specialistId != null
        ? await SupabaseService.getProviderProfile(specialistId)
        : null;
    if (mounted) setState(() { _provider = provider; _loading = false; });
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Consultation'),
        content: const Text('Are you sure you want to cancel this consultation?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Appointment'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            )),
          ]),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await SupabaseService.cancelConsultation(widget.consultation['id']);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textMid)),
          value,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    final status = (c['status'] as String?) ?? 'pending';
    final profile = _provider?['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Provider';
    final role = _provider?['provider_type'] == 'specialist'
        ? (_provider?['specialization'] as String? ?? 'Specialist')
        : (_provider?['expertise'] as String? ?? 'Volunteer');
    final dateStr = c['scheduled_date'] != null
        ? DateFormat('d MMMM yyyy (EEE)').format(DateTime.parse(c['scheduled_date']))
        : '—';
    final timeStr = c['scheduled_time'] as String? ?? '—';
    final purpose = c['purpose'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: _loading
          ? const TBLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consultation Details',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  const Text('View your consultation information.',
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.blush,
                                child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                        color: AppColors.roseDeep,
                                        fontWeight: FontWeight.w700))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(role,
                                    style: const TextStyle(
                                        color: AppColors.textMid, fontSize: 12)),
                              ],
                            )),
                          ]),
                        ),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Date', Text(dateStr,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Time', Text(timeStr,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Platform', Text(c['platform'] as String? ?? 'Zoom Meeting',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        const Divider(height: 1, color: AppColors.blush),
                        _detailRow('Status', Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(_statusLabel(status),
                              style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        )),
                        const Divider(height: 1, color: AppColors.blush),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Consultation Purpose',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(purpose.isEmpty ? 'No purpose specified.' : purpose,
                                  style: const TextStyle(
                                      color: AppColors.textMid, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (status == 'confirmed')
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Cancel Consultation'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'The session link will be shared closer to your appointment.'))),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Join Session',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      )),
                    ])
                  else if (status == 'pending')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _cancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Cancel Consultation Request'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── AI Chatbot Screen ─────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Hi! I\'m TinyBloom\'s AI assistant 🌸 I can help answer your pregnancy questions, provide symptom information, and give personalised tips. What would you like to know?'
    },
  ];
  bool _typing = false;

  final _suggestions = [
    'What foods should I avoid?',
    'Is it normal to feel tired?',
    'When should I feel baby move?',
    'Tips for better sleep',
  ];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text.trim()});
      _typing = true;
    });
    _ctrl.clear();
    _scrollDown();

    // Simulated AI response (replace with actual API call)
    await Future.delayed(const Duration(seconds: 1));
    final response = _getResponse(text.toLowerCase());
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': response});
        _typing = false;
      });
      _scrollDown();
    }
  }

  String _getResponse(String q) {
    if (q.contains('food') || q.contains('eat') || q.contains('avoid')) {
      return 'During pregnancy, avoid raw fish/sushi, unpasteurised cheeses, deli meats, high-mercury fish, and undercooked eggs. Focus on folate-rich foods, lean proteins, dairy, and plenty of fruits and vegetables. 🥗';
    }
    if (q.contains('tired') || q.contains('fatigue')) {
      return 'Fatigue is very common in pregnancy, especially in the first and third trimesters. Your body is working hard! Try to rest when you can, stay hydrated, eat iron-rich foods, and do light exercise. If fatigue is severe, consult your doctor. 💤';
    }
    if (q.contains('move') || q.contains('kick')) {
      return 'Most mums feel baby movements between 16-25 weeks. First-time mums may feel it later. By week 28, aim to notice at least 10 movements in 2 hours. If you\'re concerned about reduced movements, contact your midwife. 👶';
    }
    if (q.contains('sleep')) {
      return 'Sleep on your left side for better blood flow to baby. Use a pregnancy pillow for support. Avoid screens before bed, maintain a regular sleep schedule, and try a warm bath to relax. 🌙';
    }
    return 'That\'s a great question! For personalised advice about "${q.length > 30 ? '${q.substring(0, 30)}...' : q}", I recommend discussing with your healthcare provider who knows your specific situation. I\'m here to provide general guidance. Is there anything specific I can help with? 🌸';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🤖', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('AI Assistant'),
          ],
        ),
      ),
      body: !isPremium
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGate(
                  feature: 'AI Assistant',
                  onUpgrade: () => context.push('/subscription')))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return _buildTyping();
                      }
                      final m = _messages[i];
                      return _buildBubble(m['role']!, m['text']!);
                    },
                  ),
                ),
                // Suggestions
                if (_messages.length <= 2)
                  SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      children: _suggestions
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _send(s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                          color:
                                              AppColors.teal.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(s,
                                        style: const TextStyle(
                                            color: AppColors.teal,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                // Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.textDark.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ctrl,
                          decoration: InputDecoration(
                            hintText: 'Ask anything about pregnancy...',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _send(_ctrl.text),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                              color: AppColors.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.send,
                              color: AppColors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBubble(String role, String text) {
    final isAI = role == 'ai';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAI) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                  color: AppColors.blush, shape: BoxShape.circle),
              child: const Center(
                  child: Text('🌸', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAI ? AppColors.white : AppColors.teal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isAI ? 4 : 16),
                  topRight: Radius.circular(isAI ? 16 : 4),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: isAI
                    ? [
                        BoxShadow(
                            color: AppColors.textDark.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Text(text,
                  style: TextStyle(
                      color: isAI ? AppColors.textMid : AppColors.white,
                      fontSize: 14,
                      height: 1.5)),
            ),
          ),
          if (!isAI) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
              color: AppColors.blush, shape: BoxShape.circle),
          child:
              const Center(child: Text('🌸', style: TextStyle(fontSize: 16))),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(delay: 0),
              SizedBox(width: 4),
              _Dot(delay: 200),
              SizedBox(width: 4),
              _Dot(delay: 400),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _a,
      child: const CircleAvatar(radius: 4, backgroundColor: AppColors.teal));
}

// ── Subscription Screen ───────────────────────────────────────────
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

// Plan metadata shared by the upgrade tiles and the Change Plan sheet.
const _subscriptionPlans = {
  'premium_monthly': {'label': 'Premium Monthly', 'price': '\$9.90/month'},
  'premium_yearly': {'label': 'Premium Annual', 'price': '\$90/year • Save 24%'},
};

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _busy = false;

  // There's no real payment gateway here — "subscribing" just records the
  // chosen plan and flips the role, same as everywhere else this app mocks
  // a feature it can't actually wire up to a third party.
  Future<void> _setPlan(String? plan) async {
    setState(() => _busy = true);
    try {
      await SupabaseService.setSubscriptionPlan(plan);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(plan == null
                ? 'Subscription cancelled.'
                : 'You\'re on the ${_subscriptionPlans[plan]!['label']} plan!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmUpgrade(String plan) async {
    final label = _subscriptionPlans[plan]!['label'];
    final price = _subscriptionPlans[plan]!['price'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Subscription'),
        content: Text('Subscribe to $label for $price?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Subscribe'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) await _setPlan(plan);
  }

  void _showChangePlan(String? currentPlan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change Plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
                currentPlan == null
                    ? 'No plan on file yet — choose one below.'
                    : 'Choose between monthly and yearly billing.',
                style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 16),
            for (final entry in _subscriptionPlans.entries) ...[
              _planTile(entry.key, entry.value['label']!, entry.value['price']!,
                  isCurrent: entry.key == currentPlan,
                  onSelect: () {
                    Navigator.pop(context);
                    if (entry.key != currentPlan) _setPlan(entry.key);
                  }),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
            'Are you sure? You\'ll lose access to premium features immediately.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Plan'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Plan'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) await _setPlan(null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPremium = auth.isPremium;
    final currentPlan = auth.subscriptionPlan;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TBCard(
              color: isPremium ? AppColors.blush : AppColors.tealLight,
              child: Row(
                children: [
                  Text(isPremium ? '⭐' : '🌱',
                      style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isPremium ? 'Premium Member' : 'Free Member',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 16)),
                        Text(
                            isPremium
                                ? (currentPlan != null
                                    ? 'You\'re on the ${_subscriptionPlans[currentPlan]?['label'] ?? 'Premium'} plan.'
                                    : 'You have access to all premium features.')
                                : 'Upgrade to unlock all features.',
                            style: const TextStyle(
                                color: AppColors.textMid, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!isPremium) ...[
              Text('Upgrade to Premium',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (final entry in _subscriptionPlans.entries) ...[
                _planTile(entry.key, entry.value['label']!, entry.value['price']!,
                    onSelect: _busy ? null : () => _confirmUpgrade(entry.key)),
                const SizedBox(height: 10),
              ],
            ],
            if (isPremium) ...[
              Text('Manage Subscription',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TBCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.swap_horiz, color: AppColors.teal),
                      title: const Text('Change Plan'),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textLight),
                      onTap: _busy ? null : () => _showChangePlan(currentPlan),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading:
                          const Icon(Icons.cancel_outlined, color: Colors.red),
                      title: const Text('Cancel Subscription',
                          style: TextStyle(color: Colors.red)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textLight),
                      onTap: _busy ? null : () => _confirmCancel(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planTile(String key, String name, String price,
      {bool isCurrent = false, required VoidCallback? onSelect}) {
    return TBCard(
      color: AppColors.tealLight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text(price,
                    style:
                        const TextStyle(color: AppColors.teal, fontSize: 13)),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Current Plan',
                  style: TextStyle(
                      color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12)),
            )
          else
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: const Text('Select', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

// ── Shared provider card (Select Specialist / Select Volunteer) ────
Widget _providerCard(
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

// ── Specialists List ──────────────────────────────────────────────
class SpecialistsListScreen extends StatefulWidget {
  const SpecialistsListScreen({super.key});
  @override
  State<SpecialistsListScreen> createState() => _SpecialistsListScreenState();
}

class _SpecialistsListScreenState extends State<SpecialistsListScreen> {
  List<Map<String, dynamic>> _specialists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getSpecialists();
      if (mounted) {
        setState(() {
          _specialists = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: !isPremium
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGate(
                  feature: 'Specialist Consultations',
                  onUpgrade: () => context.push('/subscription')),
            )
          : _loading
          ? const TBLoading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('Select Specialist',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                const Text('Choose a healthcare specialist.',
                    style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 20),
                if (_error != null)
                  TBEmptyState(
                      emoji: '⚠️',
                      title: 'Couldn\'t load specialists',
                      subtitle: _error!,
                      buttonLabel: 'Retry',
                      onButton: () { setState(() => _loading = true); _load(); })
                else if (_specialists.isEmpty)
                  const TBEmptyState(
                      emoji: '👩‍⚕️',
                      title: 'No specialists available',
                      subtitle: 'Check back later for available specialists.')
                else
                  ..._specialists
                      .map((s) => _providerCard(context, s, 'specialist')),
              ],
            ),
    );
  }
}

// ── Volunteers List ───────────────────────────────────────────────
class VolunteersListScreen extends StatefulWidget {
  const VolunteersListScreen({super.key});
  @override
  State<VolunteersListScreen> createState() => _VolunteersListScreenState();
}

class _VolunteersListScreenState extends State<VolunteersListScreen> {
  List<Map<String, dynamic>> _volunteers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getVolunteers();
      if (mounted) {
        setState(() {
          _volunteers = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: _loading
          ? const TBLoading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('Select Volunteer',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                const Text('Choose a volunteer.',
                    style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 20),
                if (_error != null)
                  TBEmptyState(
                      emoji: '⚠️',
                      title: 'Couldn\'t load volunteers',
                      subtitle: _error!,
                      buttonLabel: 'Retry',
                      onButton: () { setState(() => _loading = true); _load(); })
                else if (_volunteers.isEmpty)
                  const TBEmptyState(
                      emoji: '🤝',
                      title: 'No volunteers available',
                      subtitle: 'Check back later for available volunteers.')
                else
                  ..._volunteers
                      .map((v) => _providerCard(context, v, 'volunteer')),
              ],
            ),
    );
  }
}

// ── Consultation Booking ──────────────────────────────────────────
class ConsultationBookingScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final String type;
  const ConsultationBookingScreen(
      {super.key, required this.provider, required this.type});
  @override
  State<ConsultationBookingScreen> createState() =>
      _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState
    extends State<ConsultationBookingScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  String? _selectedTime;
  final _purposeCtrl = TextEditingController();

  // Derived from the provider's own "Available Today" times (shown on their
  // selection card), each turned into a full hour-long start–end range, so
  // the slots offered here always match what was advertised on that card.
  List<String> get _timeSlots {
    final available = (widget.provider['available_today'] as List?)
        ?.map((e) => e.toString())
        .toList();
    if (available == null || available.isEmpty) {
      return const ['9:00 AM - 10:00 AM', '2:00 PM - 3:00 PM', '5:00 PM - 6:00 PM'];
    }
    return available.map(_toRange).toList();
  }

  String _toRange(String start) {
    try {
      final time = DateFormat('h:mm a').parse(start);
      final end = time.add(const Duration(hours: 1));
      return '$start - ${DateFormat('h:mm a').format(end)}';
    } catch (_) {
      return start;
    }
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _continue() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a date and time.')));
      return;
    }
    context.push('/consultation/confirm', extra: {
      'provider': widget.provider,
      'type': widget.type,
      'date': _selectedDate,
      'time': _selectedTime,
      'purpose': _purposeCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.provider['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'this provider';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultation Booking',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            Text('Select your preferred date and time with $name.',
                style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 20),
            const Text('1. Date',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            _buildCalendar(),
            const SizedBox(height: 20),
            const Text('2. Available Time Slots',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((t) {
                  final sel = _selectedTime == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTime = t),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel
                              ? AppColors.sage
                              : AppColors.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(t,
                          style: TextStyle(
                              color: sel ? Colors.white : AppColors.sage,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  );
                }).toList()),
            const SizedBox(height: 20),
            const Text('3. Consultation Purpose',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purposeCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'e.g. Discuss morning sickness & fatigue'),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Continue',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstDayOfMonth.weekday % 7; // Sun=0 .. Sat=6
    final totalCells = leadingBlanks + daysInMonth;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMMM yyyy').format(_month),
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month - 1))),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1))),
              ]),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'])
                Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600))),
              for (int i = 0; i < totalCells; i++)
                if (i < leadingBlanks)
                  const SizedBox.shrink()
                else
                  _dayCell(i - leadingBlanks + 1, todayMidnight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int day, DateTime todayMidnight) {
    final date = DateTime(_month.year, _month.month, day);
    final isPast = date.isBefore(todayMidnight);
    final isSelected = _selectedDate != null && _isSameDay(_selectedDate!, date);
    return GestureDetector(
      onTap: isPast ? null : () => setState(() => _selectedDate = date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.rose : Colors.transparent),
        alignment: Alignment.center,
        child: Text('$day',
            style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : (isPast
                        ? AppColors.textLight.withValues(alpha: 0.5)
                        : AppColors.textDark),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

// ── Confirm Consultation ──────────────────────────────────────────
class ConfirmConsultationScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final String type;
  final DateTime date;
  final String time;
  final String purpose;
  const ConfirmConsultationScreen({
    super.key,
    required this.provider,
    required this.type,
    required this.date,
    required this.time,
    required this.purpose,
  });
  @override
  State<ConfirmConsultationScreen> createState() =>
      _ConfirmConsultationScreenState();
}

class _ConfirmConsultationScreenState extends State<ConfirmConsultationScreen> {
  bool _submitting = false;
  bool _submitted = false;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      await SupabaseService.bookConsultation({
        'specialist_id': widget.provider['user_id'],
        'consultation_type': widget.type,
        'scheduled_date': widget.date.toIso8601String().split('T').first,
        'scheduled_time': widget.time,
        'purpose': widget.purpose.isEmpty ? null : widget.purpose,
        'platform': 'Zoom Meeting',
      });
      if (mounted) setState(() { _submitted = true; _submitting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textMid)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.provider['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Provider';
    final role = widget.type == 'specialist'
        ? (widget.provider['specialization'] as String? ?? 'Specialist')
        : (widget.provider['expertise'] as String? ?? 'Volunteer');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm Consultation',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            const Text('Review your consultation details.',
                style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.blush,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppColors.roseDeep,
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(role,
                              style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 12)),
                        ],
                      )),
                    ]),
                  ),
                  const Divider(height: 1, color: AppColors.blush),
                  _detailRow(
                      'Date', DateFormat('d MMMM yyyy (EEE)').format(widget.date)),
                  const Divider(height: 1, color: AppColors.blush),
                  _detailRow('Time', widget.time),
                  const Divider(height: 1, color: AppColors.blush),
                  _detailRow('Platform', 'Zoom Meeting'),
                  const Divider(height: 1, color: AppColors.blush),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Consultation Purpose',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                            widget.purpose.isEmpty
                                ? 'No purpose specified.'
                                : widget.purpose,
                            style: const TextStyle(
                                color: AppColors.textMid, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_submitted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Consultation request sent!',
                    style:
                        TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/consultation'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ] else
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Booking',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    )),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Baby Development Screen ───────────────────────────────────────
class BabyDevelopmentScreen extends StatefulWidget {
  const BabyDevelopmentScreen({super.key});

  @override
  State<BabyDevelopmentScreen> createState() => _BabyDevelopmentScreenState();
}

class _BabyDevelopmentScreenState extends State<BabyDevelopmentScreen> {
  int _currentWeek = 24;
  bool _loading = true;
  DateTime? _dueDate;
  List<Map<String, dynamic>> _articles = [];

  static const _trimesterInfo = {
    1: {'label': 'First Trimester', 'weeks': 'Weeks 1–12', 'color': 0xFFE8B4BC},
    2: {
      'label': 'Second Trimester',
      'weeks': 'Weeks 13–27',
      'color': 0xFFB4D4CC
    },
    3: {
      'label': 'Third Trimester',
      'weeks': 'Weeks 28–40',
      'color': 0xFFD4C4B4
    },
  };

  int get _trimester {
    if (_currentWeek <= 12) return 1;
    if (_currentWeek <= 27) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load the current week first so article recommendations can be
    // filtered by the right trimester from the start.
    await _loadWeek();
    await _loadArticles();
  }

  Future<void> _loadWeek() async {
    try {
      final data = await SupabaseService.getPregnancyProfile();
      if (data != null && mounted) {
        // Calculate week from due date if available
        if (data['due_date'] != null) {
          final due = DateTime.parse(data['due_date']);
          final now = DateTime.now();
          final daysUntilDue = due.difference(now).inDays;
          final week = ((280 - daysUntilDue) / 7).floor().clamp(1, 40);
          setState(() {
            _currentWeek = week;
            _dueDate = due;
            _loading = false;
          });
          return;
        }
        // Fall back to weeks_pregnant field if present
        if (data['weeks_pregnant'] != null) {
          setState(() {
            _currentWeek = (data['weeks_pregnant'] as int).clamp(1, 40);
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadArticles() async {
    try {
      final all = await SupabaseService.getArticles();

      // 1st choice: articles a specialist tagged for the mum's current trimester.
      final byTrimester = all.where((a) => a['trimester'] == _trimester).toList();
      if (byTrimester.isNotEmpty) {
        if (mounted) setState(() => _articles = byTrimester.take(3).toList());
        return;
      }

      // 2nd choice: untagged but pregnancy/baby-development related articles.
      final relevant = all.where((a) {
        final cat = (a['category'] as String? ?? '').toLowerCase();
        return cat.contains('pregnan') || cat.contains('baby') || cat.contains('develop');
      }).toList();

      // 3rd choice: whatever is published, newest first.
      if (mounted) {
        setState(() => _articles = (relevant.isNotEmpty ? relevant : all).take(3).toList());
      }
    } catch (_) {}
  }

  // Splits a highlight sentence (or several) into short bullet points for
  // the "Development Progress" card.
  List<String> _milestones(String highlight) {
    return highlight
        .split('. ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.endsWith('.') ? s.substring(0, s.length - 1) : s)
        .toList();
  }

  Widget _statCard(String label, String value, Color color) {
    return TBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;
    final week = pregnancyWeekData[_currentWeek] ?? pregnancyWeekData[24]!;
    final trimester = _trimesterInfo[_trimester]!;
    final trimesterColor = Color(trimester['color'] as int);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Baby Development'),
        backgroundColor: AppColors.blush,
        elevation: 0,
      ),
      body: !isPremium
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGate(
                  feature: 'Detailed Baby Development Insights',
                  onUpgrade: () => context.push('/subscription')),
            )
          : _loading
          ? const TBLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trimester badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: trimesterColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${trimester['label']}  •  ${trimester['weeks']}',
                      style: TextStyle(
                          color: trimesterColor.withValues(alpha: 1.0),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(height: 6),
                    Text('Based on due date: ${DateFormat('d MMM yyyy').format(_dueDate!)}',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),

                  // Hero card
                  TBCard(
                    color: AppColors.blush,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(week['emoji'] as String,
                                style: const TextStyle(fontSize: 64)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Week $_currentWeek',
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.roseDeep)),
                                  Text(
                                      'Your baby is the size of\n${week['size']}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textMid,
                                          height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress bar
                        LinearProgressIndicator(
                          value: _currentWeek / 40,
                          backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.rose),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text('$_currentWeek / 40 weeks',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Baby Information — stats grid
                  Row(
                    children: [
                      Expanded(child: _statCard('Length', week['length'] as String, AppColors.roseDeep)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Approx. Weight', week['weight'] as String, AppColors.roseDeep)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard('Weeks Remaining', '${40 - _currentWeek} weeks', AppColors.teal)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Trimester', 'Trimester $_trimester', AppColors.teal)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Development Progress card
                  TBCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.timeline_outlined,
                              color: AppColors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Development Progress',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.teal)),
                              const SizedBox(height: 6),
                              ..._milestones(week['highlight'] as String).map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('•  $m',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMid,
                                        height: 1.4)),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommended Articles
                  if (_articles.isNotEmpty) ...[
                    TBCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.menu_book_outlined,
                                    color: AppColors.gold, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text('Recommended Articles',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._articles.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => _openArticle(context, a),
                              child: Row(
                                children: [
                                  const Text('•  ', style: TextStyle(color: AppColors.textMid)),
                                  Expanded(
                                    child: Text(a['title'] ?? '',
                                        style: const TextStyle(
                                            color: AppColors.textMid,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textLight, size: 16),
                                ],
                              ),
                            ),
                          )),
                          const SizedBox(height: 4),
                          GestureDetector(
                            // `go`, not `push` — `/education` lives inside the bottom-nav
                            // ShellRoute, and pushing it from a screen outside the shell
                            // (this one) would create a duplicate shell page with a
                            // colliding key, crashing the Navigator.
                            onTap: () => context.go('/education'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.blush,
                                borderRadius: BorderRadius.circular(20)),
                              child: const Text('Read More',
                                  style: TextStyle(
                                      color: AppColors.roseDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}

// ── Milestone Journey ─────────────────────────────────────────────
// Curated "big moments" timeline (as opposed to BabyDevelopmentScreen's
// week-by-week data), grouped by trimester.
const _milestoneJourney = [
  {'week': 4, 'title': 'Week 4', 'trimester': 1,
    'items': ['Fertilized egg successfully implanted', 'Pregnancy confirmed']},
  {'week': 6, 'title': 'Week 6 — Heartbeat Detected', 'trimester': 1,
    'items': ['Baby\'s heartbeat detected', 'First ultrasound completed']},
  {'week': 8, 'title': 'Week 8 — Early Development', 'trimester': 1,
    'items': ['Facial features starting to form', 'Tiny arm and leg movements begin']},
  {'week': 10, 'title': 'Week 10 — Organ Development', 'trimester': 1,
    'items': ['Major organs developing', 'Baby begins small body movements']},
  {'week': 12, 'title': 'Week 12 — End of 1st Trimester', 'trimester': 1,
    'items': ['Nuchal scan completed', 'Lower miscarriage risk', 'Baby fully formed']},
  {'week': 16, 'title': 'Week 16 — Growth Milestone', 'trimester': 2,
    'items': ['Baby can hear sounds', 'Facial expressions developing']},
  {'week': 20, 'title': 'Week 20 — Anatomy Scan', 'trimester': 2,
    'items': ['Full anatomy scan completed', 'Baby movements stronger', 'Gender may be visible']},
  {'week': 24, 'title': 'Week 24 — Viability Milestone', 'trimester': 2,
    'items': ['Baby may survive outside womb with medical support', 'Heartbeat developing well', 'Baby responding to sounds']},
  {'week': 28, 'title': 'Week 28 — Brain & Lung Development', 'trimester': 2,
    'items': ['Brain developing rapidly', 'Eyes can open and close', 'Glucose test scheduled']},
  {'week': 32, 'title': 'Week 32 — Rapid Growth', 'trimester': 3,
    'items': ['Baby gaining weight quickly', 'Stronger kicks and movements']},
  {'week': 36, 'title': 'Week 36 — Full Term Preparation', 'trimester': 3,
    'items': ['Baby moving into birth position', 'Hospital preparation checklist']},
  {'week': 38, 'title': 'Week 38 — Final Development', 'trimester': 3,
    'items': ['Baby lungs nearly mature', 'Frequent contractions may occur']},
  {'week': 40, 'title': 'Week 40 — Estimated Delivery Week', 'trimester': 3,
    'items': ['🎉 Full Term Reached', 'Baby ready for delivery', 'Labour may begin anytime']},
];

class MilestoneJourneyScreen extends StatefulWidget {
  const MilestoneJourneyScreen({super.key});
  @override
  State<MilestoneJourneyScreen> createState() => _MilestoneJourneyScreenState();
}

class _MilestoneJourneyScreenState extends State<MilestoneJourneyScreen> {
  int _currentWeek = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final week = await SupabaseService.getCurrentPregnancyWeek();
    if (mounted) setState(() { _currentWeek = week; _loading = false; });
  }

  Color _trimesterColor(int t) {
    switch (t) {
      case 1: return AppColors.sage;
      case 2: return AppColors.teal;
      default: return AppColors.gold;
    }
  }

  String _trimesterLabel(int t) {
    switch (t) {
      case 1: return '1st Trimester';
      case 2: return '2nd Trimester';
      default: return '3rd Trimester';
    }
  }

  @override
  Widget build(BuildContext context) {
    // The most recently reached milestone week, so far.
    int? currentMilestoneWeek;
    for (final m in _milestoneJourney) {
      if ((m['week'] as int) <= _currentWeek) currentMilestoneWeek = m['week'] as int;
    }
    final progress = _currentWeek > 0 ? (_currentWeek / 40).clamp(0.0, 1.0) : 0.0;
    final isPremium = context.watch<AuthProvider>().isPremium;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Milestone Journey')),
      body: !isPremium
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGate(
                  feature: 'Milestone Journey',
                  onUpgrade: () => context.push('/subscription')),
            )
          : _loading
          ? const TBLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progress',
                          style: TextStyle(
                              color: AppColors.roseDeep,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(AppColors.rose),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildTimeline(currentMilestoneWeek),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildTimeline(int? currentMilestoneWeek) {
    final widgets = <Widget>[];
    int? lastTrimester;
    for (int i = 0; i < _milestoneJourney.length; i++) {
      final m = _milestoneJourney[i];
      final trimester = m['trimester'] as int;
      final week = m['week'] as int;
      final isCurrent = week == currentMilestoneWeek;
      final isLast = i == _milestoneJourney.length - 1;

      if (trimester != lastTrimester) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: lastTrimester == null ? 0 : 8, bottom: 12),
          child: Text(_trimesterLabel(trimester),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark)),
        ));
        lastTrimester = trimester;
      }

      widgets.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _trimesterColor(trimester)),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: AppColors.textLight.withValues(alpha: 0.25))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m['title'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.sage.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Current',
                                style: TextStyle(
                                    color: AppColors.sage,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...(m['items'] as List<String>).map((it) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('✓ $it',
                              style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 13)),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }
}
