# Privacidad

Qué datos trata Profesor GO, cuáles **no** trata y dónde está implementada cada garantía.
Cada afirmación de este documento apunta al fichero que la implementa para que se pueda
verificar leyendo el código, no confiando en la documentación.

## Resumen

| Dato                                   | ¿Se guarda?                          | Dónde |
|----------------------------------------|--------------------------------------|-------|
| Posición GPS del jugador               | **No** (solo el último punto, en RAM)| `MapState.current` |
| Historial de posiciones / recorrido    | **No**                               | — |
| Última posición del profesor anfitrión | Sí, solo durante la búsqueda         | `public.hunt_sessions` |
| Cámara para escanear QR                 | Permiso mientras se usa; no se suben imágenes | `QrScanScreen` |
| Biometría, fotos guardadas, audio grabado | **No** | — |
| Email                                  | Sí                                   | `auth.users`, `public.profiles.email` |
| Nombre visible (`display_name`)        | Sí, opcional                         | `public.profiles.display_name` |
| Progreso de juego (encuentros/capturas)| Sí                                   | `public.encounters`, `public.captures` |
| Identificador de NFC                   | Sí, como relación con profesor       | `public.nfc_tags` |
| Credencial QR impresa                  | Solo hash en servidor; pendiente temporal en el dispositivo | `public.professor_qr_codes`, `PendingQr` |
| Hallazgo de la feria                   | Sí, una vez por alumno y búsqueda    | `public.hunt_checkins` |

## 1. Ubicación (GPS)

Para los jugadores, la app usa la ubicación para dibujar su avatar sobre el mapa del campus.
Sobre ese dato:

- **Solo se conserva el último punto conocido, y solo en memoria.** El estado del mapa
  (`apps/mobile/lib/features/map/presentation/map_controller.dart`) tiene un único campo
  `current` de tipo `LatLng?`; no hay lista, cola ni buffer de posiciones. Al cerrar la
  pantalla el estado se descarta.
- **No se persiste ni se envía al servidor.** No hay clave de `SharedPreferences` ni
  columna para las coordenadas del jugador. Las coordenadas de `hunt_sessions` son
  únicamente las que publica la cuenta vinculada al profesor anfitrión.
- **La captura no depende del GPS.** Lo que autoriza un encuentro es la lectura NFC o QR
  del profesor, no una comprobación de proximidad por coordenadas, así que el backend no
  necesita la ubicación ni siquiera de forma transitoria.
- **PostGIS no almacena recorridos.** El evento conserva un solo par latitud/longitud
  en `hunt_sessions`, sin historial de puntos.
- **En modo demo no se toca el GPS real:** `MockLocationService` recorre una ruta simulada
  (`DEMO_MODE=true`, ver `docs/architecture.md`).

Textos de permiso que ve el usuario:

- iOS (`apps/mobile/ios/Runner/Info.plist`), `NSLocationWhenInUseUsageDescription`:
  explica el mapa del jugador y la búsqueda voluntaria del profesor. Es *when in use*:
  no hay permiso de ubicación en segundo plano.
- Android (`apps/mobile/android/app/src/main/AndroidManifest.xml`):
  `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION`. No se declara
  `ACCESS_BACKGROUND_LOCATION`.

## 2. Posiciones de los profesores

El profesor anfitrión inicia voluntariamente una búsqueda de 30 minutos desde su cuenta
vinculada y mantiene abierta la pantalla de publicación. `hunt_sessions` guarda solo su
última posición, precisión y hora. La app intenta actualizarla cada 10 segundos; rechaza
una precisión peor que 100 metros. Los estudiantes autenticados solo pueden consultar la
posición mientras la sesión esté activa y la ubicación tenga menos de 30 segundos. Al
detenerse, se borra inmediatamente; al expirar, la RLS deja de exponerla y una tarea
programada la borra dentro de aproximadamente un minuto. No se guarda el recorrido.

El marcador representa una posición GPS aproximada; no garantiza que el profesor siga
exactamente allí. El QR impreso se puede fotografiar y compartir: escanearlo registra el
hallazgo, pero no demuestra presencia física. El administrador puede desactivarlo o
reemplazarlo. Las credenciales QR se guardan solo como hash; los estudiantes no pueden
listar los códigos ni los identificadores de `nfc_tags`.

## 3. Cámara, biometría y fotos

