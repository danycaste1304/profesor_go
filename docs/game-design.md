# Diseño del juego

## Objetivo

Encontrar físicamente a todos los profesores participantes en la feria y "capturarlos"
en la app. Cada profesor se captura **una sola vez por usuario**.

## Bucle principal

1. El jugador camina por el campus; su avatar pixelado se mueve sobre un mapa de mosaicos original.
2. Encuentra a un profesor y pulsa **CAPTURAR**.
3. Acerca el teléfono a la tarjeta NFC del profesor.
4. El servidor valida el tag y crea un **encuentro** (expira en 3 minutos).
5. Aparece el profesor como sprite; el jugador **desliza hacia arriba y suelta** la bola.
6. La app clasifica el lanzamiento (`MISS/GOOD/GREAT/EXCELLENT`) y lo envía.
7. El servidor tira el dado: éxito → colección; fallo → hay que volver a leer el NFC.

La dirección visual combina exploración geolocalizada con la presentación de un
RPG portátil: mapa pixelado, retratos y plataformas de combate, marcos cuadrados
y diálogo que se revela letra a letra. Tres piezas chiptune originales acompañan
mapa, encuentro y victoria solo cuando el jugador activa la música desde el mapa.

## Rareza

| Rareza    | Etiqueta  | Tasa base | Idea de uso                          |
|-----------|-----------|-----------|--------------------------------------|
| COMMON    | Común     | 0.80      | Profesores con stand fijo            |
| RARE      | Rara      | 0.60      | Profesores que circulan              |
| EPIC      | Épica     | 0.40      | Presentes solo en ciertas franjas     |
| LEGENDARY | Legendaria| 0.25      | Decano/invitado especial              |

La rareza siempre se muestra con texto e icono, no solo con color.

## Minijuego de lanzamiento

- Bola abajo, profesor arriba, un gesto desde la zona de lanzamiento cercana a
  la bola. Un deslizamiento corto hacia arriba basta para lanzarla; el dedo no
  tiene que llegar al sprite. El movimiento horizontal permite ajustar la mira.
- Se calculan `velocity`, `direction`, `distance` y `accuracy` (distancia al centro del
  objetivo en el punto donde cruza la trayectoria proyectada).
- Clasificación por distancia al centro (px lógicos, normalizados por el tamaño de pantalla):

```text
<= 20 px → EXCELLENT   (+0.20)
<= 50 px → GREAT       (+0.10)
<= 90 px → GOOD        (+0.00)
>  90 px → MISS        (falla siempre)
```

- Gestos muy cortos (< 40 px), horizontales o hacia abajo cuentan como `MISS`.
- Mientras se arrastra, una guía pixelada proyecta el punto de impacto y
  cambia de color según la calidad prevista. Un rótulo animado indica si falta
  deslizar o si el objetivo está bien alineado. Al soltar, desaparece y empieza
  el lanzamiento. El interruptor de música controla también los efectos
  originales de lanzamiento, impacto, sacudidas, captura y escape.
- La animación (bola viaja → impacto → profesor entra → bola cae → 1-3 sacudidas) corre en
  paralelo con la petición al servidor; el resultado real se muestra cuando ambos terminan.
- El marco superior muestra el tiempo restante como una barra de RPG y el
  objetivo se marca con esquinas pixeladas; no se representa una vida del profesor.

## Reglas de UX

- Encuentro expira a los 180 s (configurable en `app_settings`).
- Tras un fallo el encuentro queda `FAILED`; para reintentar hay que leer el NFC otra vez.
- Un profesor capturado no puede volver a capturarse (`ALREADY_CAPTURED`).
- Profesores inactivos no aparecen ni cuentan para completar la colección.
- Al completar la colección aparece `CompletionScreen` con la fecha registrada y la
  medalla digital «Maestro del campus». La pantalla comprueba el progreso antes de
  mostrar el logro; no promete un QR ni una recompensa física.

## Anti-trampas (mínimo del MVP)

Nada que afecte al progreso lo decide el cliente: la app pide y muestra, el servidor
resuelve. Lo que está realmente implementado:

- **Sin NFC no hay encuentro.** `start-encounter` exige `tag_identifier`, lo busca en
  `nfc_tags` y rechaza los desconocidos (`TAG_NOT_FOUND`), los desactivados (`TAG_DISABLED`)
  y los de profesores inactivos (`PROFESSOR_DISABLED`)
  (`supabase/functions/start-encounter/handler.ts`).
- **El encuentro lo crea y lo posee el servidor.** El `user_id` sale del JWT verificado
  (`auth.getUser`, `_shared/auth.ts`), nunca del cuerpo de la petición; el cliente solo
  recibe un `encounter_id` ya creado.
- **Caduca a los 180 s** (`app_settings.encounter_expiration_seconds`, `_shared/settings.ts`).
  Resolver fuera de plazo devuelve `ENCOUNTER_EXPIRED` y marca el encuentro `EXPIRED`; al
  abrir uno nuevo, los `ACTIVE` anteriores del mismo usuario+profesor pasan a `EXPIRED`.
- **La probabilidad se calcula en SQL** y nunca viaja por la red:
  `p = clamp(base_capture_rate + throw_bonus[quality], 0, 1)`, leyendo
  `professors.base_capture_rate` y `app_settings.throw_bonus` dentro de la misma transacción
  (`resolve_capture_tx`, migración `20260917000100_harden_resolve_capture_search_path.sql`).
- **La tirada la genera el servidor** con `crypto.getRandomValues` (`_shared/random.ts` →
  `resolve-capture/handler.ts`), no el móvil.
- **Un profesor, una captura:** `unique (user_id, professor_id)` en `captures`
  (`20260916000200_schema.sql`), más la comprobación explícita de captura previa en
  `start-encounter` y dentro de la RPC (`ALREADY_CAPTURED`).
