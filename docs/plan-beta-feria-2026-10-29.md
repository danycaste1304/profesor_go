# Plan de beta para la búsqueda del profesor — feria del 29 de octubre de 2026

> Estado histórico del plan NFC inicial. La implementación Android + Safari
> con QR impreso y sus pendientes se registran en
> [estado-piloto-qr-2026-10-29.md](estado-piloto-qr-2026-10-29.md).

Fecha de evaluación: domingo 25 de octubre de 2026. Objetivo: tener una beta verificable **antes del miércoles 28** (martes 27 por la noche), probarla en el campus el miércoles y usarla en la feria el jueves 29.

Estado al 25 de octubre por la noche: la APK local beta 9 compiló, la migración
de búsqueda se aplicó a producción y una prueba funcional con rollback verificó
el flujo de 30 minutos y el hallazgo NFC. Quedan pendientes el Gmail nuevo, la
vinculación de la cuenta del profesor, la tarjeta física, el ensayo por todo el
campus y la publicación de la política de privacidad actualizada.

El profesor anfitrión confirmado es **Noel Pérez** (`Prof. Noel` en el juego).
Su personaje ya tiene dos tags NFC activos, que sirven para la prueba y como
respaldo. Falta que Noel entre con su cuenta Google y vincular ese correo al
personaje; no hay todavía una cuenta identificable como suya en `profiles`.
El correo institucional previsto fue confirmado por la organizadora, pero
todavía no existe en `auth.users`: Noel debe entrar una vez con Google antes
de que se pueda crear la asignación.
El teléfono de Noel probablemente sea iPhone. La organizadora eligió preparar
una página HTTPS de anfitrión para Safari. La página está implementada en
`docs/anfitrion.html` y comparte la misma sesión de 30 minutos mediante RPC;
faltan publicarla en `https://danycaste1304.github.io/profesor_go/anfitrion.html`,
autorizar esa URL exacta como retorno OAuth en Supabase y probarla en el iPhone.
La APK beta 9 sigue siendo necesaria para los estudiantes que escanearán NFC.
Antes de la feria, registrar la tarjeta pequeña que Noel llevará y **desactivar
los demás tags de Noel** mientras dure la búsqueda: actualmente cualquier tag
activo del mismo personaje registra el hallazgo, aunque esté en otro lugar.

## Decisión propuesta

Para esta feria, usar **Android + tarjeta NFC física pequeña + ubicación compartida voluntariamente desde el teléfono del profesor**. La tarjeta confirma el encuentro; la ubicación ayuda a buscarlo. El teléfono del profesor no necesita emitir NFC. Mantener el teléfono con la app abierta durante la sesión de 30 minutos evita incorporar ahora seguimiento en segundo plano.

El profesor recorrerá **todo el campus**, según lo confirmado por la usuaria. Por eso la compilación real usa un mapa geográfico desplazable de OpenStreetMap; la ilustración anterior se mantiene solo en demo. Hay que comprobar en el campus que todos los edificios y senderos necesarios estén representados y que la posición GPS sea útil en interiores.

El login con otro Gmail **todavía no se ha probado**; no hay un error reproducido que permita hablar de una corrección concreta. Esta es una prueba de aceptación obligatoria antes de repartir la APK.

## Base existente y trabajo nuevo

| Ya existe | Hay que agregar o validar |
| --- | --- |
| Flutter lee NDEF/UID de tarjetas y beacons; Supabase asocia el tag con un profesor. | Registrar y probar una tarjeta NFC del profesor en dos modelos Android; conservar el beacon ya vinculado como respaldo. |
| Google OAuth está integrado en la APK real. | Reproducir los fallos de login, probar una cuenta Gmail nueva, el retorno a la app, el perfil y la persistencia de sesión. |
| El GPS del estudiante mueve su avatar sobre un trayecto aproximado. | Usar un mapa geográfico de todo el campus, publicar el último punto del profesor y ocultar marcadores vencidos. |
| Las capturas se guardan por usuario y profesor. | Crear un registro de hallazgo **por evento**; hoy se rechaza repetir la captura de un profesor y eso excluiría a alumnos que ya lo tengan en su Profedex. |
| Existe panel admin para profesores y tags. | Crear inicio/fin de actividad y una lista de hallazgos para que el profesor pueda asignar el punto extra. |

## Flujo mínimo de la feria

