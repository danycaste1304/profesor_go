-- Keep production usable after `supabase db push`, which does not run seed.sql.
-- The local `supabase db reset` applies seed.sql after migrations, restoring
-- demo tags and accounts only for local development.
insert into public.app_settings (key, value) values
  ('encounter_expiration_seconds', '180'::jsonb),
  ('throw_bonus', '{"MISS": -1.0, "GOOD": 0.0, "GREAT": 0.10, "EXCELLENT": 0.20}'::jsonb)
on conflict (key) do nothing;

-- Earlier roster migrations used placeholder tags for local testing. Never
-- leave those guessable IDs active on a production database.
delete from public.nfc_tags
where tag_identifier ~ '^DEMO-TAG-(0[1-9]|10)$';

-- New Supabase projects can disable automatic Data API grants. Keep the
-- mobile app, admin panel, and service-role Edge Functions working with
-- explicit privileges. RLS remains the row-level authorization boundary.
revoke all on table
  public.profiles,
  public.professors,
  public.nfc_tags,
  public.encounters,
  public.captures,
  public.app_settings
from anon, authenticated;

grant select, update on table public.profiles to authenticated;
grant select, insert, update, delete on table
  public.professors,
  public.nfc_tags,
  public.app_settings
to authenticated;
grant select on table public.encounters, public.captures to authenticated;

grant select, insert, update, delete on table
  public.profiles,
  public.professors,
  public.nfc_tags,
  public.encounters,
  public.captures,
  public.app_settings
to service_role;
