# Profesor GO

> Nombre provisional. Juego móvil para una feria universitaria: **encuentra físicamente a
> todos los profesores participantes y captúralos en la app** leyendo su tarjeta NFC y
> ganando un minijuego de lanzamiento.

Interfaz de exploración luminosa inspirada en los juegos de mapa y captura como Pokémon GO, con ilustraciones vectoriales y personajes propios. No incluye marcas ni assets de terceros.

## Qué hay en el repositorio

```text
profesor-go/
├── apps/
│   ├── mobile/     Flutter (Riverpod + GoRouter + supabase_flutter) — la app del jugador
│   └── admin/      Next.js + Tailwind + Supabase — panel de administración
├── supabase/
│   ├── migrations/ esquema, triggers, RPC, RLS, storage
│   ├── functions/  Edge Functions (Deno): start-encounter, resolve-capture, admin-register-nfc
│   ├── tests/      tests pgTAP
│   ├── seed.sql    10 profesores reales, tags DEMO-TAG-01..10, ajustes, usuarios demo
│   └── config.toml
├── docs/           architecture · database · game-design · nfc · privacy · setup · CONTRACTS
├── scripts/        setup.sh · check-all.sh · db-reset.sh · db-test.sh ·
│                   supabase-start.sh · e2e-local.sh
└── .github/workflows/ci.yml
```

## Arquitectura en una frase

El cliente Flutter lee el NFC y juega el minijuego; **todo lo que afecta al progreso se
decide en el servidor** (Edge Functions + RPC transaccional con `service_role`), y el
panel Next.js administra profesores y tarjetas bajo RLS. Detalles en
[`docs/architecture.md`](docs/architecture.md) y contratos en
[`docs/CONTRACTS.md`](docs/CONTRACTS.md).

## Requisitos

Flutter 3.47+, Node 20, Deno 2, Supabase CLI 2, Docker, `jq` y `psql` para el E2E.
`scripts/setup.sh` los comprueba e instala las dependencias del proyecto. En macOS,
`brew install libpq` proporciona `psql`; el script E2E detecta su ruta de Homebrew.

## Instalación rápida

```bash
git clone https://github.com/danycaste1304/profesor_go.git profesor-go && cd profesor-go
./scripts/setup.sh
```

### Supabase local

```bash
supabase start                 # levanta Postgres, Auth, Storage, Edge Runtime, Studio
supabase db reset              # migraciones + seed
supabase status -o env         # API URL + claves para los .env
supabase functions serve --no-verify-jwt
```

Usuarios demo locales: `admin@profesorgo.local / admin12345`, `player@profesorgo.local / player12345`.

### App móvil

```bash
cd apps/mobile
flutter pub get
flutter run                                  # modo demo (sin backend, GPS ni NFC reales)
flutter run --dart-define-from-file=.env     # contra Supabase (DEMO_MODE=false)
```

### Admin

```bash
cd apps/admin
npm install && cp .env.example .env.local && npm run dev   # http://localhost:3000
```

## Migraciones y seed

- Migraciones en `supabase/migrations/` (orden por timestamp). Nueva: `supabase migration new <nombre>`.
- Seed en `supabase/seed.sql`, idempotente; se aplica con `supabase db reset`.
- Esquema, RLS y RPC documentados en [`docs/database.md`](docs/database.md).

## Tests

```bash
./scripts/check-all.sh                     # todo lo que ejecuta la CI
cd apps/mobile && flutter analyze && flutter test
cd apps/admin && npm run lint && npm run typecheck && npm test && npm run build
cd supabase/functions && deno task check && deno task lint && deno task test
supabase test db                           # pgTAP (requiere supabase start)
```

End-to-end del backend real (requiere `supabase start` + `supabase functions serve --no-verify-jwt`):

```bash
./scripts/e2e-local.sh    # ~200 comprobaciones: auth, RLS, las 3 Edge Functions,
                          # expiración, idempotencia, concurrencia, colección completa
```

Crea sus propios usuarios/profesores/tags con un sufijo aleatorio y los borra al terminar;
no modifica los datos del seed.

## Demo mode

`DEMO_MODE=true` (valor por defecto si no se define nada):

- sin GPS real: el avatar recorre una ruta simulada (toggle "simular movimiento");
- sin NFC real: selector de tags demo en la pantalla de escaneo, también en el APK release demo;
- datos en memoria que reproducen las reglas del servidor (probabilidad, expiración, unicidad).

Ideal para desarrollo, tests y presentaciones sin infraestructura.

## Builds

```bash
cd apps/mobile
flutter build apk --release --dart-define-from-file=.env         # Android
flutter build ipa --release --dart-define-from-file=.env         # iOS (macOS + Xcode)
```

iOS necesita el entitlement *Near Field Communication Tag Reading* en el App ID.

## Documentación

| Documento                                     | Contenido                                   |
|-----------------------------------------------|---------------------------------------------|
| [docs/architecture.md](docs/architecture.md)  | capas, flujo, principios, modo sin conexión |
| [docs/database.md](docs/database.md)          | tablas, RLS, RPC, concurrencia              |
| [docs/game-design.md](docs/game-design.md)    | reglas, minijuego, anti-trampas, a11y       |
| [docs/nfc.md](docs/nfc.md)                    | lectura NFC, compatibilidad, seguridad      |
| [docs/privacy.md](docs/privacy.md)            | qué datos se guardan y cuáles no            |
| [docs/setup.md](docs/setup.md)                | instalación paso a paso, builds, despliegue |
| [docs/CONTRACTS.md](docs/CONTRACTS.md)        | contratos entre móvil, backend y admin      |
| [docs/cambios-ui.md](docs/cambios-ui.md)      | cambios de UI pixel art (fuentes, componentes) |

## Información externa pendiente

Los diez profesores ya tienen retrato y sprite propios, y el mapa demo está terminado.
Para usar el juego en la feria faltan los límites GPS y el plano real del lugar,
las tarjetas NFC físicas y sus identificadores, y un proyecto Supabase de producción.
Buscar `TODO_EXTERNAL` en el código para los puntos de configuración correspondientes.

## Licencia

MIT — ver [LICENSE](LICENSE).
