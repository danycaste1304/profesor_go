# FEATURE_GUIDE — map for the feature agents (auth, map, capture, collection)

Everything shared already exists and compiles (`flutter analyze` + `flutter test`
are green). You own **only**:

| Agent      | Owns (create / overwrite freely)                                                                 |
|------------|--------------------------------------------------------------------------------------------------|
| auth       | `lib/features/auth/**`, `test/features/auth/**`                                                  |
| map        | `lib/features/map/**`, `test/features/map/**`                                                    |
| capture    | `lib/features/capture/**` (keep `domain/capture_result_args.dart` API), `test/features/capture/**` |
| collection | `lib/features/collection/**`, `test/features/collection/**`                                      |

`lib/features/profile/` and `lib/features/progress/` are placeholders; the
collection agent may replace `progress/presentation/completion_screen.dart`
and the auth agent may replace `profile/presentation/profile_screen.dart` if
they have time (keep the class names).

**Do NOT edit**: `pubspec.yaml`, `lib/main.dart`, `lib/app/*` (router, theme,
app), `lib/core/**`, `analysis_options.yaml`, platform folders. If you need a
new dependency or a core change, write it in your `notes_for_other_modules`.
No `freezed` / `json_serializable` / `build_runner` — plain Dart classes only.

Keep the **screen class names and constructors** exactly as the placeholders
declare them; `lib/app/router.dart` imports them by file path:

| Route (CONTRACTS §7)        | File                                                            | Widget / ctor                                              |
|-----------------------------|-----------------------------------------------------------------|------------------------------------------------------------|
| `/splash`                   | `features/auth/presentation/splash_screen.dart`                 | `SplashScreen()`                                           |
| `/login`                    | `features/auth/presentation/login_screen.dart`                  | `LoginScreen()`                                            |
| `/register`                 | `features/auth/presentation/register_screen.dart`               | `RegisterScreen()`                                         |
| `/map`                      | `features/map/presentation/map_screen.dart`                     | `MapScreen()`                                              |
| `/scan`                     | `features/capture/presentation/nfc_scan_screen.dart`            | `NfcScanScreen()`                                          |
| `/encounter/:encounterId`   | `features/capture/presentation/encounter_screen.dart`           | `EncounterScreen({required String encounterId})`           |
| `/result` (extra)           | `features/capture/presentation/capture_result_screen.dart`      | `CaptureResultScreen({required CaptureResultArgs args})`   |
| `/collection`               | `features/collection/presentation/collection_screen.dart`       | `CollectionScreen()`                                       |
| `/collection/:professorId`  | `features/collection/presentation/professor_detail_screen.dart` | `ProfessorDetailScreen({required String professorId})`     |
| `/profile`                  | `features/profile/presentation/profile_screen.dart`             | `ProfileScreen()`                                          |
| `/completion`               | `features/progress/presentation/completion_screen.dart`         | `CompletionScreen()`                                       |

## Navigation

```dart
import 'package:go_router/go_router.dart';
import 'package:profesor_go/app/router.dart';   // AppRoutes

context.go(AppRoutes.map);
context.push(AppRoutes.scan);
context.go(AppRoutes.encounter(encounter.id));            // '/encounter/<id>'
context.go(AppRoutes.result, extra: CaptureResultArgs(...)); // typed extra (required, else → /map)
context.push(AppRoutes.professorDetail(professor.id));    // '/collection/<id>'
context.go(AppRoutes.completion);
```

The router guard (`appRedirect`) is automatic: unauthenticated → `/login`;
authenticated on `/splash|/login|/register` → `/map`; while the auth stream is
loading everything shows `/splash`. You never navigate after sign-in/out —
just call the repository and the router reacts (`refreshListenable`).

## Providers (`lib/core/di/providers.dart`)

| Provider                        | Type                                   | Notes                                                        |
|---------------------------------|----------------------------------------|--------------------------------------------------------------|
| `nfcServiceProvider`            | `Provider<NfcService>`                 | Mock in demo mode (cast to `MockNfcService` for debug tools) |
| `locationServiceProvider`       | `Provider<LocationService>`            | Mock walks `CampusConfig.demoPath`                           |
| `professorRepositoryProvider`   | `Provider<ProfessorRepository>`        |                                                              |
| `captureServiceProvider`        | `Provider<CaptureService>`             |                                                              |
| `authRepositoryProvider`        | `Provider<AuthRepository>`             |                                                              |
| `connectivityProvider`          | `StreamProvider<bool>`                 | online?; always `true` in demo mode                          |
| `isOnlineProvider`              | `Provider<bool>`                       | sync view of the above (optimistic `true`)                   |
| `authStateProvider`             | `StreamProvider<AuthUser?>`            | drives the router guard                                      |
| `currentUserProvider`           | `Provider<AuthUser?>`                  | sync, null while loading / signed out                        |
| `profileProvider`               | `FutureProvider<Profile?>`             | `profiles` row (display name, role, `collectionCompletedAt`) |
| `professorsProvider`            | `FutureProvider<List<Professor>>`      | active professors, legendary first                           |
| `myCapturesProvider`            | `FutureProvider<List<Capture>>`        |                                                              |
| `collectionProgressProvider`    | `FutureProvider<CollectionProgress>`   | `{captured,total,completed}`                                 |
| `capturedIdsProvider`           | `Provider<Set<String>>`                | derived from `myCapturesProvider`                            |
| `demoGameStateProvider`         | `Provider<DemoGameState>`              | demo only (reset in debug tools)                             |
| `supabaseClientProvider`        | `Provider<SupabaseClient>`             | never read in demo mode                                      |

