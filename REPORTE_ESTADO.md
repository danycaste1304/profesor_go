# Estado del proyecto — Profesor GO

Revisión: 20 de octubre de 2026.

## Avance hacia operación real — 23 de octubre de 2026

- El kit mostrado es un Estimote Location Beacons Development Kit con tres
  beacons BLE; el empaque confirma que incluyen un tag NFC programable. La app
  ahora reconoce el registro `estimote.com:id` y usa `ESTIMOTE:<hex>` como
  identificador estable para el panel admin. Sigue pendiente leer los aparatos
  físicos en el Android de la usuaria. La usuaria confirmó al menos cuatro kits
  (doce beacons), suficientes para diez profesores y dos reservas.
- En modo real, un fallo de configuración de Supabase muestra un error de inicio
  en vez de habilitar capturas demo. Una build release real exige HTTPS.
- Una migración carga los ajustes necesarios sin el seed de desarrollo y borra
  `DEMO-TAG-01…10` de producción. El identificador de un beacon no registrado
  se muestra solamente a una cuenta admin para facilitar el alta.
- Guía de salida y requisitos externos: `docs/puesta-en-produccion.md`.
- `scripts/build-real-android.sh` impide generar por error el APK real sin
  `DEMO_MODE=false`, URL HTTPS y clave pública. Los archivos de entorno locales
  ya apuntan al nuevo proyecto Supabase «Profesor GO» en `us-east-1`. Las 19
  migraciones están aplicadas, las tres Edge Functions activas y la producción
  contiene diez profesores, ningún tag de ejemplo y cero cuentas de jugador.
- La app y el panel ya incluyen «Continuar con Google». Se creó un proyecto
  Google Cloud separado (`profesor-go-usfq`); falta completar su cliente OAuth,
  activar el proveedor en Supabase y probar el retorno en un Android físico.
- Verificación de esta fase: Flutter analyze sin problemas; 268 pruebas pasan
  y 12 pruebas se omiten en la ejecución general; la prueba de acceso Google
  en modo real también pasó por separado. Panel admin lint,
  TypeScript, 44 pruebas y build correctos. Las pruebas SQL no se ejecutaron
  porque el servicio Docker/Supabase local no estaba iniciado.

## Juego disponible

- App Flutter con modo demo jugable sin backend, GPS ni NFC: acceso, mapa, selección de diez tarjetas, encuentro, lanzamiento, captura, colección, perfil y finalización.
- Avatar del jugador redibujado en estilo chibi pixelado y más visible en el mapa. En Perfil se pueden elegir tres peinados, tres colores de ropa y tres accesorios, además de generar una combinación sorpresa. La elección se anima en la vista previa y se guarda por cuenta en el dispositivo.
- El peinado «Rizos» tiene mechones y contorno ondulado visibles en la vista previa y en el mapa, incluso al usar gorra.
- Estética de exploración y captura inspirada en los juegos de mapa y en los RPG portátiles clásicos: mapa propio de mosaicos, personajes chibi pixelados, escena de combate con plataformas, textos animados y música chiptune original para mapa, encuentro y victoria, más efectos de sonido. Un reproductor persistente conserva la preferencia y enlaza combate, fanfarria de victoria y mapa sin dejar la pantalla de resultado en silencio.
- La bola se lanza al deslizar desde abajo hacia el profesor. Se muestra la calidad, la trayectoria y la animación hasta el resultado; el gesto está cubierto por pruebas de interfaz y se comprobó en Android.
- El catálogo activo tiene diez profesores reales. Las dos cartas legendarias son Daniel Riofrio y Erick Ñauñay. Felipe Grijalva, Pavel Alba y Noel Perez son épicos; Ricardo Flores y Diego Morales son raros; Henry Carvajal, Jose David Vega y Roberto Andrade son comunes. Todos tienen retrato y sprite de cuerpo completo basados en las referencias recibidas. Noel permanece completamente calvo; Pavel tiene el rostro joven y liso pedido por la usuaria.
- `DEMO-TAG-01` a `DEMO-TAG-10` están vinculadas en la app y en Supabase. Las capturas de antiguos personajes de ejemplo no desbloquean sus reemplazos; la colección se completa en 10/10.
- En Perfil, «Reiniciar Profedex demo» borra las capturas y encuentros de prueba tras pedir confirmación. Conserva el avatar, la preferencia musical y la sesión.
- Panel administrativo Next.js para profesores y tarjetas NFC, y backend Supabase con RLS, Edge Functions y resolución transaccional de capturas.

