# Profesor GO — Admin panel

Next.js 15 (App Router, TypeScript, Tailwind) + Supabase (`@supabase/ssr`).
Manages professors, NFC tags and shows game stats. Only accounts with
`profiles.role = 'admin'` can sign in.

## Install

```bash
cd apps/admin
npm install
```

## Environment

```bash
cp .env.example .env.local
```

| Variable                        | Local default (from `supabase start` / `supabase status`) |
|---------------------------------|-----------------------------------------------------------|
| `NEXT_PUBLIC_SUPABASE_URL`      | `http://127.0.0.1:54321`                                  |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon key printed by `supabase status`                     |

`NEXT_PUBLIC_*` values are inlined into the browser bundle, so set them before
`npm run build` for a real deployment (the build itself never contacts Supabase).

`.npmrc` pins `node-options` for npm scripts; besides the heap size it also stops
host APM injectors (e.g. Datadog's `--require` in `NODE_OPTIONS`) from being
duplicated, which crashes the Next.js build worker.

## Run

```bash
npm run dev        # http://localhost:3000 → redirects to /login
```

Demo admin (local Supabase seed): `admin@profesorgo.local` / `admin12345`.
Player accounts are rejected with "Tu cuenta no es de administrador".

## Quality checks

```bash
npm run lint
npm run typecheck
npm test           # vitest unit tests for src/lib/{game,writes}.ts
npm run build      # no Supabase needed at build time (all data pages are dynamic)
npm start
```

## Layout

- `src/middleware.ts` — refreshes the session and guards every route (admin only).
- `src/lib/supabase/{client,server,middleware}.ts` — `@supabase/ssr` helpers.
- `src/lib/game.ts` — pure helpers (rarities, default capture rates, validation, formatting, sprite allowlist).
- `src/lib/writes.ts` — `interpretWrite`: turns a PostgREST mutation result into an explicit outcome.
- `src/lib/actions/*` — server actions (auth, professors, NFC via the `admin-register-nfc` Edge Function).
- `src/app/(app)/*` — protected pages: `/dashboard`, `/professors`, `/professors/new`, `/professors/[id]`, `/nfc`.
- `src/app/error.tsx`, `src/app/(app)/error.tsx`, `src/app/global-error.tsx` — Spanish error boundaries with
  a "Reintentar" button; `src/app/not-found.tsx` and `src/app/(app)/not-found.tsx` cover the 404s.
- `src/components/ui/*` — small plain-Tailwind UI kit (Button, Input, Select, Badge, Table, Card, Alert).

## Writes must be verified

PostgREST answers with **no error** when an `UPDATE` matches zero rows (deleted row,
wrong id, or a row RLS filtered out), so a mutation that only checks `error` reports
success while nothing was written. Every mutation therefore asks for the affected rows
back (`.select("id")`) and passes the result through `interpretWrite`, which turns
"cero filas" into a Spanish error: the form shows it, and the bound toggles throw so the
error boundary renders it.

## Sprite uploads

Sprites go to the **public** `professor-sprites` bucket, so an SVG stored there would be
served from the Supabase origin and is a stored-XSS vector. The uploader therefore:

- accepts a raster allowlist only — `image/png`, `image/jpeg`, `image/webp`, `image/gif`
  (`SPRITE_MIME_TYPES` in `src/lib/game.ts`), never `image/svg+xml`;
- validates the real MIME type **and** the file-name extension, rejecting mismatches
  (`evil.svg` labelled `image/png`, or an SVG renamed to `.png`);
- sends an explicit `contentType` from that allowlist to Storage (not the raw browser
  value) and stores the file under the canonical extension for that type;
- caps the file at `MAX_SPRITE_BYTES` (2 MB) and rejects `sprite_url` values ending in
  `.svg`, since the field is a plain form value that can be posted directly.

**Recommended for production (outside this app's scope):** add the server-side
defence in depth on the bucket itself — set `allowed_mime_types` on `professor-sprites`
to the same raster list (plus a `file_size_limit`), and/or route uploads through an Edge
Function that sniffs the file's magic bytes. The checks above run in the browser, so they
stop the UI path but not a crafted request with a valid admin token.
