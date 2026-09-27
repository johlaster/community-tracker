create or replace function public.create_workspace_for_current_user()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := lower(btrim(coalesce(auth.jwt() ->> 'email', '')));
begin
  if v_user_id is null or v_email = '' then
    raise insufficient_privilege using message = 'Authentication required';
  end if;
  if exists (select 1 from public.workspace_members where owner_user_id = v_user_id or email = v_email) then
    return public.get_workspace_access();
  end if;
  insert into public.workspace_members (email, owner_user_id, role)
  values (v_email, v_user_id, 'admin');
  return jsonb_build_object('role', 'admin', 'owner_id', v_user_id);
end;
$$;

create or replace function public.get_workspace_members()
returns table(email text, role text, created_at timestamptz, registered boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null or not public.is_workspace_admin(v_user_id) then
    raise insufficient_privilege using message = 'Admin access required';
  end if;
  return query
  select member.email, member.role, member.created_at,
         exists (select 1 from auth.users as account where lower(account.email) = member.email)
  from public.workspace_members as member
  where member.owner_user_id = v_user_id
  order by member.role, member.email;
end;
$$;

revoke all on function public.create_workspace_for_current_user() from public, anon;
revoke all on function public.get_workspace_members() from public, anon;
grant execute on function public.create_workspace_for_current_user() to authenticated;
grant execute on function public.get_workspace_members() to authenticated;