## Verificación reciente

| Componente | Resultado |
|---|---|
| Flutter `analyze --no-pub` | Sin problemas. |
| Flutter `test --no-pub` | 265 pruebas pasan; 11 pruebas live se omiten sin las credenciales optativas. |
| Panel admin | ESLint, TypeScript, 44 pruebas y build de Next.js: correctos. |
| Edge Functions | Deno check y lint correctos; 98 pruebas pasan. |
| PostgreSQL `supabase test db` | 218 pruebas pasan en cinco suites, con la migración `20261019000800_ten_campus_professors.sql` aplicada localmente. |
| Android release | `apps/mobile/build/app/outputs/flutter-apk/app-release.apk` compilado para arm64 (41,9 MB según Flutter) e instalado en el emulador. |
| Revisión visual Android | Selector 01–10, encuentros de Henry, Diego, Roberto y Jose David. Se lanzaron bolas con gestos reales y se comprobó el resultado. El avatar personalizable se revisó en mapa y Perfil, y conservó su combinación al reiniciar la app. La Profedex demo se reinició desde 8/10 a 0/10 y siguió en 0/10 tras reabrir la app; el mapa mostró «MÚSICA SÍ». |
| Audio Android | Con música activada, los registros de Android confirmaron el bucle de combate, la fanfarria de victoria y el retorno al bucle de mapa tras la captura. El mapa seguía en «MÚSICA SÍ» al volver. |

Capturas de esta revisión: `docs/previews/avatar-personalizacion.png`, `docs/previews/avatar-rizos.png`, `docs/previews/felipe-encuentro.png`, `docs/previews/henry-encuentro.png`, `docs/previews/henry-captura.png`, `docs/previews/diego-encuentro.png`, `docs/previews/roberto-encuentro.png` y `docs/previews/roberto-captura.png`. Las vistas anteriores siguen en `docs/previews/`.

El APK release se firma con la clave de desarrollo porque aún no hay `android/key.properties`; se puede instalar para probar, pero hace falta una firma de producción para distribuirlo en una tienda. La música del mapa y la victoria es composición original; la del encuentro es el tema «Wild Pokémon Battle» de Pokémon Red/Blue (de terceros); los registros confirman la reproducción en el emulador, pero conviene escuchar la mezcla y el volumen en un dispositivo físico. La integración real de NFC y GPS también requiere un móvil compatible y las tarjetas físicas.

## Para jugar en modo demo

```bash
cd apps/mobile
flutter pub get
flutter run
```

Entrar con `player@profesorgo.local / player12345`, pulsar **Capturar**, elegir una tarjeta demo y deslizar la bola hacia el profesor. La sesión y las capturas demo se guardan localmente.

Para empezar otra partida, entrar en **Perfil → Opciones de demo → Reiniciar Profedex demo** y confirmar.

## Pendiente para la feria

1. Sustituir los límites GPS de muestra por los del campus y, si se desea, el mapa exacto del lugar.
2. Registrar los identificadores de las tarjetas NFC físicas y probar lectura y ubicación en teléfonos reales.
3. Preparar firma Android de producción. Para iOS, completar Xcode/CocoaPods y la capacidad NFC de Apple Developer.
4. Completar Google OAuth, autorizar los retornos, entrar con Gmail y elevar
   exclusivamente la cuenta de administración autorizada. Publicar el panel
   por HTTPS y probar el flujo completo contra producción.

Código fuente: [danycaste1304/profesor_go](https://github.com/danycaste1304/profesor_go). Los archivos de entorno, claves de firma, compilaciones locales y el retrato personal externo al juego quedan fuera del repositorio.
