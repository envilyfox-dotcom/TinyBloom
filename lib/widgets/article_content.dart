import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme.dart';

// Neither the markdown package nor raw `<u>` HTML tags support underline —
// CommonMark's raw-HTML rule leaves `<u>`/`</u>` untouched as literal text
// instead of parsing them — so Create Article's underline button emits this
// `++text++` marker instead, and every screen that displays article content
// needs this syntax registered to render it.
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

// Inline elements (unlike block elements) resolve their TextStyle from
// [MarkdownStyleSheet.styles], which only has slots for a fixed set of known
// tags — 'u' isn't one of them, so [visitText] never sees the underline
// decoration merged in. Overriding [visitElementAfterWithContext] instead
// replaces the already-built (plain) inline child with one carrying the
// parent's inherited style plus underline.
class _UnderlineBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Text.rich (not a plain Text) so the parent paragraph's merge step,
    // which only flattens children whose textSpan is a TextSpan, folds this
    // back into the same RichText run as its surrounding text.
    return Text.rich(TextSpan(
        text: element.textContent,
        style: (parentStyle ?? preferredStyle ?? const TextStyle())
            .copyWith(decoration: TextDecoration.underline)));
  }
}

// Inline images (from Create Article's image button) render with no size
// hint from markdown, so the default renderer pops the image in the instant
// it finishes downloading and the layout jumps. A shimmer skeleton at a
// placeholder height shows progress until then; the loaded image is scaled
// to the article's full width at its own natural aspect ratio (BoxFit.fitWidth)
// rather than a fixed box, so nothing gets cropped.
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
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: AppColors.rose.withValues(alpha: 0.08),
            highlightColor: AppColors.rose.withValues(alpha: 0.18),
            child: Container(width: double.infinity, height: 180, color: Colors.white),
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

// ── Article Content ───────────────────────────────────────────────
// Renders article body text written with Create Article's formatting
// toolbar (bold/italic/underline/emoji/inline images) consistently
// wherever it's displayed.
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
