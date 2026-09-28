/// Turns a caught error into a short, user-facing message. Screens must never
/// render raw exception/stack text — a finance app should stay calm and
/// trustworthy, not leak `Exception: ...` blobs at the user.
///
/// ponytail: thin heuristic mapping. If the native bridge starts returning
/// typed/coded errors, switch on those instead of string-cleaning here.
String userMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final cleaned = error
      .toString()
      .replaceFirst(
        RegExp(r'^(Exception|Error|StateError|FormatException|_Exception):\s*'),
        '',
      )
      .trim();

  // Empty, multi-line, over-long, or stack-shaped text is internal noise.
  if (cleaned.isEmpty ||
      cleaned.length > 140 ||
      cleaned.contains('\n') ||
      cleaned.contains('#0 ')) {
    return fallback;
  }
  return cleaned;
}
