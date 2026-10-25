# Profesor GO — Contratos compartidos (fuente de verdad para todos los módulos)

Este documento fija los nombres, tipos, formas de request/response y convenciones
que deben respetar **supabase/**, **apps/mobile/** y **apps/admin/**. Si algo aquí
cambia, hay que cambiar los tres lados.

## 1. Enumeraciones

| Enum            | Valores                                   |
|-----------------|-------------------------------------------|
| `role`          | `player`, `admin`                          |
| `rarity`        | `COMMON`, `RARE`, `EPIC`, `LEGENDARY`      |
| `encounter status` | `ACTIVE`, `SUCCESS`, `FAILED`, `EXPIRED` |
| `throw_quality` | `MISS`, `GOOD`, `GREAT`, `EXCELLENT`       |

Base capture rate por rareza (defaults, editables por admin por profesor):
`COMMON 0.80 · RARE 0.60 · EPIC 0.40 · LEGENDARY 0.25`.

## 2. Esquema SQL (schema `public`)

```sql
profiles(
  id uuid pk references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  role text not null default 'player' check (role in ('player','admin')),
  created_at timestamptz default now(),
  collection_completed_at timestamptz
)

professors(
  id uuid pk default gen_random_uuid(),
  name text not null,
  display_name text not null,
  description text,
  rarity text not null check (rarity in ('COMMON','RARE','EPIC','LEGENDARY')),
  sprite_url text,
  active boolean not null default true,
  base_capture_rate numeric not null check (base_capture_rate >= 0 and base_capture_rate <= 1),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
)

nfc_tags(
  id uuid pk default gen_random_uuid(),
  professor_id uuid references professors(id) on delete set null,
  tag_identifier text unique not null,
  active boolean not null default true,
  created_at timestamptz default now()
)

encounters(
  id uuid pk default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  professor_id uuid not null references professors(id) on delete cascade,
  created_at timestamptz default now(),
  expires_at timestamptz not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUCCESS','FAILED','EXPIRED'))
)

captures(
  id uuid pk default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  professor_id uuid not null references professors(id) on delete cascade,
  encounter_id uuid references encounters(id) on delete set null,
  throw_quality text not null check (throw_quality in ('MISS','GOOD','GREAT','EXCELLENT')),
  captured_at timestamptz default now(),
  unique (user_id, professor_id)
)

app_settings(
  key text pk,
  value jsonb not null,
  updated_at timestamptz default now()
)
```

Filas iniciales de `app_settings`:

```json
{ "key": "encounter_expiration_seconds", "value": 180 }
{ "key": "throw_bonus", "value": { "MISS": -1.0, "GOOD": 0.0, "GREAT": 0.10, "EXCELLENT": 0.20 } }
```

Trigger: al crear un usuario en `auth.users` se inserta su `profiles` (email, display_name desde
`raw_user_meta_data->>'display_name'`, role `player`).

Helper SQL: `public.is_admin()` → `exists(select 1 from profiles where id = auth.uid() and role = 'admin')`
(security definer, para usar en RLS sin recursión).

Vistas/RPC públicas (security invoker salvo que se indique):
- `public.collection_progress(p_user uuid default auth.uid())` → `{captured int, total int, completed bool}`
  (`total` = profesores activos; `captured` = capturas del usuario sobre profesores activos).
- `public.admin_stats()` (solo admin) → `{total_players, total_captures, active_professors, completed_collections}`.
- `public.resolve_capture_tx(...)` RPC security definer usada por la Edge Function `resolve-capture`
  para que la resolución sea atómica (ver §4).

Probabilidad final (server-side): `p = clamp(base_capture_rate + throw_bonus[quality], 0, 1)`;
`MISS` → bonus `-1.0` → p = 0 → siempre falla.

## 3. RLS (resumen)

| Tabla        | player                                              | admin        |
|--------------|-----------------------------------------------------|--------------|
| profiles     | select/update propia fila (no puede cambiar `role`) | select todas |
| professors   | select donde `active = true`                        | CRUD         |
| nfc_tags     | **sin acceso**                                      | CRUD         |
| encounters   | select propias                                      | select todas |
| captures     | select propias (**no insert/update/delete**)        | select todas |
| app_settings | select                                              | CRUD         |

Capturas y encounters se escriben solo con `service_role` desde Edge Functions.

Storage: buckets `professor-sprites` y `game-assets`, públicos para lectura, escritura solo admin.
Restringidos en el servidor: `professor-sprites` acepta `image/png|jpeg|webp|gif` (máx. 2 MiB) y
`game-assets` un allowlist equivalente (máx. 5 MiB). SVG está prohibido a propósito (XSS almacenado).

## 4. Edge Functions (`supabase/functions/*`)

Todas: `POST`, `Authorization: Bearer <jwt usuario>`, body JSON, respuesta JSON.
Errores: HTTP 4xx con `{ "error": "<CODE>", "message": "<texto legible>" }`.

### `start-encounter`
Request `{ "tag_identifier": "string" }`
Response 200:
```json
{ "encounter_id": "uuid", "expires_at": "iso8601",
  "professor": { "id": "uuid", "display_name": "…", "rarity": "RARE", "sprite_url": "…|null", "description": "…|null" } }
```
Errores: `UNAUTHORIZED` (401), `TAG_NOT_FOUND` (404), `TAG_DISABLED` (403), `PROFESSOR_DISABLED` (403),
`ALREADY_CAPTURED` (409), `INVALID_INPUT` (400).
Al iniciar, los encounters `ACTIVE` previos del mismo usuario+profesor pasan a `EXPIRED`.

### `resolve-capture`
Request `{ "encounter_id": "uuid", "throw_quality": "MISS|GOOD|GREAT|EXCELLENT" }`
Response 200 éxito: `{ "success": true, "professor_id": "uuid", "collection": { "captured": 8, "total": 12, "completed": false } }`
Response 200 fracaso: `{ "success": false, "retry_requires_new_nfc_scan": true }`
Errores: `UNAUTHORIZED` (401), `ENCOUNTER_NOT_FOUND` (404), `FORBIDDEN` (403, otro usuario),
`ENCOUNTER_NOT_ACTIVE` (409, ya resuelto — idempotente: si ya fue SUCCESS con capture existente devuelve
el mismo resultado exitoso), `ENCOUNTER_EXPIRED` (410; además marca EXPIRED), `ALREADY_CAPTURED` (409),
`INVALID_INPUT` (400).

### `admin-register-nfc`
Request `{ "tag_identifier": "string", "professor_id": "uuid|null", "active": true }`
Response 200: `{ "tag": { "id", "tag_identifier", "professor_id", "active", "created_at" } }` (upsert por `tag_identifier`).
Errores: `UNAUTHORIZED` (401), `FORBIDDEN` (403, no admin), `PROFESSOR_NOT_FOUND` (404), `INVALID_INPUT` (400).

Código compartido en `supabase/functions/_shared/` (cors, respuesta de error, cliente supabase, auth,
validación). Validación de entrada común: `tag_identifier` string no vacío, recortado, máx. 128
caracteres y sin caracteres de control; `encounter_id` UUID estricto; `throw_quality` enum exacto;
`professor_id` UUID o null; cuerpo JSON máx. 8 KiB. Todo lo que no cumpla → `INVALID_INPUT` (400).
Además de los códigos de §4 existen dos de transporte: `METHOD_NOT_ALLOWED` (405) e `INTERNAL_ERROR` (500).
Tests en `supabase/functions/**/*.test.ts` ejecutables con `deno test` sin red (lógica pura + cliente mock).

## 5. Seed (`supabase/seed.sql`)

10 profesores reales, tags demo con `tag_identifier`
`DEMO-TAG-01` … `DEMO-TAG-10`, `app_settings`, y usuario admin demo
`admin@profesorgo.local` / `admin12345` + jugador demo `player@profesorgo.local` / `player12345`
(creados en `auth.users` con `crypt()` de pgcrypto — solo para entorno local).

| # | name             | display_name    | rarity    | rate |
|---|------------------|-----------------|-----------|------|
| 1 | Henry Carvajal   | Prof. Henry     | COMMON    | 0.80 |
| 2 | Felipe Grijalva  | Prof. Felipe    | EPIC      | 0.40 |
| 3 | José David Vega  | Prof. José David | COMMON   | 0.80 |
| 4 | Ricardo Flores   | Prof. Ricardo   | RARE      | 0.60 |
| 5 | Pavel Alba       | Prof. Pavel     | EPIC      | 0.40 |
| 6 | Noel Pérez       | Prof. Noel      | EPIC      | 0.40 |
| 7 | Daniel Riofrío   | Prof. Daniel    | LEGENDARY | 0.25 |
| 8 | Erick Ñauñay     | Prof. Erick     | LEGENDARY | 0.25 |
| 9 | Diego Morales    | Prof. Diego     | RARE      | 0.60 |
| 10 | Roberto Andrade | Prof. Roberto   | COMMON    | 0.80 |

Los UUID son fijos: sufijo `0016` para Henry, `0015` para Felipe,
`0014` para José David, `0013` para Ricardo, `0012` para Pavel, `0011` para
Noel, `0009` para Daniel, `0010` para Erick, `0017` para Diego y `0018`
para Roberto. Las diez tarjetas demo siguen ese orden.

## 6. Variables de entorno

Mobile (`apps/mobile/.env` vía `--dart-define-from-file` o `--dart-define`):
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DEMO_MODE` (`true|false`, default `true`).

