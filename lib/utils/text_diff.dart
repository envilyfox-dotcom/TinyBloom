import 'dart:typed_data';

enum DiffOpType { equal, delete, insert }

class DiffOp {
  final DiffOpType type;
  final String text;
  const DiffOp(this.type, this.text);
}

enum ParagraphChangeType { added, removed, modified }

class ParagraphChange {
  final ParagraphChangeType type;
  final List<DiffOp> ops;
  const ParagraphChange(this.type, this.ops);
}

List<String> _tokenizeWords(String text) =>
    RegExp(r'\s+|\S+').allMatches(text).map((m) => m[0]!).toList();

List<String> _tokenizeParagraphs(String text) => text
    .split(RegExp(r'\n\s*\n'))
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .toList();

List<DiffOp> _diffTokens(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  if (n == 0 && m == 0) return const [];
  const maxCells = 900000;
  if (n * m > maxCells) {
    final ops = <DiffOp>[];
    if (n > 0) ops.add(DiffOp(DiffOpType.delete, a.join()));
    if (m > 0) ops.add(DiffOp(DiffOpType.insert, b.join()));
    return ops;
  }

  final dp = List.generate(n + 1, (_) => Int32List(m + 1));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final ops = <DiffOp>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      ops.add(DiffOp(DiffOpType.equal, a[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      ops.add(DiffOp(DiffOpType.delete, a[i]));
      i++;
    } else {
      ops.add(DiffOp(DiffOpType.insert, b[j]));
      j++;
    }
  }
  while (i < n) {
    ops.add(DiffOp(DiffOpType.delete, a[i]));
    i++;
  }
  while (j < m) {
    ops.add(DiffOp(DiffOpType.insert, b[j]));
    j++;
  }
  return ops;
}

List<DiffOp> _collapse(List<DiffOp> ops) {
  final out = <DiffOp>[];
  for (final op in ops) {
    if (out.isNotEmpty && out.last.type == op.type) {
      out[out.length - 1] = DiffOp(op.type, out.last.text + op.text);
    } else {
      out.add(op);
    }
  }
  return out;
}

/// Word-level diff of two short strings (e.g. a title).
List<DiffOp> wordDiff(String oldText, String newText) =>
    _collapse(_diffTokens(_tokenizeWords(oldText), _tokenizeWords(newText)));

/// Paragraph-level diff of article bodies: unchanged paragraphs are dropped
/// entirely, and only the paragraphs that were added, removed, or edited are
/// returned (edited ones carry a word-level diff of just that paragraph).
List<ParagraphChange> contentDiff(String oldText, String newText) {
  final oldParas = _tokenizeParagraphs(oldText);
  final newParas = _tokenizeParagraphs(newText);
  final paraOps = _diffTokens(oldParas, newParas);

  final changes = <ParagraphChange>[];
  var idx = 0;
  while (idx < paraOps.length) {
    if (paraOps[idx].type == DiffOpType.equal) {
      idx++;
      continue;
    }
    final deletes = <String>[];
    final inserts = <String>[];
    while (idx < paraOps.length && paraOps[idx].type != DiffOpType.equal) {
      if (paraOps[idx].type == DiffOpType.delete) {
        deletes.add(paraOps[idx].text);
      } else {
        inserts.add(paraOps[idx].text);
      }
      idx++;
    }
    if (deletes.isNotEmpty && inserts.isNotEmpty) {
      changes.add(ParagraphChange(ParagraphChangeType.modified,
          wordDiff(deletes.join('\n\n'), inserts.join('\n\n'))));
    } else if (deletes.isNotEmpty) {
      changes.add(ParagraphChange(ParagraphChangeType.removed,
          [DiffOp(DiffOpType.delete, deletes.join('\n\n'))]));
    } else {
      changes.add(ParagraphChange(ParagraphChangeType.added,
          [DiffOp(DiffOpType.insert, inserts.join('\n\n'))]));
    }
  }
  return changes;
}
