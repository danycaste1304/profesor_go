# NFC

## Flujo

```text
NFCScanScreen → NfcService.scanTag() → tag_identifier → Edge Function start-encounter
```

`NfcService` es una abstracción con dos implementaciones:

- `RealNfcService` (paquete `nfc_manager`): prioriza el registro externo
  `estimote.com:id` de los Estimote compatibles y devuelve
  `ESTIMOTE:<payload hexadecimal en mayúsculas>`. En otros tags lee el registro
  NDEF de texto si existe; si no, usa el UID físico en hexadecimal.
- `MockNfcService`: devuelve un tag demo seleccionable (`DEMO-TAG-01 … 10`). Es la
  implementación en `DEMO_MODE=true` y en tests. En todas las compilaciones demo se
  muestra un selector de tags; no se inicia una lectura automática.

## Compatibilidad

| Situación                 | Comportamiento                                             |
|---------------------------|------------------------------------------------------------|
| Android con NFC           | Lectura en segundo plano al abrir la pantalla               |
| iPhone 7+ (iOS 13+)       | Sesión de lectura del sistema (hoja nativa)                 |
| Dispositivo sin NFC       | Mensaje "Este dispositivo no tiene NFC"                     |
| NFC apagado (Android)     | Mensaje + botón «Abrir ajustes de NFC» (intent del sistema)  |
| NFC apagado (iOS)         | Solo mensaje: iOS no expone una pantalla de ajustes de NFC  |
| Tag desconocido           | `TAG_NOT_FOUND` → "Esta tarjeta no es válida"               |
| Tag desactivado           | `TAG_DISABLED`                                              |
| Error de lectura          | Mensaje amigable + reintentar                               |

El botón de ajustes usa un `MethodChannel` propio (`edu.profesorgo/settings` →
`Settings.ACTION_NFC_SETTINGS` en `MainActivity.kt`); si el canal no existe (iOS, web o una
build sin la parte nativa) el botón no se muestra y, si la llamada falla, la app solo enseña
un aviso — nunca un error técnico.

## Estimote Location Beacons

El Development Kit fotografiado para este proyecto contiene tres Location Beacons
Bluetooth Low Energy. El empaque indica que también tienen un tag NFC programable.
La app usa **el toque NFC** para iniciar el encuentro; todavía no usa la señal
Bluetooth para detección por cercanía. La documentación de Estimote describe el
registro `estimote.com:id` en los Location Beacons compatibles. El identificador
devuelto por la app se registra tal cual en el panel admin; no es el UUID de iBeacon.
Hay que confirmar en el dispositivo físico que la revisión concreta emite ese
registro y que su batería/NFC funcionan.

Para asociar uno a un profesor:

1. Instala una build con `DEMO_MODE=false` y un backend Supabase real.
2. Entra en la app con una **cuenta admin**, abre «Capturar» y toca el beacon.
3. Si todavía no está registrado, la pantalla muestra el identificador leído
   después de `TAG_NOT_FOUND`. Cópialo exactamente.
4. En el panel admin, «Tarjetas NFC → Registrar tag», pega ese valor, selecciona
   el profesor y deja el tag activo.
5. Vuelve a tocar el beacon con una cuenta de jugador y completa un encuentro.

Un kit tiene tres beacons. La usuaria confirmó cuatro kits o más: hay al menos
doce dispositivos para los diez profesores, con dos o más de reserva. Hay que
contarlos y comprobar por separado el NFC de cada uno antes de asignarlos.

### Diagnóstico físico de los beacons

El APK `apps/mobile/build/nfc-diagnostic/profesor-go-nfc-diagnostico.apk`
se compila con `./scripts/build-nfc-diagnostic-android.sh`. Es una herramienta
local: no pide cuenta ni internet y no registra datos en Supabase. Usa el mismo
servicio de lectura que la app principal, pero se instala como un paquete Android
separado (`edu.profesorgo.profesor_go.nfcdiag`) con el nombre **Profesor GO NFC**.
No reemplaza la app principal en el teléfono.

