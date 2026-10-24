# Paso de demo a operación real

Estado: 23 de octubre de 2026. Este documento es la secuencia de salida para
la feria; ningún emulador sustituye la última prueba con los dispositivos.

## 1. Infraestructura y cuentas

1. Usar el proyecto Supabase de producción `zwvnyejxettnjbuallgm` con **Data API** activa,
   **Automatically expose new tables** desactivado y **Enable automatic RLS**
   activado. La migración final otorga los permisos necesarios por tabla.
   Guardar su **Project URL** y
   **publishable/anon key** en `apps/mobile/.env` (`DEMO_MODE=false`) y en el
   entorno del panel admin. La `service_role` nunca va en ninguna app cliente.
2. Las 19 migraciones ya se aplicaron con `supabase db push` y las tres Edge
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
   puntos fijos del mapa. Sustituir `CampusConfig.bounds` (actualmente
   coordenadas de ejemplo en Madrid) por límites GPS medidos y validar la
   proyección de los Cuadrángulos antes de mostrar posición real del jugador.
   La entrada del laboratorio es la esquina marcada con un círculo rojo en el
   plano proporcionado por el organizador. El mapa ilustrado solo muestra la
   dirección hacia esa entrada; faltan sus coordenadas GPS y las de la carpa
   para calibrar la ubicación real del jugador. Referencia: [mapa oficial de
   la USFQ](https://www.usfq.edu.ec/sites/default/files/2023-10/mapa-usfq-2023.pdf).
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
en el recinto correcto. Repetir el flujo con una cuenta Gmail nueva,
y con red móvil, no solo con Wi-Fi de desarrollo.

Los identificadores NFC son estáticos. Para una operación pública prolongada o
recompensas valiosas hay que reforzar la protección contra copias y limitar
intentos en `start-encounter` (ver `docs/nfc.md`).