Admin (`apps/admin/.env.local`): `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

Supabase local: `supabase start` en puertos por defecto (API 54321, DB 54322, Studio 54323).

## 7. Convenciones Flutter

- Paquete `profesor_go`; feature-first: `lib/features/<feature>/{data,domain,presentation}`.
- Estado: Riverpod (`flutter_riverpod`), navegación `go_router`. Los modelos son clases Dart
  inmutables con `fromJson/toJson/copyWith` escritos a mano: **sin `build_runner`** (freezed /
  json_serializable) para mantener el proyecto liviano y evitar codegen compartido.
- Rutas: `/splash`, `/login`, `/register`, `/map`, `/scan`, `/encounter/:encounterId`,
  `/result`, `/collection`, `/collection/:professorId`, `/profile`, `/completion`.
- `DEMO_MODE=true` → `MockNfcService`, `MockLocationService`, `MockProfessorRepository`,
  `MockCaptureService` (todo en memoria, sin backend). `DEMO_MODE=false` → implementaciones Supabase.
- Widgets propios: `PixelCard`, `PixelButton`, `RarityBadge`, `ProfessorSprite`, `ProgressBar`, `CaptureBall`.
- Rareza siempre con etiqueta de texto además del color (accesibilidad).
- Contraseña mínima **8 caracteres**, alineada con `supabase/config.toml`
  (`minimum_password_length = 8`) y expuesta como `AppConfig.minPasswordLength`.

## 8. Convenciones Admin (Next.js App Router)

Rutas: `/login`, `/dashboard`, `/professors`, `/professors/new`, `/professors/[id]`, `/nfc`.
Cliente Supabase con `@supabase/ssr`; solo usuarios con `profiles.role = 'admin'` pasan el guard.

## 9. RPC atómico `resolve_capture_tx` (firma fija)

```sql
create or replace function public.resolve_capture_tx(
  p_encounter_id uuid,
  p_user_id      uuid,
  p_throw_quality text,
  p_roll         numeric default null   -- valor en [0,1); null => random() en SQL
) returns jsonb
language plpgsql security definer set search_path = ''   -- refs fully schema-qualified
```

Comportamiento (todo dentro de la misma transacción, con `select … for update` sobre el encounter):

| Situación                                             | `outcome`          | efecto                                  |
|-------------------------------------------------------|--------------------|-----------------------------------------|
| encounter no existe                                   | `NOT_FOUND`        | —                                       |
| `user_id` ≠ `p_user_id`                               | `FORBIDDEN`        | —                                       |
| status `SUCCESS` y ya existe capture del user+prof    | `ALREADY_RESOLVED` | devuelve `success=true` idempotente     |
| status ≠ `ACTIVE` (FAILED/EXPIRED)                    | `NOT_ACTIVE`       | —                                       |
| `expires_at < now()`                                  | `EXPIRED`          | marca encounter `EXPIRED`               |
| ya existe capture user+prof (otro encounter)          | `ALREADY_CAPTURED` | marca encounter `EXPIRED`               |
| roll < p                                              | `SUCCESS`          | encounter `SUCCESS` + insert capture + `collection_completed_at` si completa |
| roll ≥ p                                              | `FAILED`           | encounter `FAILED`                      |

Retorno: `{"outcome": "...", "professor_id": uuid|null, "probability": numeric|null,
"throw_quality": text, "collection": {"captured": int, "total": int, "completed": bool} | null}`.

`p = least(1, greatest(0, base_capture_rate + (app_settings.throw_bonus ->> quality)::numeric))`.
Se ejecuta solo con `service_role` (revocar `execute` a `anon`/`authenticated`).

## 10. Edge Function ↔ RPC

`resolve-capture` (TS) valida input y JWT, obtiene el `user_id` del JWT, genera `roll` con
`crypto.getRandomValues`, llama a `resolve_capture_tx` con `service_role` y mapea `outcome` →
respuesta HTTP de §4. `start-encounter` hace sus consultas con `service_role` directamente
(tag → profesor → captura previa → expirar ACTIVE previos → insertar encounter).
