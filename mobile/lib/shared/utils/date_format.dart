/// Formats an ISO 8601 timestamp into a human-readable "time ago" string.
///
/// - < 1 hour  → "Just now"
/// - < 24 hours → "3h ago"
/// - < 7 days   → "2d ago"
/// - older      → "15/6/2026"
String formatTimeAgo(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    final absDiff = diff.abs();

    if (absDiff.inHours < 1) return 'Just now';
    if (absDiff.inHours < 24) return '${absDiff.inHours}h ago';
    if (absDiff.inDays < 7) return '${absDiff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}
