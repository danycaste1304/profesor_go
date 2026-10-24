# Profesor GO — app móvil (Flutter)

Juego de captura de profesores para la feria universitaria: lee la tarjeta NFC
de un profesor, lanza la bola en el mini-juego y completa tu colección.

* Flutter 3.47 / Dart 3.13, Riverpod 3, go_router, supabase_flutter.
* Sin codegen (freezed / json_serializable): modelos escritos a mano en
  `lib/core/models/`.
* Los contratos (enums, endpoints, seed, rutas) están en `../../docs/CONTRACTS.md`.

## Ejecutar en modo demo (sin backend)

```bash
flutter pub get
flutter run            # DEMO_MODE=true por defecto
```

Con `DEMO_MODE=true` (el valor por defecto) la app funciona 100 % en memoria:

| Servicio                    | Implementación demo                                                     |
|-----------------------------|-------------------------------------------------------------------------|
| `AuthRepository`            | `MockAuthRepository`: cualquier correo válido + contraseña ≥ 6 sirve.   |
| `NfcService`                | `MockNfcService`: "lee" la tarjeta demo seleccionada (ver más abajo).   |
| `LocationService`           | `MockLocationService`: recorre `CampusConfig.demoPath`.                 |
| `ProfessorRepository`       | `MockProfessorRepository` sobre `DemoGameState` (10 profesores del seed).|
| `CaptureService`            | `MockCaptureService`: misma lógica que `resolve_capture_tx` (§9).       |

* Jugador demo: `player@profesorgo.local` / `player12345` (botón *Usar jugador
  demo* en el login). La sesión y las capturas se guardan en
  `SharedPreferences`, así que sobreviven a un reinicio.
* Al registrarte, la contraseña necesita **8 caracteres como mínimo**: es la
  política del backend (`supabase/config.toml` → `[auth]
  minimum_password_length = 8`). El cliente la replica en
  `AppConfig.minPasswordLength`, de donde salen el validador
  (`AuthValidators`), la etiqueta del campo y el mensaje `WEAK_PASSWORD`; si
  algún día cambia en Supabase, cámbiala ahí y los tres textos se actualizan
  solos. En modo demo `MockAuthRepository` aplica el mismo mínimo.
* Tarjetas demo `DEMO-TAG-01` … `DEMO-TAG-10` → Henry Carvajal,
  Felipe Grijalva, Jose David Vega, Ricardo Flores, Pavel Alba, Noel Perez,
  Daniel Riofrio, Erick Ñauñay, Diego Morales y Roberto Andrade.
  Daniel y Erick son legendarios; Felipe, Pavel y Noel son épicos;
  Ricardo y Diego son raros; Henry, Jose David y Roberto son comunes.
  La probabilidad de captura es la del contrato:
  `base_capture_rate + throw_bonus[quality]` (MISS siempre falla).

### Flujo de demostración

1. **Iniciar sesión** → el router te lleva a `/map` (barra de progreso,
   indicador de conexión, mapa del campus con el avatar y el interruptor
   *Simular movimiento* para recorrer el campus).
2. **CAPTURAR** → `/scan`. En modo demo elige una de las diez tarjetas de la
   lista; en modo real acerca el móvil a la tarjeta NFC física.
3. `/encounter/:id` → pon el dedo sobre la bola o cerca de ella, desliza hacia
   arriba y **suelta** antes de que acabe la cuenta atrás (180 s). Basta un
   gesto corto: la bola sale desde abajo y viaja hasta el profesor. La
   dirección horizontal determina la puntería y la calidad
   (MISS/GOOD/GREAT/EXCELLENT).
4. `/result` → *¡Capturaste a …!* o *… se escapó* (volver a leer la tarjeta).
5. **Ver colección** → `/collection` (Profedex con filtro por rareza) y
   `/collection/:id` (ficha). Al completar los 10 → `/completion`.
6. **Perfil → Tu personaje**: elige peinado, color de ropa y accesorio, o pulsa
   **Sorpréndeme**. La vista previa se anima al cambiar y el mismo sprite aparece
   en el mapa. Cada cuenta conserva su combinación en este dispositivo.

### Herramientas demo

* **Selector de tarjetas demo** en `/scan` ("TARJETAS DEMO"): toca un
  profesor para iniciar el encuentro. Está disponible en debug y release
  siempre que `DEMO_MODE=true`, para poder completar la colección sin hardware.
* **Reiniciar Profedex demo** en `/profile` (también en la APK de prueba): tras
  confirmarlo, borra capturas y encuentros del `DemoGameState` y su registro
  local. Conserva sesión, aspecto del avatar y preferencia de música.
* **Simular movimiento** en el mapa: inicia / pausa el paseo del
  `MockLocationService` por la ruta demo.
* **MÚSICA NO / SÍ** en el mapa: activa o silencia tres piezas chiptune
  originales para el mapa, el encuentro y la victoria, además de cinco efectos
  breves de lanzamiento, impacto, sacudida, captura y escape. Un solo reproductor
  acompaña toda la partida: combate → victoria → mapa, incluso si permaneces en
  la pantalla de resultado tras terminar la fanfarria. La elección se guarda en
  `SharedPreferences` y se aplica al volver a abrir la app. Empieza silenciada
  en la primera instalación.