Helpers: `invalidateCollection(WidgetRef ref)` (from widgets) and
`invalidateCollectionFromProvider(Ref ref)` (from providers/notifiers) refresh
professors + captures + progress + profile. **Call one of them after a
successful capture.**

Riverpod is v3: `ref.watch(x).value` (nullable), `.when(data:, error:, loading:)`,
`ref.invalidate(p)`. Put feature state in `Notifier`/`AsyncNotifier` inside your
feature folder (`NotifierProvider`, `AsyncNotifierProvider`).

## Core APIs

### Config
```dart
AppConfig.isDemoMode        // bool (runtime-effective)
AppConfig.debugToolsEnabled // kDebugMode → teleport / reset; tag picker in all demo builds
CampusConfig.bounds         // CampusBounds {north,south,east,west}, .center, .contains(p), .clamp(p)
CampusConfig.mapWidth / mapHeight / mapSize      // 720 x 1290 logical px (9:16, matches campus_map.png)
CampusConfig.toMapOffset(LatLng) → Offset         // and fromMapOffset(Offset) → LatLng
CampusConfig.demoPath       // List<LatLng>
```

### Models (`lib/core/models/models.dart` barrel)
```dart
enum Rarity { common, rare, epic, legendary }
  .wireValue 'COMMON'…  .label 'Común/Rara/Épica/Legendaria'  .defaultCaptureRate  .rank (0..3)  Rarity.parse(s) / tryParse(s)
enum ThrowQuality { miss, good, great, excellent }  .wireValue .label .bonus(-1.0/0/0.10/0.20)  parse/tryParse
enum EncounterStatus { active, success, failed, expired }
enum UserRole { player, admin }

Professor { id, name, displayName, description?, rarity, spriteUrl?, active, baseCaptureRate, createdAt?, updatedAt? }
  .summary → ProfessorSummary, fromJson/toJson/copyWith, == by id
ProfessorSummary { id, displayName, rarity, spriteUrl?, description? }        // shape inside Encounter
Encounter { id, expiresAt (UTC), professor: ProfessorSummary, status, createdAt? }
  .isExpired, .remaining (Duration), .isExpiredAt(now), .remainingAt(now)
Capture { id, userId, professorId, encounterId?, throwQuality, capturedAt }
CaptureResult { success, professorId?, collection?: CollectionProgress, retryRequiresNewNfcScan }
CollectionProgress { captured, total, completed }  .ratio
  CollectionProgress.compute(professors:, captures:)
  CollectionProgress.byRarity(professors:, captures:) → Map<Rarity, RarityProgress{rarity,captured,total,.ratio,.completed}>
Profile { id, email, displayName?, role, createdAt?, collectionCompletedAt? }  .nameOrEmail .hasCompletedCollection
AuthUser { id, email, displayName? }
LatLng(latitude, longitude)  .distanceTo(other) meters
```

### Errors (`lib/core/errors/app_exception.dart`)
```dart
try { await service.startEncounter(tag); }
on AppException catch (e) { showSnackBar(e.message); if (e.code == AppException.alreadyCaptured) ... }
// Unknown errors: AppException.from(error).message  (Spanish, never a stack trace)
```
Codes: `AppException.noInternet, nfcUnsupported, nfcDisabled, nfcCancelled,
nfcReadError, tagNotFound, tagDisabled, professorDisabled, alreadyCaptured,
encounterExpired, encounterNotActive, encounterNotFound, forbidden, unauthorized,
invalidInput, invalidCredentials, emailTaken, weakPassword, locationDenied,
locationDisabled, serverUnavailable, unknown`. Messages: `AppException.messages[code]`.

