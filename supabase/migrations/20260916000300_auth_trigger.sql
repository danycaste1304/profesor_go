-- Profesor GO — auth.users -> public.profiles trigger (docs/CONTRACTS.md §2)
-- Every new auth user gets a profile with role 'player'. display_name comes from the
-- signup metadata (raw_user_meta_data->>'display_name').

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    new.raw_user_meta_data ->> 'display_name',
    'player'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Trigger functions are only ever invoked by the auth service (supabase_auth_admin)
-- or by SQL seeds run as postgres.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
