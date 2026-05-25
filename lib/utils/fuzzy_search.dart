import 'package:kumpas/data/signs_catalog.dart';

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9 ]"), '').trim();

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

double _similarity(String a, String b) {
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1.0;
  return 1.0 - (_levenshtein(a, b) / maxLen);
}

class SignScore {
  final Sign sign;
  final double score;
  const SignScore(this.sign, this.score);
}

List<SignScore> searchSigns(String query, {int limit = 8}) {
  final q = _normalize(query);
  if (q.isEmpty) return const [];

  final scored = <SignScore>[];
  for (final s in kSignCatalog) {
    final w = _normalize(s.word);
    final p = _normalize(s.pronunciation);

    double best = 0;

    if (w == q || p == q) {
      best = 1.0;
    } else {
      final wContains = w.contains(q) ? 0.95 : 0.0;
      final pContains = p.contains(q) ? 0.9 : 0.0;
      final wStarts = w.startsWith(q) ? 0.98 : 0.0;
      final pStarts = p.startsWith(q) ? 0.92 : 0.0;
      final wSim = _similarity(q, w);
      final pSim = _similarity(q, p) * 0.85;

      best = [wStarts, pStarts, wContains, pContains, wSim, pSim]
          .reduce((a, b) => a > b ? a : b);
    }

    if (best >= 0.45) scored.add(SignScore(s, best));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  if (scored.length > limit) return scored.sublist(0, limit);
  return scored;
}

Sign? bestSignMatch(String query) {
  final results = searchSigns(query, limit: 1);
  if (results.isEmpty) return null;
  return results.first.sign;
}
