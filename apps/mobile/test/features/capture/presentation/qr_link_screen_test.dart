import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/core/qr/pending_qr.dart';
import 'package:profesor_go/features/capture/presentation/qr_link_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const code = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PendingQr.take();
  });

  Future<GoRouter> openQr(WidgetTester tester, String value) async {
    final router = GoRouter(
      initialLocation: AppRoutes.map,
      routes: [
        GoRoute(
          path: AppRoutes.map,
          builder: (_, _) => const Scaffold(body: Text('map')),
        ),
        GoRoute(
          path: AppRoutes.scan,
          builder: (_, _) => const Scaffold(body: Text('scan')),
        ),
        GoRoute(
          path: AppRoutes.qrLinkPattern,
          builder: (_, state) =>
              QrLinkScreen(code: state.pathParameters['code'] ?? ''),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/qr=$value');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('an existing web tab saves the QR and opens the scanner', (
    tester,
  ) async {
    final router = await openQr(tester, code);
    expect(find.text('scan'), findsOneWidget);
    expect(await PendingQr.take(), code);
    router.dispose();
  });

  testWidgets('a malformed QR returns to the map without saving it', (
    tester,
  ) async {
    final router = await openQr(tester, 'short');
    expect(find.text('map'), findsOneWidget);
    expect(await PendingQr.take(), isNull);
    router.dispose();
  });
}
