# Paso de demo a operación real

Estado: 26 de octubre de 2026. Este documento es la secuencia de salida para
la feria; ningún emulador sustituye la última prueba con los dispositivos.

## Candidato beta 9: búsqueda por todo el campus

El código local de `0.1.0+9` incorpora mapa geográfico, publicación voluntaria
de la última posición durante 30 minutos, hallazgo NFC independiente de la
Profedex y lista/exportación de participantes en `/hunt`. La migración
`20261026021215_campus_hunt.sql` se aplicó al Supabase de producción el
25 de octubre (hora de Ecuador); creó las tablas con RLS y programó la limpieza
de ubicaciones. La APK beta 9 ya puede llamar a `check_in_campus_hunt`, pero
todavía requiere la prueba física antes de distribuirse.

Verificación en producción: las tres tablas tienen RLS, los RPC públicos están
disponibles solo para cuentas autenticadas y `pg_cron` ejecutó la limpieza con
estado `succeeded`. Una prueba dentro de una transacción revertida confirmó
sesión de 30 minutos, ubicación visible para un alumno mientras estaba activa,
un solo hallazgo al tocar dos veces la tarjeta de un profesor ya capturado,
ocultación al detener y borrado del último punto. Tras el rollback quedaron
cero usuarios, sesiones y hallazgos de prueba; las diez capturas previas siguen
presentes. Otra transacción revertida confirmó que la cuenta administradora
puede crear una asignación mediante RLS. La prueba pgTAP completa sigue
pendiente por falta de Docker local.

Secuencia para habilitarla:

1. Ejecutar `supabase/tests/007_campus_hunt.test.sql` en un entorno de prueba
   cuando Docker esté disponible; las comprobaciones de producción anteriores
   ya pasaron.
2. Probar un Gmail nuevo en dos Android con la APK beta 9, cerrar/reabrir la app
   y confirmar que la sesión persiste. No hay un fallo de login reproducido aún.
3. Hacer que el profesor entre en la app con Google, vincular su correo desde
   `/hunt`, registrar su tarjeta NFC pequeña y comprobar la lectura física.
4. Recorrer todo el campus con dos estudiantes: marcador y precisión GPS,
   desaparición a los 30 segundos sin señal, hallazgo de quien ya capturó al
   profesor, fin manual y automático, y exportación CSV.
5. Distribuir la APK solo después de completar esas pruebas. La compilación
   local usa la firma debug mientras no exista `android/key.properties`.

Si Noel usa iPhone, la página de anfitrión está en `docs/anfitrion.html`. Para
habilitarla: publicar `docs/` por HTTPS en GitHub Pages, añadir exactamente
`https://danycaste1304.github.io/profesor_go/anfitrion.html` a las Redirect URLs
de Supabase Auth sin quitar los retornos existentes, y probar Google OAuth y
GPS en Safari. La página usa una clave pública, verifica por RLS la cuenta
vinculada y deja de publicar al bloquearse Safari; el marcador caduca a los
30 segundos. Noel debe iniciar sesión una vez antes de vincular su cuenta.

## Estado de la beta 8

La APK real v0.1.0+8 integra el mapa y la transición de encuentro nuevos,
NFC, Google y Supabase. Su botón **Perfil → Reiniciar mi Profedex** aparece
solo para la cuenta organizadora y el servidor verifica su identificador y
rol antes de borrar únicamente sus capturas y encuentros. La migración se
probó en producción dentro de una transacción revertida; la colección real
del organizador quedó intacta.
Las diez fichas usan el tono indicado por el equipo organizador; Daniel figura
como coordinador de MAC y CMP y Felipe como responsable de las maestrías. El
beacon 08 de Pavel acepta también el UID leído por el A52; la prueba física
abrió correctamente su encuentro. El valor del UID se mantiene solo en el
backend privado.

La beta distribuida por enlace usa únicamente música original y está firmada
con la clave debug local. Sirve para probar mediante instalación directa; para
distribuirla en una tienda se necesita una clave de firma de producción.
La descarga pública de la beta 8 está en
`https://github.com/danycaste1304/profesor_go/releases/download/v0.1.0-beta.8/profesor-go-beta8.apk`.

