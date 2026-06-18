import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

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
