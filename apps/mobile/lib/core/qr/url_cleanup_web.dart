import 'package:web/web.dart' as web;

void removeQrFragment() {
  final uri = Uri.base;
  final clean = uri.replace(fragment: '');
  web.window.history.replaceState(null, '', clean.toString());
}
