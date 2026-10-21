# Privacidad

Qué datos trata Profesor GO, cuáles **no** trata y dónde está implementada cada garantía.
Cada afirmación de este documento apunta al fichero que la implementa para que se pueda
verificar leyendo el código, no confiando en la documentación.

## Resumen

| Dato                                   | ¿Se guarda?                          | Dónde |
|----------------------------------------|--------------------------------------|-------|
| Posición GPS del jugador               | **No** (solo el último punto, en RAM)| `MapState.current` |
| Historial de posiciones / recorrido    | **No**                               | — |
| Posición de los profesores             | **No**                               | — |
| Biometría, cámara, fotos               | **No** (no se piden permisos)        | — |
| Email                                  | Sí                                   | `auth.users`, `public.profiles.email` |
| Nombre visible (`display_name`)        | Sí, opcional                         | `public.profiles.display_name` |
| Progreso de juego (encuentros/capturas)| Sí                                   | `public.encounters`, `public.captures` |
| Identificador del tag NFC leído        | Sí, asociado al encuentro            | `public.nfc_tags`, `public.encounters` |

## 1. Ubicación (GPS)

La app pide la ubicación con un único fin: **dibujar el avatar del jugador sobre el mapa
del campus**. Sobre ese dato:

- **Solo se conserva el último punto conocido, y solo en memoria.** El estado del mapa
  (`apps/mobile/lib/features/map/presentation/map_controller.dart`) tiene un único campo
  `current` de tipo `LatLng?`; no hay lista, cola ni buffer de posiciones. Al cerrar la
  pantalla el estado se descarta.
- **No se persiste nunca.** No hay clave de `SharedPreferences` con coordenadas y no
  existe ninguna columna de latitud/longitud, `geography` o `geometry` en el esquema
  (`supabase/migrations/20260916000200_schema.sql`).
- **No se envía nunca al servidor.** Los únicos cuerpos que la app manda a las Edge
  Functions son `{"tag_identifier": …}` y `{"encounter_id": …, "throw_quality": …}`
  (`docs/CONTRACTS.md` §4, `apps/mobile/lib/core/repositories/supabase_capture_service.dart`).
  El servidor no tiene forma de saber dónde estaba el jugador.
- **La captura no depende del GPS.** Lo que autoriza un encuentro es la lectura NFC del
  tag físico, no una comprobación de proximidad por coordenadas, así que el backend no
  necesita la ubicación ni siquiera de forma transitoria.
- **PostGIS está instalado pero no se usa para almacenar nada.** La extensión se habilita
  en `supabase/migrations/20260916000100_extensions.sql` pensando en funciones geográficas
  futuras; hoy no hay ninguna columna geográfica que pudiera alimentar.
- **En modo demo no se toca el GPS real:** `MockLocationService` recorre una ruta simulada
  (`DEMO_MODE=true`, ver `docs/architecture.md`).

Textos de permiso que ve el usuario:

- iOS (`apps/mobile/ios/Runner/Info.plist`), `NSLocationWhenInUseUsageDescription`:
  «Profesor GO usa tu ubicación para mostrarte en el mapa del campus. No se guarda ningún
  historial.» Es *when in use*: no hay permiso de ubicación en segundo plano.
- Android (`apps/mobile/android/app/src/main/AndroidManifest.xml`):
  `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION`. No se declara
  `ACCESS_BACKGROUND_LOCATION`.

## 2. Posiciones de los profesores

**No se almacena ni se expone la ubicación física de ningún profesor.** La tabla
`public.professors` guarda solo `name`, `display_name`, `description`, `rarity`,
`sprite_url`, `active` y `base_capture_rate`: no hay coordenadas ni referencia a un aula,
stand o edificio. Lo único que relaciona a un profesor con un punto del campus es la
tarjeta NFC pegada allí, y esa relación vive en `public.nfc_tags` (`tag_identifier` →
`professor_id`), que **los jugadores no pueden leer**: `nfc_tags` tiene RLS activada y una
única política, solo para administradores (`supabase/migrations/20260916000500_rls.sql`).
Un jugador autenticado que consulte la tabla recibe cero filas.