### Arte y sonido

El mapa de campus, el avatar, los retratos demo, las plataformas de encuentro
y los cuadros de diálogo son originales y usan una estética de juego portátil
de píxeles. Los diálogos de encuentro y resultado aparecen progresivamente;
el texto completo queda disponible para accesibilidad y se muestra de inmediato
cuando el sistema desactiva las animaciones.
Los diez profesores usan sprites chibi de cuerpo completo durante el encuentro
y retratos pixelados basados en sus fotos para la colección. Conservan sus
rasgos personales con expresiones más juguetonas.

El mapa editable está en `assets/map/campus_map.svg`; para regenerar su PNG
sin suavizado usa `bash tool/generate_retro_map.sh` (requiere `rsvg-convert`). La
partitura y síntesis de las tres piezas están en `tool/generate_soundtrack.py`;
`python3 tool/generate_soundtrack.py` actualiza sus WAV sin dependencias externas.
Los cinco efectos originales se generan con `python3 tool/generate_sound_effects.py`.
La escena de encuentro muestra una guía de puntería proyectada y una etiqueta
animada de calidad mientras se arrastra la bola, un destello cuadrado al impactar, una barra de tiempo con
marco de RPG y un diálogo que indica cuándo soltar la bola.

## Ejecutar contra Supabase real

```bash
cp .env.example .env
# Edita .env:
#   SUPABASE_URL=http://<ip-del-pc>:54321      (supabase start en ../../supabase)
#   SUPABASE_ANON_KEY=<anon key de `supabase status`>
#   DEMO_MODE=false
flutter run --dart-define-from-file=.env
```

Equivalente con defines sueltos:

```bash
flutter run --dart-define=DEMO_MODE=false \
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Con `DEMO_MODE=false` se usan `SupabaseAuthRepository`,
`SupabaseProfessorRepository`, `SupabaseCaptureService` (Edge Functions
`start-encounter` / `resolve-capture`), `RealNfcService` (`nfc_manager`) y
`RealLocationService` (`geolocator`). Si faltan las credenciales o
`Supabase.initialize` falla, la app arranca igualmente en modo demo y lo
indica en el log (`AppConfig.demoFallbackReason`).

Para un móvil físico contra el Supabase local usa la IP de tu PC (no
`localhost`) y, en Android, tráfico HTTP en claro solo si tu build lo permite
(`android:usesCleartextTraffic`); en producción usa siempre `https`.

## Verificación

```bash
flutter analyze        # 0 issues
flutter test           # unitarios + widget + test/integration/demo_flow_test.dart
```

`test/integration/demo_flow_test.dart` es un *widget test* (no usa el paquete
`integration_test`) que monta la `App` real con los servicios demo inyectados
y recorre login → mapa → CAPTURAR → selección de `DEMO-TAG-01` → encuentro →
gesto real de lanzamiento → resultado *¡Capturaste a Prof. Henry!* → colección
1 / 10.

### Test LIVE contra el backend real (opt-in)

`test/live/supabase_live_test.dart` ejercita las clases reales
`SupabaseAuthRepository`, `SupabaseProfessorRepository` y
`SupabaseCaptureService` contra un Supabase **en marcha**, por HTTP de verdad y
sin móvil ni emulador. Se **salta solo** si no le pasas la URL y la anon key,
así que `flutter test` a secas sigue sin tocar la red.

```bash
# Con el stack local levantado (supabase start en ../../supabase):
flutter test test/live/supabase_live_test.dart \
  --dart-define=SUPABASE_LIVE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_LIVE_ANON_KEY="$(cd ../../supabase && supabase status -o json | jq -r .ANON_KEY)" \
  --dart-define=SUPABASE_LIVE_SERVICE_KEY="$(cd ../../supabase && supabase status -o json | jq -r .SERVICE_ROLE_KEY)"