La cámara se solicita al abrir el lector QR en Android o Safari. `mobile_scanner` procesa
los fotogramas en el dispositivo para extraer la URL; la app envía al backend solo la
credencial del QR y no sube imágenes ni vídeo. La URL se quita de la barra del navegador
al abrir el juego. No se usa biometría, galería ni grabación de audio.

- Android: `INTERNET`, `CAMERA`, `NFC`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- Safari: permiso del navegador para cámara y ubicación opcional; requiere HTTPS.
- iOS nativo, si se compila: `NFCReaderUsageDescription` y `NSLocationWhenInUseUsageDescription`.

El jugador no sube ni un solo fichero: su avatar se dibuja en la app y sus elecciones
cosméticas se guardan por cuenta en el dispositivo con `SharedPreferences`. Los únicos
ficheros del Storage son los sprites de los profesores y los assets del juego, de
escritura solo admin.

## 4. Datos personales que sí se guardan

Son los mínimos para tener una cuenta y un progreso:

- `auth.users` (gestionado por Supabase Auth): email y hash de la contraseña.
- `public.profiles`: `email`, `display_name` (opcional, lo elige el jugador al registrarse),
  `role`, `created_at` y `collection_completed_at`.
- `public.encounters` y `public.captures`: qué profesor, cuándo, con qué resultado.
- `public.hunt_checkins`: alumno, sesión, tarjeta NFC o profesor del QR y hora de hallazgo. Se conserva para
  verificar el punto extra; no contiene coordenadas del alumno.

No se recoge teléfono, fecha de nacimiento, dirección, identificador de dispositivo ni
publicitario. **No hay SDK de analítica, telemetría ni crash reporting** en la app móvil ni
en el panel admin (ni Firebase, ni Sentry, ni Crashlytics, ni equivalentes en
`apps/mobile/pubspec.yaml` ni en `apps/admin/package.json`).

## 5. Qué queda en el dispositivo

- La sesión de Supabase Auth (tokens + PKCE) en `SharedPreferences`, escrita por
  `Supabase.initialize` (`apps/mobile/lib/main.dart`). Se borra al cerrar sesión.
- Si el profesor usa la página web de anfitrión, Safari conserva su sesión de
  Supabase en el almacenamiento local de ese navegador hasta que cierre sesión
  allí o caduque. La página no guarda coordenadas en ese almacenamiento.
- Una caché de juego: profesores, capturas y progreso
  (`apps/mobile/lib/core/repositories/professor_repository.dart`) y, en modo demo, el
  estado simulado (`apps/mobile/lib/core/mock/demo_game_state.dart`).

Ninguna de esas claves contiene coordenadas.

## 6. Quién puede ver qué

Lo impone la RLS, no la interfaz (resumen completo en `docs/database.md`):

- Un jugador solo lee **su** fila de `profiles`, **sus** encuentros y **sus** capturas, y
  los profesores activos. No puede leer las filas de otros jugadores ni `nfc_tags`.
- Un jugador no puede escribir en `captures`, `encounters` ni directamente en las tablas
  de búsqueda. El hallazgo se crea mediante la RPC `check_in_campus_hunt` al leer un tag
  de una búsqueda activa.
- Un administrador puede leer `profiles` y el panel de búsqueda muestra y exporta los
  nombres/correos de quienes registraron hallazgo, para entregar el punto extra.
- Los usuarios anónimos no leen nada: todas las políticas son `to authenticated`.

## 7. Registros del servidor

Las Edge Functions escriben un log JSON por línea (`supabase/functions/_shared/log.ts`)
con identificadores (`user_id`, `encounter_id`, `professor_id`, `tag_id`), el evento y el
resultado. `redact()` elimina cualquier campo cuyo nombre parezca un secreto
(`authorization`, `token`, `jwt`, `password`, `api_key`, `service_role`…) y cualquier valor
con forma de JWT. **No se registran emails ni coordenadas.**

## 8. Borrado de datos

Borrar el usuario en `auth.users` elimina en cascada su fila de `profiles` y, desde ahí,
sus `encounters`, `captures` y `hunt_checkins` (`on delete cascade`). Si era una cuenta
publicadora, se eliminan también su asignación y sus sesiones. No queda ningún dato del jugador salvo las
líneas de log del servidor, que contienen solo su UUID.

## 9. Si esto cambia

Cualquier cambio que añada historial de coordenadas, biometría, fotos o analítica requiere
revisar este documento y `docs/CONTRACTS.md`.
