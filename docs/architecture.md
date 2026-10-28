# Arquitectura

Profesor GO es un monorepo con tres piezas que comparten un único backend Supabase.

```text
┌──────────────────────┐        ┌───────────────────────────┐        ┌────────────────────┐
│  apps/mobile         │        │  supabase/                │        │  apps/admin        │
│  Flutter + Riverpod  │ ─────▶ │  Postgres + Auth + Storage│ ◀───── │  Next.js + Tailwind│
│  GoRouter            │  JWT   │  Edge Functions (Deno)    │  JWT   │  @supabase/ssr     │
└──────────────────────┘        └───────────────────────────┘        └────────────────────┘
```

## Principios

1. **El servidor decide.** Todo lo que afecta al progreso (crear un encuentro, resolver una
   captura, marcar la colección como completa) ocurre en Edge Functions con `service_role`
   y en un RPC transaccional (`resolve_capture_tx`). El cliente solo envía `throw_quality`.
2. **Feature-first + clean architecture ligera.** Cada feature de Flutter tiene
   `domain/` (lógica pura, testeable), `data/` cuando aplica y `presentation/`
   (pantallas, controladores Riverpod, widgets).
3. **Demo mode como ciudadano de primera clase.** Con `DEMO_MODE=true` la app corre sin
   backend, sin GPS y sin NFC gracias a `Mock*` que reproducen las reglas del servidor.
4. **Sin sobrearquitectura.** Sin codegen (freezed/build_runner) para mantener el proyecto
   liviano y permitir trabajo paralelo; los modelos son clases Dart inmutables con
   `fromJson/toJson/copyWith` manuales.

## Flujo principal

```text
Splash → (auth guard) → Map
Map → CAPTURAR → NFC Scan → start-encounter → Encounter (minijuego)
Encounter → resolve-capture → Result → Map | Collection
Collection completa → Completion
Profesor vinculado → inicia búsqueda → publica último GPS → estudiantes ven marcador
Estudiante → NFC Scan → check_in_campus_hunt → hallazgo para la feria
```

## Capas en Flutter

```text
lib/
├── app/          MaterialApp.router, GoRouter (guard de auth), tema de exploración
├── core/
│   ├── config/   AppConfig (dart-define), CampusConfig (bounds + tamaño del mapa)
│   ├── di/       Providers Riverpod: eligen Mock vs Supabase según DEMO_MODE
│   ├── errors/   AppException → mensajes amigables en español
│   ├── location/ LocationService (Real/Mock)
│   ├── hunt/     HuntService (sesiones y hallazgos de la feria)
│   ├── models/   Professor, Rarity, Encounter, Capture, CollectionProgress, Profile
│   ├── nfc/      NfcService (Real/Mock)
│   ├── repositories/ ProfessorRepository, CaptureService, AuthRepository (Supabase/Mock)
│   └── widgets/  PixelCard, PixelButton, RarityBadge, ProfessorSprite, ProgressBar, CaptureBall
└── features/
    ├── auth/        Splash, Login, Register, AuthController
    ├── map/         CampusMap demo, mapa geográfico real, avatar, MapScreen (hub)
    ├── hunt/        pantalla del profesor anfitrión, publicación GPS en primer plano
    ├── capture/     NFC scan, Encounter + minijuego, ThrowQuality, Result
    ├── collection/  Profedex, detalle de profesor, filtros
    ├── profile/     Perfil, logout
    └── progress/    CompletionScreen
```

