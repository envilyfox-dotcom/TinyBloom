import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

// Opens an article: launches the external link if the article has a `url`
// (specialist-submitted), otherwise pushes the in-app detail screen.
//
// Guarded against rapid double-taps: a fast double tap can fire two
// `context.push()` calls before the first navigation completes, which makes
// the Navigator try to register two pages with the same key and crash with
// "!keyReservation.contains(key)". A short cooldown avoids that.
DateTime? _lastArticleOpen;
void openArticle(BuildContext context, Map<String, dynamic> article) {
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
