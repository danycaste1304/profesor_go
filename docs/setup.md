# Setup local

## Requisitos

| Herramienta   | Versión probada | Notas                                             |
|---------------|-----------------|---------------------------------------------------|
| Flutter       | 3.47 (stable)   | incluye Dart 3.13                                  |
| Node.js       | 20 LTS          | admin Next.js                                      |
| Deno          | 2.x             | tests de Edge Functions                            |
| Supabase CLI  | 2.x             | `supabase start` necesita Docker                   |
| Docker        | 24+             | stack local de Supabase                            |
| Bash, curl, jq, psql | Bash 4+    | pruebas E2E (`brew install bash jq libpq` en macOS) |
| Android Studio / Xcode | —      | solo para compilar la app en dispositivo           |

`scripts/setup.sh` comprueba las versiones e instala dependencias de los tres proyectos.

## 1. Supabase local

```bash
supabase start            # primera vez descarga imágenes (varios minutos)
supabase db reset         # aplica migraciones + seed
supabase status -o env    # muestra API URL, anon key, service role key
```

Usuarios demo (solo local): `admin@profesorgo.local / admin12345` y
`player@profesorgo.local / player12345`.

La contraseña mínima es de **8 caracteres**: la fija `supabase/config.toml`
(`minimum_password_length = 8`) y la app la refleja en `AppConfig.minPasswordLength`.
Si cambias una, cambia la otra.

Edge Functions en local:

```bash
supabase functions serve --no-verify-jwt
```

(Las funciones verifican el JWT por sí mismas; `--no-verify-jwt` evita la doble
verificación del gateway local.)

Tests SQL (pgTAP): `supabase test db`.
Tests Deno: `cd supabase/functions && deno task test`.
End-to-end real (con el stack y las funciones sirviendo): `./scripts/e2e-local.sh`.
En macOS, el script detecta `psql` en la ruta de Homebrew aunque `libpq` no se haya
añadido al `PATH` global.

## 2. App móvil

```bash
cd apps/mobile
flutter pub get
flutter run                                   # DEMO_MODE=true por defecto: sin backend
cp .env.example .env                          # para usar Supabase real
flutter run --dart-define-from-file=.env      # DEMO_MODE=false + URL + anon key
```

En modo demo el GPS y el NFC son simulados; en todas las compilaciones demo aparece un selector
de tags demo en la pantalla de escaneo.

Para probar en un teléfono contra Supabase local usa la IP de tu máquina en
`SUPABASE_URL` (por ejemplo `http://192.168.1.10:54321`), no `127.0.0.1`.

## 3. Admin

```bash
cd apps/admin
npm install
cp .env.example .env.local     # rellena NEXT_PUBLIC_SUPABASE_URL / ANON_KEY
npm run dev                    # http://localhost:3000
```

## 4. Calidad

```bash
./scripts/check-all.sh          # todas las puertas de calidad, en el orden de la CI
```

O una por una:

```bash
cd apps/mobile && flutter analyze && flutter test
cd apps/admin  && npm run lint && npm run typecheck && npm test && npm run build
cd supabase/functions && deno task check && deno task lint && deno task test
supabase test db
```

`flutter analyze` se ejecuta sin `--no-fatal-infos`, igual que en la CI: cualquier *info* del
analizador rompe la build.

## 5. Builds

Android:

```bash
cd apps/mobile
flutter build apk --release --dart-define-from-file=.env
# o app bundle: flutter build appbundle --release --dart-define-from-file=.env
```

iOS (requiere macOS + Xcode, y el entitlement NFC en el perfil de la app):

```bash
cd apps/mobile
flutter build ipa --release --dart-define-from-file=.env
```

## 6. Despliegue de Supabase

```bash
supabase link --project-ref <ref>
supabase db push                       # migraciones
supabase functions deploy start-encounter resolve-capture admin-register-nfc
```

Después ejecuta `seed.sql` manualmente solo si quieres datos demo en producción (los
usuarios demo NO deben crearse en producción).