### Services / repositories (abstract; always depend on these)
```dart
abstract class NfcService {
  Future<String?> scanTag();                 // null = cancelled / timeout; throws AppException
  Future<NfcAvailability> availability();    // available | disabled | unsupported
  Future<void> cancel();
}
class MockNfcService implements NfcService { // demo only
  Future<List<DemoTag>> demoTags();          // DemoTag { identifier, label, professorId? }
  DemoTag selectedTag; void selectTag(String identifier);
  set availabilityOverride(NfcAvailability v);
}

abstract class LocationService {
  Stream<LatLng> positions();
  Future<LocationStatus> checkAndRequest();  // available | denied | deniedForever | serviceDisabled
}
class MockLocationService implements LocationService {
  LatLng get current; bool get isWalking;
  void teleport(LatLng p); void resumeWalk(); void step();
}

abstract class ProfessorRepository {
  Future<List<Professor>> getActiveProfessors();
  Future<List<Capture>> getMyCaptures();
  Future<CollectionProgress> getProgress();
  ProfessorCache get cache;                  // .professors / .captures / .progress last known (offline)
}

abstract class CaptureService {
  Future<Encounter> startEncounter(String tagIdentifier);
  Future<CaptureResult> resolveCapture({required String encounterId, required ThrowQuality quality});
  Encounter? cachedEncounter(String encounterId);   // recover professor/expiry from the route param
  Encounter? get lastEncounter;
}

abstract class AuthRepository {
  Stream<AuthUser?> authState();
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, {String? displayName});
  Future<void> signOut();
  AuthUser? get currentUser;
  Future<Profile?> getProfile();
}
```

Capture flow (capture agent):
1. `/scan`: check `ref.read(isOnlineProvider)` → if offline show
   `AppException.messages[AppException.noInternet]`; else `nfcServiceProvider.scanTag()`
   → `captureServiceProvider.startEncounter(tag)` → `context.go(AppRoutes.encounter(e.id))`.
   In demo mode, when `AppConfig.debugToolsEnabled`, cast `ref.read(nfcServiceProvider)`
   to `MockNfcService` to offer the tag picker (`demoTags()` / `selectTag`).
   NFC off (`NfcAvailability.disabled`) → message + "Abrir ajustes de NFC"
   (`nfcSettingsOpenerProvider`, hidden unless `canOpenNfcSettingsProvider`: Android
   only) + "Reintentar". The opener talks to the `edu.profesorgo/settings`
   `MethodChannel` (`openNfcSettings`, implemented in `MainActivity.kt`) and returns
   false — snackbar, never a crash — when the channel or the activity is missing.
2. `/encounter/:id`: `ref.read(captureServiceProvider).cachedEncounter(id)` (null → go
   back to `/scan` with `encounterNotFound` message). Show `ProfessorSprite`,
   `RarityBadge`, a countdown from `encounter.remaining`; on throw call
   `resolveCapture(encounterId:, quality:)`.
3. On result: `invalidateCollection(ref)`, then
   `context.go(AppRoutes.result, extra: CaptureResultArgs(professor: e.professor, success: r.success, collection: r.collection, quality: q))`.
   `CaptureResultArgs.collectionCompleted` → offer `AppRoutes.completion`.
   Failure (`retryRequiresNewNfcScan`) → button back to `/scan`.

### Widgets (`lib/core/widgets/widgets.dart` barrel)
```dart
AppScaffold({required body, title?, actions?, leading?, showAppBar = true, padding = 16, bottomBar?, floatingActionButton?})
PixelCard({required child, padding, color?, borderColor?, onTap?, shadow = true, semanticLabel?})
PixelButton({required label, required onPressed, variant: PixelButtonVariant.primary|secondary|danger, loading = false, icon?, expand = true})
                                                             // pixel art: frame by PixelFramePainter (4 px blocks); label font from theme (AppTheme.displayFontFamily)
PixelIconButton({required icon, required semanticLabel, required onPressed, toggled?, size = 48, iconSize = 22})
                                                             // circular pixel-art icon button, no label (music toggle); toggled: true = accent face
RarityBadge(rarity, {compact = false})                       // icon + text + color
ProfessorSprite({required professorId, spriteUrl?, size = 96, silhouette = false, semanticLabel?})
ProgressBar({required value, required total, label?, color?, height = 22, showCount = true})
CaptureBall({size = 96, topColor, bottomColor, bandColor})   // CustomPainter, no assets
ErrorView({required message, onRetry?})  /  ErrorView.fromError(error, onRetry: ...)
LoadingView({message?, size = 72})
```
Theme helpers (`lib/app/theme.dart`): `AppColors.*` (background, surface,
surfaceAlt, border, accent, accentAlt, danger, success, text, textMuted),
`AppTheme.rarityColor(rarity)`, `AppTheme.rarityIcon(rarity)`,
`AppTheme.minButtonHeight` (56). `flutter_animate` is available for effects.

## Testing
* Unit tests: construct the mocks directly — `MockCaptureService(DemoGameState(clock: () => now), random: FixedRandom(0), delay: Duration.zero)`
  (see `test/core/repositories/mock_capture_service_test.dart` for `FixedRandom`).
* Widget tests: wrap in `ProviderScope(overrides: [captureServiceProvider.overrideWithValue(fake), ...], child: MaterialApp(theme: AppTheme.dark(), home: YourScreen()))`.
  For screens that call `context.go`, build a `GoRouter` in the test or use `MaterialApp.router`.
* Any test that hits SharedPreferences (only the real providers do) needs
  `SharedPreferences.setMockInitialValues({})` in `setUp`.
* `mocktail` is available for fakes of the abstract services.

All UI text in Spanish; identifiers/comments in English; rarity always with a
text label (never color-only); primary buttons ≥ 56 dp.
