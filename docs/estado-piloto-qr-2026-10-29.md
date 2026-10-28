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

## Pasos para habilitar la prueba HTTPS

1. En el repositorio GitHub, configurar Pages con origen **GitHub Actions**.
   Crear la variable `SUPABASE_URL` y el secreto `SUPABASE_ANON_KEY` de la
   instancia Profesor GO. El flujo manual `.github/workflows/web-pages.yml`
   monta la web en `/profesor_go/jugar/` y conserva portada, privacidad y
   página de anfitrión. No ejecutarlo como anuncio público; la portada actual
   seguirá apuntando a la beta anterior hasta el corte de salida.
2. Autorizar exactamente
   `https://danycaste1304.github.io/profesor_go/jugar/` como retorno OAuth
   en Supabase Auth. Confirmar el origen permitido por Google OAuth.
3. Configurar `NEXT_PUBLIC_GAME_URL` en el panel admin con esa URL HTTPS,
   desplegar el panel y crear/imprimir los diez QR. Confirmar que un QR
   desactivado falla y que el código antiguo no funciona tras reemplazarlo.
4. Vincular la cuenta Google del profesor participante en `hunt_publishers`.
   La base remota aún no tenía ningún vínculo ni sesión de búsqueda al
   verificarla; el profesor debe iniciar sesión al menos una vez.

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
