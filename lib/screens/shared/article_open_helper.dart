import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

DateTime? _lastArticleOpen;
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
