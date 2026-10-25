-- Only the event owner's admin account can restart its own collection.
-- This is one transaction: a failed authorization leaves progress untouched.
create or replace function public.reset_my_profedex()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is distinct from '37b8f998-df0e-454e-bc4d-76714e0ad9dc'::uuid then
    raise exception 'reset_my_profedex: not authorized' using errcode = '42501';
  end if;

  -- Lock the owner's profile and verify the role stored on the server.
  perform 1 from public.profiles
    where id = v_user and role = 'admin'
    for update;
  if not found then
    raise exception 'reset_my_profedex: not authorized' using errcode = '42501';
  end if;

  delete from public.captures where user_id = v_user;
  delete from public.encounters where user_id = v_user;
  update public.profiles
    set collection_completed_at = null
    where id = v_user;
end;
$$;

revoke all on function public.reset_my_profedex() from public, anon, authenticated;
grant execute on function public.reset_my_profedex() to authenticated;
