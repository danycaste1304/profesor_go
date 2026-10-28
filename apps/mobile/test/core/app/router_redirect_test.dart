import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/core/models/auth_user.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'a@b.c');
  const loading = AsyncLoading<AuthUser?>();
  const signedOut = AsyncData<AuthUser?>(null);
  const signedIn = AsyncData<AuthUser?>(user);

  test('while auth is loading everything goes to /splash', () {
    expect(appRedirect(loading, AppRoutes.map), AppRoutes.splash);
    expect(appRedirect(loading, AppRoutes.login), AppRoutes.splash);
    expect(appRedirect(loading, AppRoutes.splash), isNull);
  });

  test('signed out users are sent to /login except on public routes', () {
    expect(appRedirect(signedOut, AppRoutes.map), AppRoutes.login);
    expect(appRedirect(signedOut, AppRoutes.collection), AppRoutes.login);
    expect(appRedirect(signedOut, AppRoutes.splash), AppRoutes.login);
    expect(appRedirect(signedOut, AppRoutes.login), isNull);
    expect(appRedirect(signedOut, AppRoutes.register), isNull);
  });

  test('signed in users skip splash/login/register', () {
    expect(appRedirect(signedIn, AppRoutes.splash), AppRoutes.map);
    expect(appRedirect(signedIn, AppRoutes.login), AppRoutes.map);
    expect(appRedirect(signedIn, AppRoutes.register), AppRoutes.map);
    expect(appRedirect(signedIn, AppRoutes.map), isNull);
    expect(appRedirect(signedIn, AppRoutes.encounter('e1')), isNull);
  });

  test('auth errors are treated as signed out', () {
    final errored = AsyncError<AuthUser?>(Exception('x'), StackTrace.empty);
    expect(appRedirect(errored, AppRoutes.map), AppRoutes.login);
  });

  test('route helpers build contract paths', () {
    expect(AppRoutes.encounter('abc'), '/encounter/abc');
    expect(AppRoutes.professorDetail('p1'), '/collection/p1');
  });

  test('QR fragment has a route for an already-running web app', () {
    expect(AppRoutes.qrLinkPattern, '/qr=:code');
  });
}
