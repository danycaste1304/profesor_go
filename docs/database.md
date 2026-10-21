# Base de datos

Esquema completo y contratos en `docs/CONTRACTS.md` (§2, §3, §9). Este documento explica
las decisiones.

## Tablas

| Tabla          | Propósito                                                          |
|----------------|--------------------------------------------------------------------|
| `profiles`     | Perfil de usuario (1:1 con `auth.users`), rol y fecha de colección completa |
| `professors`   | Catálogo de profesores, rareza, `base_capture_rate`, sprite, activo |
| `nfc_tags`     | Tarjetas NFC ↔ profesor; `tag_identifier` único                     |
| `encounters`   | Encuentro creado al leer un NFC; expira (`expires_at`)              |
| `captures`     | Una fila por (usuario, profesor) — `unique(user_id, professor_id)`  |
| `app_settings` | Parámetros del juego en JSON (expiración, bonus por lanzamiento)     |

## Rarezas y probabilidad

```text
COMMON 0.80 · RARE 0.60 · EPIC 0.40 · LEGENDARY 0.25
p = clamp(base_capture_rate + throw_bonus[quality], 0, 1)
MISS → bonus -1.0 → p = 0 (siempre falla)
```

La probabilidad final **nunca** se calcula en el cliente. El mock de demo la reproduce
solo para que la app funcione sin backend.

## RLS

| Tabla        | player                               | admin        | service_role |
|--------------|--------------------------------------|--------------|--------------|
| profiles     | leer/editar la propia (no `role`)    | leer todas   | todo         |
| professors   | leer activos                         | CRUD         | todo         |
| nfc_tags     | **nada**                             | CRUD         | todo         |
| encounters   | leer propios                         | leer todos   | todo         |
| captures     | leer propias                         | leer todas   | todo         |
| app_settings | leer                                 | CRUD         | todo         |

Las inserciones en `encounters` y `captures` solo las hacen las Edge Functions con
`service_role`. Ningún cliente puede insertar una captura directamente.

## Funciones

- `is_admin()` — helper `security definer` para políticas sin recursión.
- `collection_progress(p_user)` — `{captured, total, completed}`; `total` cuenta solo
  profesores activos, `captured` solo capturas de profesores activos.
- `admin_stats()` — métricas del dashboard (solo admin).
- `resolve_capture_tx(p_encounter_id, p_user_id, p_throw_quality, p_roll)` — resolución
  atómica con `select … for update`; idempotente; solo `service_role`.

## Concurrencia

Dos peticiones simultáneas de `resolve-capture` para el mismo encounter se serializan por el
bloqueo de fila; la segunda ve el estado ya resuelto y devuelve el mismo resultado
(`ALREADY_RESOLVED`). Si por otro camino existiera ya una captura, la restricción
`unique(user_id, professor_id)` la rechaza y se reporta `ALREADY_CAPTURED`.

## Colección completa

```sql
captures del usuario sobre profesores activos = count(professors where active)
```

Los profesores desactivados no cuentan. `collection_completed_at` se fija la primera vez que
se cumple; no se borra si luego se añade un profesor nuevo (decisión de UX: el logro se
conserva; el progreso mostrará `n / n+1`).

## Migraciones

```bash
supabase start          # levanta el stack local
supabase db reset       # aplica migrations + seed.sql
supabase test db        # ejecuta los tests pgTAP en supabase/tests
```

Para crear una migración nueva: `supabase migration new <nombre>`.
