/// Detects, by keyword match (no model call), that the student is explicitly
/// asking the tutor to solve the problem, so the pen should write the full
/// worked solution instead of asking one guiding question at a time.
bool isSolveIntent(String text) {
  final String t = text
      .toLowerCase()
      .replaceAll(RegExp(r"[’‘`]"), "'")
      .replaceAll(RegExp(r'[^a-z0-9À-ỿ\s\x27]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return false;
  const List<String> guideOnly = <String>[
    'without giving',
    'without the answer',
    'how to start',
    'give me a hint',
  ];
  if (guideOnly.any(t.contains)) return false;

  const List<String> negations = <String>[
    "don't",
    'dont',
    'do not',
    'never',
    "no need to",
    'without',
    'not ask',
  ];
  const List<String> phrases = <String>[
    'solve this for me',
    'solve it for me',
    'solve that for me',
    'solve for me',
    'just solve',
    'solve it',
    'solve this',
    'show me how',
    'show me the solution',
    'show me the working',
    'work it out for me',
    'do it for me',
    'give me the solution',
    'full solution',
    'worked solution',
    'show me the steps',
  ];

  for (final String p in phrases) {
    final int at = t.indexOf(p);
    if (at < 0) continue;
    final String before = t.substring(at < 14 ? 0 : at - 14, at);
    if (negations.any(before.contains)) continue;
    return true;
  }
  return false;
}
