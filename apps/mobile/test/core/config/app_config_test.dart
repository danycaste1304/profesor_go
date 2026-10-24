import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/config/app_config.dart';

void main() {
  group('real backend configuration', () {
    String? validate(String url, String key, {bool release = false}) =>
        AppConfig.validateBackendConfiguration(
          url: url,
          anonKey: key,
          releaseMode: release,
        );

    test('rejects missing and malformed credentials', () {
      expect(validate('', 'key'), isNotNull);
      expect(validate('https://example.supabase.co', ''), isNotNull);
      expect(validate('not-a-url', 'key'), isNotNull);
    });

    test('allows local HTTP in debug but requires HTTPS in release', () {
      expect(validate('http://127.0.0.1:54321', 'key'), isNull);
      expect(
        validate('http://127.0.0.1:54321', 'key', release: true),
        isNotNull,
      );
      expect(
        validate('https://example.supabase.co', 'key', release: true),
        isNull,
      );
    });
  });
}
