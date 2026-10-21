-- Profesor GO — local seed (docs/CONTRACTS.md §5). Idempotent.
-- Loaded by `supabase db reset`. LOCAL DEVELOPMENT ONLY: it creates demo users
-- with known passwords directly in auth.users.

-- ---------------------------------------------------------------------------
-- app_settings
-- ---------------------------------------------------------------------------
insert into public.app_settings (key, value) values
  ('encounter_expiration_seconds', '180'::jsonb),
  ('throw_bonus', '{"MISS": -1.0, "GOOD": 0.0, "GREAT": 0.10, "EXCELLENT": 0.20}'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---------------------------------------------------------------------------
-- professors (ten campus professors)
-- ---------------------------------------------------------------------------
insert into public.professors (id, name, display_name, description, rarity, base_capture_rate, active) values
  ('00000000-0000-4000-8000-000000000016', 'Henry Carvajal',    'Prof. Henry', 'Profesor de MAC, amable y buena onda con sus estudiantes.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000015', 'Felipe Grijalva',   'Prof. Felipe', 'Excoordinador de MAC y experto en Machine Learning. Está a cargo de las maestrías de Ciencia de Datos e IA. Su aire serio impone respeto, pero es buena gente.', 'EPIC', 0.40, true),
  ('00000000-0000-4000-8000-000000000014', 'Jose David Vega',   'Prof. Jose David', 'Enseña muy bien y sus materias son llevaderas. Es un profe muy buena onda, cercano y querido por sus estudiantes.', 'COMMON', 0.80, true),
  ('00000000-0000-4000-8000-000000000013', 'Ricardo Flores',    'Prof. Ricardo', 'Experto en Redes y nuestro advisor de CS. Sus exámenes son legendariamente difíciles, pero explica muy bien.', 'RARE', 0.60, true),
  ('00000000-0000-4000-8000-000000000012', 'Pavel Alba',        'Prof. Pavel',    'Experto en Inteligencia Artificial y el «papá de la carrera». Su oficina está en nuestro laboratorio; explica increíble y hace sus clases súper interactivas.', 'EPIC', 0.40, true),
  ('00000000-0000-4000-8000-000000000011', 'Noel Perez',        'Prof. Noel',     'Profesor cubano de Bases de Datos y Estructuras de Datos. Sus exámenes son retadores; enseña bien y anima a sus estudiantes a ser más sociables.', 'EPIC', 0.40, true),
  ('00000000-0000-4000-8000-000000000009', 'Daniel Riofrio',    'Prof. Daniel',  'Coordinador de MAC y CMP. «Todo es un experimento social». Uno de los profesores más poderosos e inteligentes del campus.', 'LEGENDARY', 0.25, true),
  ('00000000-0000-4000-8000-000000000010', 'Erick Ñauñay',      'Prof. Erick',   'Enseña mejor que nadie, pero sus pruebas son imposibles. Genio de Big Tech y Netflix; fundó su propia empresa y cae genial en clase.', 'LEGENDARY', 0.25, true),
  ('00000000-0000-4000-8000-000000000017', 'Diego Morales',    'Prof. Diego', 'Profesor de MAC. Es tan difícil encontrárselo que aquí aparece como raro. Cuando se deja ver, llega con buena onda.', 'RARE', 0.60, true),
  ('00000000-0000-4000-8000-000000000018', 'Roberto Andrade',  'Prof. Roberto', 'Profesor de CMP. Gentil, sencillo y muy buena gente con sus estudiantes.', 'COMMON', 0.80, true)
on conflict (id) do update set
  name              = excluded.name,
  display_name      = excluded.display_name,
  description       = excluded.description,
  rarity            = excluded.rarity,
  base_capture_rate = excluded.base_capture_rate,
  active            = excluded.active;

-- ---------------------------------------------------------------------------
-- nfc_tags: 01 Henry, 02 Felipe, 03 Jose David, 04 Ricardo, 05 Pavel,
-- 06 Noel, 07 Daniel, 08 Erick, 09 Diego, 10 Roberto
-- ---------------------------------------------------------------------------
insert into public.nfc_tags (professor_id, tag_identifier, active)
select
  ('00000000-0000-4000-8000-' || lpad(professor_number::text, 12, '0'))::uuid,
  'DEMO-TAG-' || lpad(tag_number::text, 2, '0'),
  true
from (values (1, 16), (2, 15), (3, 14), (4, 13), (5, 12), (6, 11), (7, 9), (8, 10), (9, 17), (10, 18))
  as roster(tag_number, professor_number)
on conflict (tag_identifier) do update set
  professor_id = excluded.professor_id,
  active       = excluded.active;

-- ---------------------------------------------------------------------------
-- demo users (local only). The on_auth_user_created trigger creates profiles.
--   admin@profesorgo.local  / admin12345   (role admin)
--   player@profesorgo.local / player12345  (role player)
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-4000-8000-000000000001',
    'authenticated', 'authenticated',
    'admin@profesorgo.local',
    extensions.crypt('admin12345', extensions.gen_salt('bf')),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"display_name": "Admin Demo"}'::jsonb,
    now(), now(),
    '', '', '', '', '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-4000-8000-000000000002',
    'authenticated', 'authenticated',
    'player@profesorgo.local',
    extensions.crypt('player12345', extensions.gen_salt('bf')),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"display_name": "Jugador Demo"}'::jsonb,
    now(), now(),
    '', '', '', '', '', '', '', ''
  )
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(),
  u.id,
  u.id::text,
  'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true, 'phone_verified', false),
  now(), now(), now()
from auth.users u
where u.email in ('admin@profesorgo.local', 'player@profesorgo.local')
on conflict (provider_id, provider) do nothing;

-- Profiles are created by the trigger with role 'player'; promote the admin.
update public.profiles
set role = 'admin'
where email = 'admin@profesorgo.local'
  and role <> 'admin';
