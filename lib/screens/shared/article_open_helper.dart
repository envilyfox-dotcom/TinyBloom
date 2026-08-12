import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

// Debounced so a double-tap doesn't open the same article/link twice.
DateTime? _lastArticleOpen;

// Articles with an external URL open in the browser; everything else opens
// in our own article detail screen.
Future<void> openArticle(
    BuildContext context, Map<String, dynamic> article) async {
  final now = DateTime.now();
  if (_lastArticleOpen != null &&
      now.difference(_lastArticleOpen!) < const Duration(milliseconds: 600)) {
    return;
  }
  _lastArticleOpen = now;

  final url = article['url'] as String?;
  if (url != null && url.isNotEmpty) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    await context.push('/education/${article['id']}', extra: article);
  }
}
