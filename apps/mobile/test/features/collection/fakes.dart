import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/auth_repository.dart';
import 'package:profesor_go/core/repositories/professor_repository.dart';
import 'package:profesor_go/features/collection/domain/collection_filter.dart';
import 'package:profesor_go/features/collection/presentation/collection_screen.dart';
import 'package:profesor_go/features/collection/presentation/professor_detail_screen.dart';
import 'package:profesor_go/features/progress/presentation/completion_screen.dart';

/// In-memory [ProfessorRepository] whose calls can be made to fail.
class FakeProfessorRepository implements ProfessorRepository {
  FakeProfessorRepository({
    List<Professor>? professors,
    List<Capture>? captures,
    this.professorsError,
    this.capturesError,
  }) : professors = professors ?? demoProfessors,
       captures = captures ?? const [];

  List<Professor> professors;
  List<Capture> captures;
  Object? professorsError;
  Object? capturesError;
  int professorCalls = 0;
  int captureCalls = 0;

  @override
  final ProfessorCache cache = ProfessorCache(persistent: false);

  @override
  Future<List<Professor>> getActiveProfessors() async {
    professorCalls++;
    if (professorsError != null) throw professorsError!;
    final list = professors.where((p) => p.active).toList();
    await cache.saveProfessors(list);
    return list;
  }

  @override
  Future<List<Capture>> getMyCaptures() async {
    captureCalls++;
    if (capturesError != null) throw capturesError!;
    await cache.saveCaptures(captures);
    return captures;
  }

  @override
  Future<CollectionProgress> getProgress() async {
    final p = progressFor(professors, captures);
    await cache.saveProgress(p);
    return p;
  }

  @override
  Future<void> resetMyCollection() async {
    captures = [];
    await cache.clear();
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.profile, this.profileError, AuthUser? user})
    : user = user ?? const AuthUser(id: 'u1', email: 'test@uni.edu');

  Profile? profile;
  Object? profileError;
  AuthUser? user;

  @override
  Stream<AuthUser?> authState() => Stream.value(user);

  @override
  AuthUser? get currentUser => user;

  @override
  Future<Profile?> getProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {}
}

Capture captureOf(String professorId, {DateTime? at, ThrowQuality? quality}) =>
    Capture(
      id: 'cap-$professorId',
      userId: 'u1',
      professorId: professorId,
      encounterId: 'enc-$professorId',
      throwQuality: quality ?? ThrowQuality.great,
      capturedAt: at ?? DateTime.utc(2026, 9, 16, 10, 30),
    );

/// App shell with the collection / detail / completion routes plus a stub map,
/// wired to the fakes through a [ProviderScope].
Widget buildCollectionApp({
  required FakeProfessorRepository repository,
  FakeAuthRepository? auth,
  bool online = true,
  String initialLocation = '/collection',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/map',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('MAP STUB'))),
      ),
      GoRoute(
        path: '/collection',
        builder: (_, _) => const CollectionScreen(),
        routes: [
          GoRoute(
            path: ':professorId',
            builder: (_, state) => ProfessorDetailScreen(
              professorId: state.pathParameters['professorId']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/completion', builder: (_, _) => const CompletionScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(repository),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      connectivityProvider.overrideWithValue(AsyncValue.data(online)),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}
