# Ensayo presencial de Profesor GO — USFQ, 29 de octubre de 2026

Objetivo: decidir con evidencia si la beta 10 sirve para la feria. Probar con
**dos Android de modelos distintos, un iPhone con Safari, dos estudiantes con
cuentas Google diferentes y un profesor**. Usar datos móviles durante al menos
una pasada completa. Llevar la hoja impresa de los diez QR, una etiqueta NFC
activa, cargadores y una persona que anote resultados.

## Preparación (10 minutos)

- [ ] Descargar el [APK beta 10](https://github.com/danycaste1304/profesor_go/releases/download/v0.1.0-beta.10/profesor-go-beta10-android.apk). Si hay beta 8 instalada, desinstalarla primero: sus firmas son distintas. Anotar modelo, versión Android/iOS y hora.
- [ ] Instalar en un Android limpio; abrir en iPhone la [web de Safari](https://danycaste1304.github.io/profesor_go/jugar/). Confirmar que se ve la pantalla de acceso, sin pantalla blanca.
- [ ] Entrar con una cuenta Google nueva en cada plataforma; cerrar y reabrir. Confirmar que la sesión persiste y que cada cuenta ve su propia colección.
- [ ] Abrir un QR **antes** de iniciar sesión en otro navegador o sesión privada. Tras Google OAuth debe volver al encuentro del profesor correcto.
- [ ] Hacer que el profesor entre una vez con su cuenta Google. Un administrador debe vincular esa cuenta con su personaje antes de probar el marcador: al 28 de octubre había cero cuentas de profesor vinculadas.

## Mapa y GPS (15 minutos)

- [ ] Caminar por el campus y comprobar avatar, precisión y centrado cerca de **Einstein, Biblioteca y Da Vinci**; anotar distancia aproximada entre punto real y avatar en cada lugar.
- [ ] Revisar los accesos, senderos y edificios en el mapa hasta los extremos del recorrido. Registrar nombres ausentes o mal ubicados con foto y punto GPS si se puede.
- [ ] Repetir una ubicación exterior y otra interior; anotar si la precisión mostrada aumenta o si el punto salta. No exigir precisión de edificio dentro de un aula.
- [ ] Negar permiso de ubicación y luego apagar GPS/señal: debe verse un estado entendible y todavía se debe poder abrir un QR y jugar.
- [ ] Cambiar de Wi-Fi a datos móviles y volver; comprobar que mapa, sesión y QR se recuperan.

## Profesor y búsqueda (15 minutos)

- [ ] Antes de pulsar **Iniciar**, ningún estudiante debe ver su marcador.
- [ ] El profesor inicia desde `https://danycaste1304.github.io/profesor_go/anfitrion.html` y concede ubicación. Los estudiantes ven solo su último punto fresco; comprobar que el círculo de precisión tiene sentido.
- [ ] Otro estudiante o profesor no vinculado intenta iniciar/publicar: debe recibir rechazo.
- [ ] El profesor camina 20–30 metros con la pantalla abierta; confirmar actualización del marcador. Bloquear el teléfono o cerrar la página más de 30 segundos; el marcador debe desaparecer.
- [ ] Volver a abrir la página, publicar de nuevo y pulsar **Detener**; el marcador debe desaparecer sin esperar al vencimiento.

## QR, NFC y captura (20 minutos)

- [ ] Escanear los diez QR impresos con la cámara interna de Android y con la cámara del iPhone/Safari; cada uno debe mostrar **su propio profesor**. Anotar cualquier QR que no enfoque, abra una página incorrecta o quede en blanco.
- [ ] Completar un encuentro en Android y otro en iPhone: minijuego, resultado y colección. Entrar con la misma cuenta en el otro dispositivo y comprobar que la captura aparece.
- [ ] Durante una búsqueda activa, escanear un QR con una cuenta que **ya capturó** a ese profesor. Debe registrar el hallazgo aunque no otorgue otra captura.
- [ ] Repetir el mismo QR dos veces con la misma cuenta y búsqueda: debe quedar un solo hallazgo. Probar también dos escaneos casi simultáneos.
- [ ] Leer una etiqueta NFC activa en Android y comprobar el mismo profesor y recorrido. En iPhone usar QR.
- [ ] Con el administrador presente, desactivar **un QR de prueba**, confirmar que falla, reemplazarlo y confirmar que el nuevo funciona. Reimprimir ese código antes del evento. No publicar tokens QR en capturas o mensajes.
- [ ] Exportar la lista de hallazgos y contrastar estudiante, profesor y hora con lo anotado en papel. No compartir públicamente datos personales de estudiantes.

## Corte de salida (5 minutos)

- [ ] Marcar **apto** solo si funcionan acceso nuevo, QR, captura, colección y Safari de iPhone sin bloqueo; el mapa cubre el recorrido y la ubicación del profesor se puede iniciar/detener.
- [ ] Si falla cualquiera de esos recorridos, registrar el problema, corregirlo y repetir la prueba antes de anunciar la función. El APK y la web se consideran **beta de ensayo** hasta entonces.

## Registro rápido de problemas

Para cada fallo anotar: **hora**, plataforma/modelo y versión del sistema,
**cuenta de prueba** (sin contraseña), pantalla o edificio, pasos exactos,
resultado esperado, resultado observado, red usada y captura de pantalla.
Enviar el registro al equipo sin mostrar los códigos QR completos.