Google Auth Platform está **En producción** para usuarios externos: cualquier
cuenta de Google puede iniciar sesión sin estar en la lista de prueba. La
[página del juego](https://danycaste1304.github.io/profesor_go/) y la
[política de privacidad](https://danycaste1304.github.io/profesor_go/privacidad.html)
se publicaron en GitHub Pages y se registraron en la información de marca de
Google. Falta una prueba de inicio de sesión con un Gmail que nunca haya estado
en la lista de prueba. También siguen pendientes la calibración GPS en campus,
la prueba física completa de los diez NFC en la APK nueva y el panel admin por
HTTPS.

## 1. Infraestructura y cuentas

1. Usar el proyecto Supabase de producción `zwvnyejxettnjbuallgm` con **Data API** activa,
   **Automatically expose new tables** desactivado y **Enable automatic RLS**
   activado. La migración final otorga los permisos necesarios por tabla.
   Guardar su **Project URL** y
   **publishable/anon key** en `apps/mobile/.env` (`DEMO_MODE=false`) y en el
   entorno del panel admin. La `service_role` nunca va en ninguna app cliente.
2. Las 22 migraciones ya se aplicaron con `supabase db push` y las tres Edge
   Functions de `docs/setup.md` están desplegadas. La migración final carga los ajustes de juego
   y elimina `DEMO-TAG-01…10`; **no ejecutar `supabase/seed.sql` en producción**.
3. Configurar «Continuar con Google» en el proyecto Google Cloud
   `profesor-go-usfq`. En el cliente OAuth web, autorizar exactamente
   `https://zwvnyejxettnjbuallgm.supabase.co/auth/v1/callback`; guardar el
   ID y secreto del cliente en el proveedor Google de Supabase, sin poner el
   secreto en el repositorio. Autorizar en Supabase los retornos
   `profesorgo://login-callback` y la URL HTTPS de `/auth/callback` del panel.
   El retorno `http://localhost:3000/auth/callback` sirve solo para la prueba
   local. Probar el acceso con una cuenta Gmail real y comprobar la sesión.
4. Entrar con Google usando `danycaste1304@gmail.com`, comprobar que la cuenta
   existe en `auth.users` y `public.profiles` y establecer `role='admin'` solo
   para ese ID de usuario desde el SQL Editor. Probar acceso al panel y
   registro de un tag.
5. Publicar el panel admin con URL HTTPS y sus variables públicas de Supabase.
   Confirmar que solo la cuenta administradora puede ver y modificar tags.
   El acceso público con Google no necesita SMTP. Si se habilita después el
   registro por correo y contraseña, configurar SMTP propio antes de abrirlo
   a los asistentes.

## 2. NFC físico

1. Instalar una build real en el Android con NFC y tocar los beacons
   Estimote. Hay al menos doce (cuatro kits o más). Anotar para cada uno el
   identificador que muestra la app con la cuenta admin tras `TAG_NOT_FOUND`
   (ver `docs/nfc.md`).
2. Registrar diez identificadores en el panel y asociar uno a cada profesor;
   reservar al menos dos beacons para reemplazos. Confirmar que cada ID sea
   distinto antes de terminar la asignación.
3. Con una cuenta de jugador distinta, probar lectura, encuentro, captura,
   persistencia al cerrar/abrir la app y rechazo de un tag no registrado.
4. Probar con la pantalla encendida, NFC activo, el profesor portando su beacon
   y el teléfono que usarán los participantes. Verificar batería de cada beacon.

## 3. Lugar y distribución

1. La feria será en el campus Santiago Gangotena de la Universidad San Francisco
   de Quito, en Diego de Robles. La carpa del Politécnico y los puestos MAC y
   Computación estarán en los Cuadrángulos, frente al edificio Espejo (n.º 20
   en el mapa de la USFQ). Algunos profesores también estarán en un laboratorio
   hacia la derecha de esta zona. Todos portarán sus beacons: los NFC no son
   puntos fijos del mapa. El modo real ya usa los pines aproximados enviados
   por el organizador para la carpa (`-0.1968714, -78.4364417`) y la entrada
   del laboratorio (`-0.1968818, -78.4352857`). La ilustración tiene
   perspectiva, así que el avatar muestra el avance aproximado por el trayecto
   carpa → laboratorio y dice «Ubicación aproximada». `CampusConfig.bounds`
   conserva las coordenadas de Madrid solo para el modo demo. Antes de la
   feria, medir ambos puntos caminando en sitio y comprobar el recorrido y el
   margen de GPS con varios teléfonos; los pines se marcaron de forma remota.
   La entrada del laboratorio es la esquina marcada con un círculo rojo en el
   plano proporcionado por el organizador. Referencia: [mapa oficial de la
   USFQ](https://www.usfq.edu.ec/sites/default/files/2023-10/mapa-usfq-2023.pdf).
2. Para la primera prueba, crear `apps/mobile/.env` con `DEMO_MODE=false`, URL
   HTTPS y clave pública de Supabase; ejecutar `./scripts/build-real-android.sh`.
   El script rechaza una configuración demo o incompleta. Para distribución
   definitiva, generar y conservar una clave de firma Android de producción y
   completar `apps/mobile/android/key.properties`.
   Si se distribuirá en iPhone, hace falta la cuenta Apple Developer y la
   capacidad NFC habilitada en el App ID.
3. Decidir el canal de distribución y probar instalación limpia en un teléfono
   que no tenga la demo. El modo real jamás debe mostrar «MODO DEMO» ni el
   selector `DEMO-TAG-*`.

## Criterio de salida

La versión está lista para la feria cuando diez tags físicos distintos inician
encuentros de sus diez profesores en teléfonos reales, las capturas sobreviven
al reinicio, el panel permite desactivar un tag y el mapa muestra la ubicación
en el trayecto correcto, con la etiqueta de aproximación. Repetir el flujo con
una cuenta Gmail nueva y con red móvil, no solo con Wi-Fi de desarrollo.

Los identificadores NFC son estáticos. Para una operación pública prolongada o
recompensas valiosas hay que reforzar la protección contra copias y limitar
intentos en `start-encounter` (ver `docs/nfc.md`).
