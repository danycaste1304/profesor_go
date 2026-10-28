# Profesor GO: estado del piloto Android + Safari

Actualizado el 27 de octubre de 2026. Este documento registra la implementación;
el corte de salida sigue dependiendo de la prueba física del 28.

## Preparado en código y backend

- Migración `20261027035710_cross_platform_qr.sql` aplicada al proyecto Supabase
  `zwvnyejxettnjbuallgm`. Crea una credencial aleatoria por profesor, almacena
  solo SHA-256, permite rotación/desactivación por admin y acepta NFC o QR en el
  inicio de encuentro transaccional. Los hallazgos QR y NFC comparten la regla
  de un registro por estudiante y búsqueda. Ambas entradas tienen límites de
  intentos por cuenta.
- `start-encounter` desplegado con el RPC transaccional; `resolve-capture`
  conserva el contrato existente.
- Panel `/qr` para crear, imprimir, reemplazar y desactivar códigos. Un código
  solo se muestra al crearlo; si se pierde el papel, hay que reemplazarlo.
  `NEXT_PUBLIC_GAME_URL` debe apuntar a la app HTTPS operativa antes de crear
  el primero.
- Flutter Android y web comparten OAuth, mapa, colección, QR y minijuego.
  Android conserva NFC. En Safari se puede escanear dentro del juego o abrir
  la URL impresa con la cámara del sistema; el QR pendiente sobrevive al
  retorno Google OAuth y se quita de la URL visible. El código va en el
  fragmento `#qr=...`, que no se envía al servidor web en la solicitud inicial.
- El mapa geográfico usa el último GPS del estudiante y su círculo de
  precisión; el GPS se puede denegar sin perder el flujo QR. La posición del
  estudiante no se persiste. Los marcadores de profesores se muestran solo
  para sesiones voluntarias activas con posición de menos de 30 segundos.
- La caché de capturas y progreso se separa por cuenta y se borra al salir.
- Política de privacidad técnica y página pública actualizadas para cámara y QR.
- GitHub Pages sirve el juego completo en
  `https://danycaste1304.github.io/profesor_go/jugar/`. El flujo manual
  «Safari pilot candidate» completó con éxito. Google OAuth devolvió la sesión
  a la web y cargó el mapa. La prueba real descubrió que un QR recibido por una
  pestaña ya abierta iba a «Page Not Found»; la ruta `/qr=:code` corrige este
  caso y necesita repetirse en la próxima publicación.
- Los diez profesores tienen QR únicos activos en Supabase. La hoja de cinco
  páginas y el JSON de recuperación están en `pilot-private/` del equipo local,
  ignorados por Git. Guardar una copia segura antes de imprimir; rotar en el
  panel cualquier código que se pierda o se comparta fuera del evento.

## Compilaciones verificadas

- Flutter: análisis limpio; 316 pruebas superadas y 15 omitidas, incluidas
  las pruebas nuevas de QR y aislamiento de caché.
- Endpoint: 28 pruebas superadas. Panel: 44 pruebas, lint, tipos y build.
- Web real: `flutter build web --release --base-href /profesor_go/jugar/
  --dart-define-from-file=.env` completado. La apertura de una URL QR de
  prueba con `#qr=...` mostró la pantalla de acceso, eliminó el código de la
  URL visible y no produjo errores de consola. El registro HTTP local recibió
  solo `/profesor_go/jugar/`, sin la credencial; falta probar OAuth real.
- APK candidato `0.1.0+10`: compilado con firma local de piloto; `apksigner`
  confirmó la firma y que corresponde al archivo de clave local.
- AAB candidato: `flutter build appbundle --release` completado después de
  instalar las Android SDK Command-line Tools oficiales. El archivo firmado
  está en `apps/mobile/build/app/outputs/bundle/release/app-release.aab`.

## Configuración HTTPS completada

- Pages usa GitHub Actions; la variable `SUPABASE_URL` y el secreto publicable
  `SUPABASE_ANON_KEY` están configurados. El flujo conserva la portada y las
  páginas estáticas dentro de `/profesor_go/`.
- Supabase Auth permite exactamente la URL web como retorno OAuth. El proveedor
  Google está habilitado y una sesión existente completó el retorno web.
- El panel local tiene `NEXT_PUBLIC_GAME_URL` y generó los diez QR. El panel
  sigue funcionando en local; falta decidir y configurar su alojamiento HTTPS
  para que el equipo pueda administrar fuera de este computador.

## Pendientes antes de distribuir

1. Publicar y verificar la corrección del QR en pestaña existente, incluidas
   las rutas con sesión y después de Google OAuth sin sesión.
2. Imprimir la hoja y probar los diez códigos físicamente. Confirmar QR
   desactivado y reemplazado con cuentas de ensayo.
3. Vincular la cuenta Google de cada profesor participante en
   `hunt_publishers`. Solo existen una cuenta admin y una de estudiante; los
   profesores deben iniciar sesión al menos una vez. Sin esos vínculos, no
   habrá marcadores compartidos aunque el QR funcione.
4. Completar el alta de Google Play Console para `danycaste1304@gmail.com`.
   La consola muestra el formulario de creación de cuenta de desarrollador;
   todavía no puede subirse el AAB a Play.

## Ensayo y corte de distribución

- En iPhone Safari y dos Android con datos móviles: cuenta Google nueva,
  sesión persistente, QR abierto antes del login, cámara interna, mapa en
  exterior/interior, GPS denegado, captura, colección compartida y cambio de
  cuenta en un mismo teléfono.
- Profesor: comprobar que no aparece marcador antes de «Iniciar», que solo
  su cuenta publica, que «Detener» lo oculta y que una posición de más de
  30 segundos desaparece. Verificar el hallazgo de alguien que ya capturó
  a ese profesor y la exportación administrativa.
- Instalar el APK en un Android limpio y probar una actualización firmada con
  la **misma** clave. La clave local está en
  `apps/mobile/android/profesor-go-pilot.jks` y sus contraseñas en
  `apps/mobile/android/key.properties`; ambos están excluidos de Git.
  Guardar ambos en el gestor seguro del equipo antes de distribuir cualquier
  APK. Si se pierden, una actualización directa no se podrá firmar igual.
- No publicar el enlace web como juego disponible ni repartir el APK/AAB hasta
  superar la prueba física. Google Play depende de la cuenta, sus requisitos
  de prueba y su revisión; si no llega a tiempo, publicar solo el APK firmado
  mediante un enlace HTTPS controlado tras el ensayo.

## Crecimiento posterior

Medir concurrencia, latencia y errores de la consulta de búsquedas cada
10 segundos antes de ajustarla. Paginar el panel y hacer streaming de
exportaciones grandes cuando el volumen lo justifique. Migrar mosaicos de
OpenStreetMap a un proveedor con capacidad comercial antes de escalar el
tráfico. Añadir entidades `campus` y `evento` cuando haya una segunda feria,
y evaluar QR rotativo o aprobación del profesor si el hallazgo se usará como
prueba fuerte de presencia.