- **El cliente no puede escribir progreso.** `captures` y `encounters` solo tienen políticas
  RLS de `select` sobre las filas propias; insertar, actualizar o borrar queda para
  `service_role` desde las Edge Functions. `nfc_tags` no tiene ninguna política para
  jugadores, así que la lista de tags no se puede enumerar (`20260916000500_rls.sql`).
- **Resolución idempotente y sin carreras:** `resolve_capture_tx` hace `select … for update`
  sobre el encuentro y resuelve todo en la misma transacción; reenviar la misma petición
  devuelve el resultado ya guardado (`ALREADY_RESOLVED`) en lugar de tirar el dado otra vez.
- **La RPC no es pública:** `revoke execute … from public, anon, authenticated` y
  `grant … to service_role` (`20260916000400_functions.sql`).

### La frontera de confianza (lo que el servidor no puede comprobar)

`throw_quality` lo clasifica el móvil y lo envía tal cual. **Un cliente modificado siempre
puede declarar `EXCELLENT`**, y eso no se puede detectar desde el servidor con los datos que
recibe. No se disimula: se acota.

- El techo es la tasa base del profesor **+ 0.20** (el bonus de `EXCELLENT`). Un LEGENDARY
  sube de 0.25 a 0.45: sigue fallando más de la mitad de las veces.
- Sigue siendo **una captura por profesor**, así que la ventaja máxima es capturar antes, no
  capturar más ni completar la colección de otra forma.
- Y sigue haciendo falta **leer la tarjeta**: sin un `tag_identifier` válido no existe
  encuentro que resolver.

Hacerlo a prueba de clientes exigiría puntuar el lanzamiento en el servidor (enviar la traza
del swipe y reclasificarla) o quitar el minijuego; ninguna de las dos está en el MVP.

La otra frontera conocida es que el `tag_identifier` es **estático**: quien lo conozca puede
iniciar un encuentro sin estar delante del profesor. Está analizada, con sus caminos de
migración (tokens rotativos, NTAG 424 DNA/SUN), en
[`docs/nfc.md`](nfc.md#limitación-de-seguridad-mvp).

## Accesibilidad

Cada punto está comprobado contra `apps/mobile/lib/core/widgets/` y `lib/app/theme.dart`.

- **La rareza nunca va solo en el color.** `RarityBadge` pinta icono + etiqueta en español
  (`Común`, `Rara`, `Épica`, `Legendaria`) junto al color, y se envuelve en
  `Semantics(label: 'Rareza: …')`. Los iconos son distintos entre sí y estables
  (`AppTheme.rarityIcon`: círculo, estrella hueca, estrella sólida, destello) y se reutilizan
  en los filtros de la colección. Un profesor sin capturar se reconoce por la silueta y por
  el texto `???`, no por el color.
- **Objetivos táctiles.** `PixelButton` —todas las acciones principales— usa
  `minHeight = AppTheme.minButtonHeight = 56` y `minWidth = 48`; los secundarios que se
  encogen lo hacen a `minHeight: 48`. El tema fija `TextButton` en 48×48 y los `IconButton`
  de contraseña y de los avisos llevan `BoxConstraints(minWidth: 48, minHeight: 48)`.
  Los filtros de rareza de la colección también miden 48×48 y su fila desplaza en horizontal
  en pantallas estrechas en lugar de encoger los objetivos.
- **Contraste** (ratios WCAG calculados sobre los colores de `AppColors`): texto principal
  17.6:1 sobre el fondo y 13.5:1 sobre `surfaceAlt`; texto atenuado (`textMuted`) 6.9:1 en su
  peor fondo; `accent` 13.2:1 y `accentAlt` 13.7:1 sobre el fondo (11.8:1 y 12.3:1 sobre
  `surface`); `danger` 5.2:1 sobre `surface`; la etiqueta del botón primario (`onAccent`
  sobre `accent`) 13.2:1. En las chapas de rareza el texto va sobre su propio color al 18 %
  encima de `surface`: de 4.6:1 (épica) a 6.5:1 (legendaria). Todos los pares cumplen AA para
  texto normal (≥ 4.5:1), varios sin llegar a AAA.
- **Háptica.** Hay un único punto de vibración en toda la app: `PixelButton._handleTap`
  dispara `HapticFeedback.lightImpact()` al pulsar. No hay vibraciones largas ni patrones, y
  **no existe un interruptor dentro de la app**: depende de los ajustes de vibración del
  sistema. Si en el futuro se quiere hacer opcional, ese método es el único sitio que tocar.
- **Tamaños de letra.** Tema base: cuerpo 17 (`bodyLarge`) y 15 (`bodyMedium`) con
  `height: 1.35`, etiquetas de botón 16, título de AppBar 20. Los textos más pequeños son de
  12 (chapa de rareza compacta y chips de filtro) y siempre van acompañados de icono. La app
  **no sobreescribe `textScaler` / `textScaleFactor` en ningún sitio**, así que respeta el
  tamaño de fuente del sistema; el hub del mapa se vuelve desplazable cuando el alto
  disponible baja de 560 dp, en lugar de comprimir el contenido.
- **Lectores de pantalla.** Los elementos con significado no textual llevan `Semantics`
  explícito: `ProgressBar` anuncia «Progreso: X de Y» con un `value` en porcentaje,
  `ProfessorSprite` y `CaptureBall` se marcan como imagen con etiqueta, y los estados que
  cambian solos son `liveRegion` (indicador de conexión del mapa, cuenta atrás del encuentro
  y banda de «Mostrando datos guardados»).

## Fuera del MVP

PvP, intercambio, chat, amigos, equipos, tienda, pagos, inventario, ranking, misiones,
raids, IA, reconocimiento facial.
