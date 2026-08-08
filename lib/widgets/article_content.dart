import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme.dart';

class _UnderlineSyntax extends md.DelimiterSyntax {
  _UnderlineSyntax()
      : super(
          r'\++',
          requiresDelimiterRun: true,
          allowIntraWord: true,
          startCharacter: 0x2B, // '+'
          tags: [md.DelimiterTag('u', 2)],
        );
}

class _UnderlineBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Text.rich(TextSpan(
        text: element.textContent,
        style: (parentStyle ?? preferredStyle ?? const TextStyle())
            .copyWith(decoration: TextDecoration.underline)));
  }
}

class _ImageBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final src = element.attributes['src'];
    if (src == null || src.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: src,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          memCacheWidth: (MediaQuery.sizeOf(context).width *
                  MediaQuery.of(context).devicePixelRatio)
              .round(),
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: AppColors.rose.withValues(alpha: 0.08),
            highlightColor: AppColors.rose.withValues(alpha: 0.18),
            child: Container(
                width: double.infinity, height: 180, color: Colors.white),
          ),
          errorWidget: (context, url, error) => Container(
            width: double.infinity,
            height: 180,
            color: AppColors.rose.withValues(alpha: 0.08),
            child: const Icon(Icons.broken_image_outlined,
                color: AppColors.textLight),
          ),
        ),
      ),
    );
  }
}

class ArticleContent extends StatelessWidget {
  final String data;
  final TextStyle? style;

  const ArticleContent({super.key, required this.data, this.style});

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        const TextStyle(color: AppColors.textMid, fontSize: 15, height: 1.7);
    return MarkdownBody(
      data: data,
      selectable: true,
      inlineSyntaxes: [_UnderlineSyntax()],
      builders: {'u': _UnderlineBuilder(), 'img': _ImageBuilder()},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}
