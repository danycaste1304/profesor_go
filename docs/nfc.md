# NFC

## Flujo

```text
NFCScanScreen → NfcService.scanTag() → tag_identifier → Edge Function start-encounter
```

`NfcService` es una abstracción con dos implementaciones:

- `RealNfcService` (paquete `nfc_manager`): lee el registro NDEF de texto si existe; si no,
  usa el identificador físico del tag en hexadecimal (mayúsculas, sin separadores).
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

## Programación de tarjetas

Para el MVP cualquier tag NFC (NTAG213/215/216 recomendados) sirve:

1. Opción A — sin escribir: registra en el admin el UID del tag (hex en mayúsculas).
2. Opción B — con NDEF: escribe un registro de texto con el identificador que registres
   en el admin (por ejemplo `PROF-HENRY-01`). Es más cómodo para reemplazar tarjetas.

`TODO_EXTERNAL:` reemplazar los tags demo del seed por los identificadores reales.

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