Consecuencia práctica: la app no puede pintar «dónde está cada profesor» ni un jugador
puede deducirlo consultando la API. Hay que recorrer el campus y encontrar el tag.

## 3. Biometría, cámara y fotos

**No se usa biometría, ni cámara, ni fotos, ni grabación de audio.** No hay ninguna dependencia de
cámara, galería o autenticación biométrica en `apps/mobile/pubspec.yaml` (ni
`camera`, ni `image_picker`, ni `local_auth`), y no se declara ningún permiso de ese tipo.
El conjunto completo de permisos de la app es:

- Android: `INTERNET`, `NFC`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- iOS: `NFCReaderUsageDescription` y `NSLocationWhenInUseUsageDescription`.

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

No se recoge teléfono, fecha de nacimiento, dirección, identificador de dispositivo ni
publicitario. **No hay SDK de analítica, telemetría ni crash reporting** en la app móvil ni
en el panel admin (ni Firebase, ni Sentry, ni Crashlytics, ni equivalentes en
`apps/mobile/pubspec.yaml` ni en `apps/admin/package.json`).

## 5. Qué queda en el dispositivo

- La sesión de Supabase Auth (tokens + PKCE) en `SharedPreferences`, escrita por
  `Supabase.initialize` (`apps/mobile/lib/main.dart`). Se borra al cerrar sesión.
- Una caché de juego: profesores, capturas y progreso
  (`apps/mobile/lib/core/repositories/professor_repository.dart`) y, en modo demo, el
  estado simulado (`apps/mobile/lib/core/mock/demo_game_state.dart`).

Ninguna de esas claves contiene coordenadas.

## 6. Quién puede ver qué

Lo impone la RLS, no la interfaz (resumen completo en `docs/database.md`):

- Un jugador solo lee **su** fila de `profiles`, **sus** encuentros y **sus** capturas, y
  los profesores activos. No puede leer las filas de otros jugadores ni `nfc_tags`.
- Un jugador no puede escribir en `captures` ni en `encounters`: solo escribe
  `service_role` desde las Edge Functions.
- Un administrador puede leer `profiles` (incluido el email) por RLS, pero **el panel no
  muestra ninguna lista de jugadores**: el dashboard solo consulta `admin_stats()`, que
  devuelve agregados (`total_players`, `total_captures`, `active_professors`,
  `completed_collections`) y ninguna fila individual
  (`apps/admin/src/app/(app)/dashboard/page.tsx`).
- Los usuarios anónimos no leen nada: todas las políticas son `to authenticated`.

## 7. Registros del servidor

Las Edge Functions escriben un log JSON por línea (`supabase/functions/_shared/log.ts`)
con identificadores (`user_id`, `encounter_id`, `professor_id`, `tag_id`), el evento y el
resultado. `redact()` elimina cualquier campo cuyo nombre parezca un secreto
(`authorization`, `token`, `jwt`, `password`, `api_key`, `service_role`…) y cualquier valor
con forma de JWT. **No se registran emails ni coordenadas.**

## 8. Borrado de datos

Borrar el usuario en `auth.users` elimina en cascada su fila de `profiles` y, desde ahí,
sus `encounters` y `captures` (`on delete cascade` en
`supabase/migrations/20260916000200_schema.sql`). No queda ningún dato del jugador salvo
las líneas de log del servidor, que contienen solo su UUID.

## 9. Si esto cambia

Cualquier cambio que añada coordenadas, biometría, fotos o un SDK de analítica invalida
este documento: hay que actualizarlo en el mismo cambio y revisar `docs/CONTRACTS.md` §2,
porque implicaría tocar el esquema.