```

Qué comprueba (11 tests): alta de un usuario nuevo con `data: {display_name}`
y lectura de su `profiles`; listado de profesores activos (los 10 del seed,
ordenados legendario → común, `sprite_url`/`description` nullable,
`base_capture_rate` numérico); `collection_progress()` a 0; `start-encounter`
con `DEMO-TAG-01` (`expires_at` ISO-8601 con milisegundos en UTC);
`resolve-capture` con `MISS` → `success: false` y el segundo intento
`ENCOUNTER_NOT_ACTIVE`; `EXCELLENT` sobre un profesor `COMMON` (p = 1,0) →
`success: true` y progreso 1; capturas filtradas por usuario; y los errores
`ALREADY_CAPTURED` (409), `TAG_NOT_FOUND` (404), `ENCOUNTER_NOT_FOUND` (404),
`INVALID_INPUT` (400) y `UNAUTHORIZED` (401) mapeados a su `AppException`.

* `SUPABASE_LIVE_SERVICE_KEY` es **opcional**: solo se usa para borrar el
  usuario desechable al terminar (`DELETE /auth/v1/admin/users/<id>`). Sin él
  el test pasa igual y avisa por consola del usuario que ha dejado atrás.
* No usa `Supabase.initialize()` (registra canales de plataforma que no
  existen bajo `flutter test`): crea el mismo `SupabaseClient` que reciben los
  repositorios en `lib/core/di/providers.dart`. Necesita además
  `HttpOverrides.global = null` —`flutter_test` responde a **toda** petición
  HTTP con un `400` vacío— y un `pkceAsyncStorage` en memoria, que en la app
  inyecta `Supabase.initialize`.
* El test crea solo su propio usuario; nunca toca las filas del seed.

No se necesita el SDK de Android para analizar ni testear. Para generar el APK
(`flutter build apk`) hace falta el Android SDK + JDK 17; para iOS, Xcode con
la capability *Near Field Communication Tag Reading* activada en el App ID.

### Firma del APK de release

`flutter build apk --release` funciona sin configuración: si no existe
`android/key.properties`, el build usa el **keystore de depuración**. Sirve para
probar en local o instalar por sideload, pero Google Play rechaza ese APK.

Para firmar de verdad, copia `android/key.properties.example` a
`android/key.properties` (está en `.gitignore`, nunca se commitea) y rellena
`storeFile`, `storePassword`, `keyAlias` y `keyPassword`; el fichero de ejemplo
incluye el comando `keytool` para crear el keystore. Si `key.properties` existe
pero le falta alguna de las cuatro claves, el build falla con un mensaje que la
nombra en vez de firmar con la clave equivocada.

### Icono de la aplicación

El icono de Profesor GO usa una ilustración original de mapa, esfera de captura y
birrete. Su fuente editable es `assets/branding/launcher_icon.svg`; los PNG de
Android e iOS se generan con `bash tool/generate_launcher_icons.sh` (requiere
`rsvg-convert` de librsvg y `jq`). El script copia el mismo SVG al panel admin
para su marca e icono de pestaña.

## Permisos de plataforma

* **Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET`, `NFC`,
  `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`; NFC declarado como
  `required="false"` (la app se instala en móviles sin NFC). `minSdk =
  flutter.minSdkVersion` (24): los módulos `nfc_manager` y `geolocator_android`
  se compilan con ese mismo mínimo. `MainActivity.kt` registra además el
  `MethodChannel` `edu.profesorgo/settings` con el método `openNfcSettings`
  (`Intent(Settings.ACTION_NFC_SETTINGS)`), que usa la pantalla `/scan` cuando el
  NFC está apagado. En iOS no existe esa pantalla: el botón no se muestra.
* **iOS** (`ios/Runner/Info.plist`): `NFCReaderUsageDescription`,
  `NSLocationWhenInUseUsageDescription`. El entitlement
  `com.apple.developer.nfc.readersession.formats` (`NDEF`, `TAG`) está en
  `ios/Runner/Runner.entitlements`, referenciado desde el target Runner con
  `CODE_SIGN_ENTITLEMENTS`. Hay que activar la capability *Near Field
  Communication Tag Reading* en el App ID (portal de Apple) antes de firmar.

## Estructura

```
lib/
  main.dart                 bootstrap (Supabase o demo) + ProviderScope(App)
  app/                      App, tema de exploración, GoRouter (rutas + guard de auth)
  core/
    config/                 AppConfig (dart-define), CampusConfig (bounds, demo path)
    models/                 Rarity, ThrowQuality, Professor, Encounter, Capture, ...
    errors/                 AppException (códigos + mensajes en español)
    nfc/  location/         abstracciones + implementaciones real / mock
    repositories/           ProfessorRepository, CaptureService, AuthRepository (+ Supabase / Mock)
    mock/                   seed demo (10 profesores, tags) y DemoGameState
    di/providers.dart       providers Riverpod (Mock vs Supabase según DEMO_MODE)
    widgets/                PixelCard, PixelButton, PixelIconButton, PixelPill (+ PixelFramePainter / PixelCirclePainter), RarityBadge, ProfessorSprite, ...
  features/
    auth/                   splash, login, register, AuthController
    map/                    mapa del campus, MapController, banner de colección completa
    capture/                /scan (NFC + selector demo), /encounter (mini-juego), /result
    collection/             Profedex, filtro por rareza, ficha del profesor
    profile/                perfil, cerrar sesión, reinicio demo
    progress/               /completion (celebración)
test/
  core/  features/          unitarios y widget tests por módulo
  integration/              demo_flow_test.dart (flujo completo con la App real)
  live/                     supabase_live_test.dart (opt-in, backend real)
```

Rutas (CONTRACTS §7): `/splash`, `/login`, `/register`, `/map`, `/scan`,
`/encounter/:encounterId`, `/result` (extra tipado `CaptureResultArgs`),
`/collection`, `/collection/:professorId`, `/profile`, `/completion`.

Consulta `FEATURE_GUIDE.md` antes de tocar `lib/features/*`.
