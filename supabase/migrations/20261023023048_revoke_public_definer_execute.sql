-- RLS calls is_admin only for authenticated users. Anonymous clients do not
-- need the public RPC, and PUBLIC's default function EXECUTE must be removed.
revoke execute on function public.is_admin() from public, anon;

-- Supabase creates this event-trigger function when automatic RLS is enabled
-- during project creation. Its owner can still run the trigger without
-- exposing the function through the Data API. Local CLI databases may not
-- have it, so keep the migration portable.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;
