create or replace function public.workspace_owner()
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select member.owner_user_id
  from public.workspace_members as member
  where (
    member.role = 'admin'
    and member.owner_user_id = auth.uid()
  ) or (
    member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  )
  order by case when member.owner_user_id = auth.uid() and member.role = 'admin' then 0 else 1 end
  limit 1
$$;

create or replace function public.workspace_role()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select member.role
  from public.workspace_members as member
  where (
    member.role = 'admin'
    and member.owner_user_id = auth.uid()
  ) or (
    member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  )
  order by case when member.owner_user_id = auth.uid() and member.role = 'admin' then 0 else 1 end
  limit 1
$$;

create or replace function public.is_workspace_admin(p_owner_user_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.workspace_members as member
    where member.owner_user_id = p_owner_user_id
      and member.owner_user_id = auth.uid()
      and member.role = 'admin'
  )
$$;

create or replace function public.get_workspace_access()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'role', member.role,
    'owner_id', member.owner_user_id
  )
  from public.workspace_members as member
  where (
    member.role = 'admin'
    and member.owner_user_id = auth.uid()
  ) or (
    member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  )
  order by case when member.owner_user_id = auth.uid() and member.role = 'admin' then 0 else 1 end
  limit 1
$$;

drop policy if exists "Members can read their workspace membership"
on public.workspace_members;

create policy "Members can read their workspace membership"
on public.workspace_members for select
to authenticated
using (
  email = lower(btrim(coalesce((select auth.jwt()) ->> 'email', '')))
  or owner_user_id = (select auth.uid())
);
