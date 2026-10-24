# Cambios de UI (sesión de rediseño pixel art)

Resumen corto de lo que cambió en `apps/mobile`. Todos los tests pasan (277) y `flutter analyze` está limpio.

## Mapa
- Lienzo de **720×1290** (9:16), igual que `assets/map/campus_map.png`. Antes era 900×1200 y la imagen se veía aplastada. Está en `CampusConfig.mapWidth/mapHeight`.
- La cámara sigue al avatar sobre el mapa completo; al mover o ampliar el mapa con los dedos se pausa el seguimiento y aparece un botón para recentrar. La ilustración de los Cuadrángulos se conserva y los marcadores de la carpa y la dirección del laboratorio se dibujan encima.
- Las coordenadas GPS aún son de ejemplo. La cámara ya funciona, pero la proyección real de la USFQ requiere medir el área y validar el mapa en sitio.
- Ruta del avatar en modo demo (`CampusConfig.demoPath`) rehecha sobre los caminos del arte nuevo.

## Estilo pixel art (bloques de 4 px, misma paleta `AppColors`)
Todo se dibuja con `CustomPainter`, sin assets.

| Componente | Archivo | Notas |
|---|---|---|
| `PixelFramePainter` | `core/widgets/pixel_frame_painter.dart` | Marco con esquinas escalonadas. Con losa y bisel (botones) o `.flat` (contenedores). |
| `PixelButton` | `pixel_button.dart` | Misma API. Se hunde al pulsar. |
| `PixelCard` | `pixel_card.dart` | Sin sombra. Se eliminó el parámetro `shadow`. |
| `PixelIconButton` + `PixelCirclePainter` | `pixel_icon_button.dart` | **Nuevo.** Botón circular sin texto (se usa para la música). |
| `ProgressBar` + `PixelBarPainter` | `progress_bar.dart` | Relleno por bloques. Muestra solo el porcentaje; `showCount` y `showPercent` son opcionales. |
| `RarityBadge` | `rarity_badge.dart` | Un solo componente para tarjetas (`compact`) y detalle. Bloques de 2–3 px. |
| `RarityFilterChip` | `collection_widgets.dart` | Carrusel de la Profedex; el filtro activo se ve hundido. |

## Fuentes y texto
- Fuentes en `assets/fonts/` (VT323 y Silkscreen, ambas SIL OFL; licencias incluidas) y registradas en `pubspec.yaml`.
- Se referencian solo desde el tema: `AppTheme.displayFontFamily` (h1 y botones) y `AppTheme.bodyFontFamily` (resto). No escribir nombres de fuente sueltos.
- `letterSpacing` en **0** para todo el texto (`AppTheme._flat`).
- Para cambiar tamaños: `theme.dart` (`_display(...)`, `bodyLarge/Medium`, `titleMedium`, `appBarTheme`).
- "Colección" pasó a **"Profedex"** en todos los textos visibles.
- Título del detalle de profesor: siempre "Profesor".
- La frase bajo el logo (`PixelLogo.tagline`) usa el estilo `bodyMedium` atenuado.

## Navegación
- `AppScaffold` tiene `homeFallback`: si la pantalla se abrió con `context.go` (sin pantalla anterior), el AppBar muestra una flecha que vuelve al mapa. Activo en Profedex, Perfil, Leer tarjeta, detalle y Logro.

## Otros
- El encuentro usa `FittedBox` en la insignia de rareza para que no se desborde junto al contador.
- Tests nuevos: `pixel_icon_button_test`, `progress_bar_test`, `app_scaffold_test`. Se actualizaron los textos esperados en los tests del mapa, la Profedex, el perfil, el logro y el flujo demo.
