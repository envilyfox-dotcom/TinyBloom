import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
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
      builders: {'u': _UnderlineBuilder()},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}