1. En el Android, activa NFC en Ajustes y abre **Prueba NFC · Profesor GO**.
2. Pulsa **Leer un beacon** y acércalo a distintos puntos de la parte trasera
   del teléfono durante unos segundos; gíralo si no responde.
3. La lectura muestra el identificador Estimote (si está disponible) y el UID
   físico del tag. Pega una etiqueta con el número mostrado (01, 02, etc.) en
   ese beacon y repite con todos, en un orden fijo.
4. Pulsa **Copiar lista de identificadores**. La lista incluye ambos valores,
   detecta duplicados por identificador o UID y conserva el orden mientras la
   app siga abierta. Guarda una copia antes de cerrarla; el diagnóstico no
   persiste esa lista en el teléfono.
5. Si no hay lectura, prueba otro beacon, confirma que NFC sigue activado y
   quita una funda gruesa. Si ninguno responde, anota modelo del Android y
   muestra una captura de la pantalla de diagnóstico.

La lectura NFC es distinta de la señal Bluetooth BLE del beacon. No hay que
emparejarlo por Bluetooth para esta prueba.

Si una lectura devuelve `ESTIMOTE:<hex>` y otra devuelve solo el UID del mismo
beacon, registra **ambos identificadores** como tags activos del mismo profesor.
La aplicación puede recurrir al UID cuando no logra leer el registro NDEF.
Después valida cada uno en **Profesor GO → Capturar**.

El beacon físico **08 → Prof. Pavel** mostró un UID adicional en la APK real
el 25 de octubre de 2026. Se registró de forma privada en Supabase sin
eliminar los identificadores anteriores. El Galaxy A52 abrió el encuentro de
Pavel al leer el 08 separado de los otros beacons.

Los Estimote pueden incluir un Android Application Record (AAR) que apunta a
otra app. Si Android lee el beacon fuera de la sesión de captura, ese AAR puede
abrir Play Store. En la feria, espera a que aparezca **BUSCANDO TARJETA** antes
de acercar el beacon y sepáralo del teléfono al terminar. Para que un toque
fuera de la app abra Profesor GO, habría que configurar el AAR del beacon con
el paquete `edu.profesorgo.profesor_go` y volver a probar que conserva el
registro `estimote.com:id`; consulta la
[guía NFC de Estimote](https://developer.estimote.com/proximity/nfc/) antes de
reprogramar dispositivos.

## Programación de tarjetas

Para el MVP cualquier tag NFC (NTAG213/215/216 recomendados) sirve:

1. Opción A — sin escribir: registra en el admin el UID del tag (hex en mayúsculas).
2. Opción B — con NDEF: escribe un registro de texto con el identificador que registres
   en el admin (por ejemplo `PROF-HENRY-01`). Es más cómodo para reemplazar tarjetas.

Los tags `DEMO-TAG-01…10` solo se cargan con el seed **local**. La migración de
producción elimina esos identificadores de prueba; registra los físicos en el
panel antes de la prueba final.

## Limitación de seguridad (MVP)

El `tag_identifier` es **estático**: quien lo conozca puede iniciar un encuentro sin estar
frente al profesor. Es aceptable para una feria de un día con recompensas simbólicas,
porque:

- el servidor sigue controlando la probabilidad y la unicidad de la captura;
- los tags no se listan a los jugadores (RLS);
- cada encuentro expira en 3 minutos.

### Camino de migración

La lógica está encapsulada en `NfcService` (móvil) y en `start-encounter` (servidor), por
lo que se puede migrar sin tocar pantallas:

1. **Tokens rotativos**: el admin escribe en el tag un NDEF con `id:counter:hmac`; el servidor
   verifica el HMAC con un secreto por profesor y rechaza contadores repetidos.
2. **Tags criptográficos** (NTAG 424 DNA / SUN): la URL NDEF incluye un CMAC único por
   lectura; el servidor lo valida con la clave del tag.
3. **Firma del profesor**: alternativa sin hardware especial — el profesor muestra un QR
   rotativo que se combina con el NFC.

En los tres casos solo cambia el contenido de `tag_identifier` y la validación en
`start-encounter`.