Las garantías de accesibilidad de esos widgets (rareza con texto e icono, objetivos
táctiles, contraste medido, háptica, tamaños de letra y `Semantics`) están documentadas en
[`docs/game-design.md` § Accesibilidad](game-design.md#accesibilidad).

## Modo sin conexión

La app sigue siendo útil sin red para *consultar*, nunca para *progresar*.

**Qué se cachea.** `ProfessorCache`
(`apps/mobile/lib/core/repositories/professor_repository.dart`) guarda el último valor
conocido de tres cosas, en memoria y —salvo que se construya con `persistent: false`— también
en `SharedPreferences`, como JSON:

| Dato | Clave de `SharedPreferences` |
|------|------------------------------|
| Profesores activos | `cache.professors` |
| Capturas del jugador | `cache.captures.<userId>` |
| Progreso de la colección (`captured/total/completed`) | `cache.progress.<userId>` |

`SupabaseProfessorRepository` escribe en la caché cada vez que una petición va bien, y solo
recurre a ella cuando el fallo es de conectividad (`NO_INTERNET`) o el backend no responde
(`SERVER_UNAVAILABLE`). Una sesión caducada o un error de permisos **no** se tapan con datos
viejos: se propagan para que la UI reaccione (`_orCache` en
`supabase_professor_repository.dart`). No se cachea nada más: ni tarjetas NFC, ni encuentros,
ni ubicaciones (ver [`docs/privacy.md`](privacy.md)).

**Qué ve el jugador.** Se muestra el último estado conocido con un aviso, nunca una pantalla
vacía:

- La colección y el detalle de profesor pintan los datos cacheados con la banda
  `CachedDataBanner` arriba: **«Mostrando datos guardados»** (`collection_widgets.dart`). Se
  activa con `CollectionData.fromCache`, que también cubre el caso «hay caché caliente y la
  petición aún está en vuelo».
- El hub del mapa lleva un indicador permanente de conexión: **EN LÍNEA** / **SIN CONEXIÓN**
  (icono + texto + color, `liveRegion` para lectores de pantalla).
- El estado de conexión viene de `connectivityProvider` (`connectivity_plus`), optimista:
  se asume `true` hasta el primer evento, y en `DEMO_MODE=true` siempre es `true`.

**Capturar exige backend, siempre.** No hay cola offline ni capturas optimistas: el
encuentro y su resolución los crea y decide el servidor (ver
[Anti-trampas](game-design.md#anti-trampas-mínimo-del-mvp)). Sin red:

- el botón **Capturar** del mapa se deshabilita y debajo aparece, en rojo,
  `No puedes iniciar una captura sin conexión.` (`MapScreen.offlineCaptureMessage`);
- si se llega a la pantalla de lectura NFC, esta muestra el estado «Sin conexión» con el
  mensaje canónico de `AppException.NO_INTERNET`:
  `Sin conexión. No puedes iniciar una captura sin conexión.`, un botón *Reintentar*, y
  reanuda sola el escaneo en cuanto vuelve la conexión;
- iniciar sesión o registrarse se corta antes de salir a la red con
  `Sin conexión. Comprueba tu internet e inténtalo de nuevo.` (`AuthController`).

## Backend

- **Postgres** con RLS estricta (ver `docs/database.md`).
- **Edge Functions** (`supabase/functions`): `start-encounter`, `resolve-capture`,
  `admin-register-nfc`. Comparten `_shared/` (auth, errores, CORS, logging).
- **Storage**: buckets `professor-sprites` y `game-assets` (lectura pública, escritura admin),
  restringidos en el servidor por tipo y tamaño: sprites `image/png|jpeg|webp|gif` hasta 2 MiB;
  `game-assets` añade `audio/mpeg|ogg` hasta 5 MiB. SVG queda fuera a propósito (XSS almacenado
  en un bucket público). Limitación conocida: Storage confía en el `Content-Type` declarado por
  el cliente y no inspecciona los bytes, así que el allowlist frena el caso accidental, no a un
  administrador malicioso; el navegador, aun así, sirve el objeto como la imagen declarada.
- **Búsqueda de la feria:** `hunt_publishers`, `hunt_sessions` y `hunt_checkins` con RLS.
  El profesor publica su último punto mediante RPC y `pg_cron` limpia posiciones
  vencidas. PostGIS está habilitado, pero esta función usa columnas latitud/longitud.

## Privacidad

Garantías de diseño, no solo de interfaz; cada una es verificable en el código y está
detallada en [`docs/privacy.md`](privacy.md):

- **Ubicación del jugador:** la app guarda únicamente el último punto conocido y solo en
  memoria (`MapState.current`); no persiste historial ni lo envía al servidor.
- **Ubicación del profesor anfitrión:** solo la última posición de una sesión voluntaria
  de 30 minutos. La RLS solo la muestra fresca y activa a usuarios autenticados; se
  borra al detener o expirar la actividad.
- **Cámara para QR, sin biometría ni fotos guardadas:** el lector procesa la imagen
  localmente y envía solo el código extraído. Android solicita cámara, NFC,
  ubicación *when in use* e internet; Safari solicita cámara y ubicación opcional.
- **Datos personales persistidos:** email, `display_name`, progreso y hallazgos NFC/QR
  de la feria. Sin analítica, telemetría ni crash reporting.

## Admin

Next.js App Router con `@supabase/ssr`. El middleware refresca la sesión y solo deja pasar
perfiles con `role = 'admin'`. Las operaciones CRUD usan las políticas RLS de admin; el
registro de tags NFC pasa por la Edge Function `admin-register-nfc`. La ruta `/qr`
rota e imprime credenciales por profesor. La ruta `/hunt` vincula la cuenta del
profesor y muestra/exporta los hallazgos.

## Extensión futura

El diseño deja espacio (sin implementar) para: recompensas al completar la colección,
tags NFC criptográficos (ver `docs/nfc.md`), ranking, misiones. Todo lo que no está en el
MVP se mantuvo fuera del código para no añadir complejidad.
