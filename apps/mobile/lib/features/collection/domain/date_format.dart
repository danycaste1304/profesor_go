/// Tiny date formatting helpers (no `intl` dependency). Output uses the
/// device's local time zone.
library;

String _two(int n) => n < 10 ? '0$n' : '$n';

/// `dd/MM/yyyy` in local time.
String formatDate(DateTime dateTime) {
  final d = dateTime.toLocal();
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// `dd/MM/yyyy HH:mm` in local time.
String formatDateTime(DateTime dateTime) {
  final d = dateTime.toLocal();
  return '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';
}