1. Un organizador vincula la cuenta Google del profesor con su personaje y registra su tarjeta NFC. El servidor autoriza la publicación solo a esa cuenta o a un admin designado.
2. El profesor pulsa **Iniciar búsqueda**. El servidor fija `starts_at` y `ends_at = starts_at + 30 min`. Puede detenerla antes; la expiración también se aplica en el servidor aunque la app se cierre.
3. Mientras la pantalla está abierta, el teléfono intenta enviar una posición cada 10 segundos. Se guarda solo el último punto y su hora; no el recorrido. Se rechaza una precisión peor que 100 metros. La restricción geográfica a los límites exactos del campus queda pendiente de obtener y validar esos límites.
4. Los estudiantes autenticados ven un marcador con círculo de precisión en el mapa geográfico. El marcador desaparece al acabar los 30 minutos, al detenerse la actividad o si pasan aproximadamente 30 segundos sin una actualización válida.
5. Al encontrarlo, escanean la tarjeta que lleva el profesor. El servidor registra una sola constancia de hallazgo por alumno y evento, con hora. Esto debe funcionar aunque ese alumno ya haya capturado al personaje anteriormente. La captura normal y su minijuego pueden seguir disponibles para quien aún no lo tenga; el punto extra depende del hallazgo físico, no de la probabilidad del minijuego.
6. El organizador consulta o exporta la lista de alumnos con hallazgo confirmado. Solo esa lista sirve para el punto extra; ver el marcador en el mapa no cuenta.

## Orden de trabajo y cortes

| Cuándo | Entrega y comprobación |
| --- | --- |
| Domingo 25 / lunes 26 | Probar login Google con un Gmail nuevo; preparar cuenta del profesor y tarjeta NFC. Si el login no funciona en dos teléfonos reales, no repartir una beta abierta. |
| Lunes 26 | Implementar sesión de 30 minutos, autorización de publicación, último punto, expiración y lectura restringida a participantes. Actualizar textos de privacidad al introducir ubicación del profesor. |
| Martes 27 | Mostrar marcador y estado de frescura en el mapa; implementar constancia de hallazgo independiente de la Profedex y vista/lista para el punto extra. Generar APK beta real. |
| Martes 27, noche | Prueba completa con dos cuentas de estudiante, una de profesor, dos Android y datos móviles: inicio de sesión, compartir, buscar, escanear, alumno ya capturado, fin automático y fin anticipado. Solo después distribuir la APK. |
| Miércoles 28 | Caminata de 30 minutos por todo el campus: comprobar mapa, edificios, GPS exterior/interior, tarjeta real y beacon de respaldo. Corregir problemas de campo y congelar versión. |
| Jueves 29 | Activar la búsqueda con el profesor presente; comprobar conexión y marcador antes de anunciarla; revisar/exportar los hallazgos al terminar. |

## Condiciones para decir «lista»

- Una cuenta Google nueva entra y conserva sesión tras cerrar y reabrir la app en el Android que usarán los alumnos.
- Solo el profesor autorizado puede iniciar, actualizar o detener su sesión; los estudiantes no pueden escribir posiciones ni hallazgos manualmente.
- La posición nunca se muestra después de 30 minutos ni cuando queda obsoleta; se elimina al terminar y no se guarda historial.
- El mapa cubre el campus entero y dibuja el círculo de precisión. La limitación de GPS en interiores se explica y los puntos obsoletos desaparecen.
- La tarjeta NFC registra un hallazgo una sola vez por alumno y actividad, incluso si ese profesor ya estaba capturado. El panel permite revisar los registros del punto extra.
- El flujo completo se prueba con datos móviles y dispositivos físicos antes de distribuir la beta.

## Riesgos y respaldo

- **Mapa:** el mapa geográfico ya sustituye la proyección limitada en modo real, pero aún faltan pruebas físicas de cobertura y posición por todo el campus. El servidor todavía no comprueba un polígono del campus.
- **GPS y conectividad:** en edificios o bajo techo puede haber poca precisión o cortes. Mostrar frescura y precisión, y ocultar el marcador vencido. Si falla la ubicación en la prueba del miércoles, activar una zona manual por el organizador y mantener la captura NFC.
- **Pantalla del profesor:** compartir en segundo plano exige trabajo adicional de permisos, servicios y pruebas. Para esta sesión corta, mantener la pantalla y la app activas; si se bloquea el teléfono, el marcador caduca hasta que vuelva a actualizar.
- **Integridad del punto extra:** un identificador NFC estático puede copiarse. Para una recompensa académica, el profesor debe controlar físicamente la tarjeta y revisar la lista. Si se exige prueba fuerte, añadir después un código QR rotativo o confirmación del profesor.
- **Tarjeta nueva:** si no llega o falla, utilizar uno de los beacons NFC ya registrados; en ambos casos hay que hacer una lectura física con la APK final.

## Después de la feria

Investigar NFC teléfono a teléfono como prototipo **Android a Android** con HCE y un protocolo APDU propio. La lectura actual de NDEF/UID no basta para ello. Android Beam ya fue deprecado y la emulación libre de una tarjeta NFC por iPhone no está disponible para este caso. Para una beta de jugadores con Android e iPhone, continuar con etiquetas NFC físicas o usar un QR rotativo como mecanismo común.

## Decisiones pendientes para fijar el alcance

1. Confirmar si la beta del jueves puede ser solo Android.
2. Definir si el punto extra se concede por el toque NFC confirmado (implementado) o por ganar también el minijuego.
3. Probar el login con un Gmail nuevo y registrar cualquier fallo real junto con el modelo del teléfono.
