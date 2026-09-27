create table public.workspace_members (
  email text primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'viewer')),
  created_at timestamptz not null default now(),
  check (email = lower(btrim(email)))
);

create index workspace_members_owner_idx
on public.workspace_members (owner_user_id);

alter table public.workspace_members enable row level security;

insert into public.workspace_members (email, owner_user_id, role)
select lower(btrim(u.email)), u.id, 'admin'
from auth.users as u
where u.email is not null
  and (
    exists (select 1 from public.persons as p where p.user_id = u.id)
    or exists (select 1 from public.events as e where e.user_id = u.id)
  )
on conflict (email) do nothing;

create or replace function public.workspace_owner()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select member.owner_user_id
  from public.workspace_members as member
  where member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  limit 1
$$;

create or replace function public.workspace_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select member.role
  from public.workspace_members as member
  where member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  limit 1
$$;

create or replace function public.is_workspace_admin(p_owner_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workspace_members as member
    where member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
      and member.owner_user_id = p_owner_user_id
      and member.role = 'admin'
  )
$$;

create or replace function public.get_workspace_access()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'role', member.role,
    'owner_id', member.owner_user_id
  )
  from public.workspace_members as member
  where member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  limit 1
$$;

create or replace function public.add_workspace_viewer(p_email text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, ''));
  v_existing public.workspace_members%rowtype;
begin
  if auth.uid() is null
     or public.workspace_owner() is distinct from auth.uid()
     or not public.is_workspace_admin(auth.uid()) then
    raise insufficient_privilege using message = 'Admin access required';
  end if;

  if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise invalid_parameter_value using message = 'Invalid email address';
  end if;

  select * into v_existing
  from public.workspace_members
  where email = v_email;

  if found and v_existing.owner_user_id is distinct from auth.uid() then
    raise unique_violation using message = 'Email already belongs to another workspace';
  end if;

  if found and v_existing.role = 'admin' then
    return false;
  end if;

  insert into public.workspace_members (email, owner_user_id, role)
  values (v_email, auth.uid(), 'viewer')
  on conflict (email) do update
  set role = 'viewer'
  where public.workspace_members.owner_user_id = excluded.owner_user_id;

  return true;
end;
$$;

create or replace function public.remove_workspace_viewer(p_email text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or public.workspace_owner() is distinct from auth.uid()
     or not public.is_workspace_admin(auth.uid()) then
    raise insufficient_privilege using message = 'Admin access required';
  end if;

  delete from public.workspace_members
  where email = lower(btrim(coalesce(p_email, '')))
    and owner_user_id = auth.uid()
    and role = 'viewer';

  return found;
end;
$$;

revoke all on table public.workspace_members from anon;
revoke all on table public.workspace_members from authenticated;
grant select on table public.workspace_members to authenticated;

create policy "Members can read their workspace membership"
on public.workspace_members for select
to authenticated
using (
  email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
  or owner_user_id = (select auth.uid())
);

revoke all on function public.workspace_owner() from public, anon;
revoke all on function public.workspace_role() from public, anon;
revoke all on function public.is_workspace_admin(uuid) from public, anon;
revoke all on function public.get_workspace_access() from public, anon;
revoke all on function public.add_workspace_viewer(text) from public, anon;
revoke all on function public.remove_workspace_viewer(text) from public, anon;
grant execute on function public.workspace_owner() to authenticated;
grant execute on function public.workspace_role() to authenticated;
grant execute on function public.is_workspace_admin(uuid) to authenticated;
grant execute on function public.get_workspace_access() to authenticated;
grant execute on function public.add_workspace_viewer(text) to authenticated;
grant execute on function public.remove_workspace_viewer(text) to authenticated;

drop policy if exists "authenticated can read persons" on public.persons;
drop policy if exists "authenticated can insert persons" on public.persons;
drop policy if exists "authenticated can update persons" on public.persons;
drop policy if exists "authenticated can delete persons" on public.persons;

create policy "Workspace members can read persons"
on public.persons for select to authenticated
using (user_id = public.workspace_owner());

create policy "Workspace admins can insert persons"
on public.persons for insert to authenticated
with check (user_id = (select auth.uid()) and public.is_workspace_admin(user_id));

create policy "Workspace admins can update persons"
on public.persons for update to authenticated
using (user_id = (select auth.uid()) and public.is_workspace_admin(user_id))
with check (user_id = (select auth.uid()) and public.is_workspace_admin(user_id));

create policy "Workspace admins can delete persons"
on public.persons for delete to authenticated
using (user_id = (select auth.uid()) and public.is_workspace_admin(user_id));

drop policy if exists "authenticated can read events" on public.events;
drop policy if exists "authenticated can insert events" on public.events;
drop policy if exists "Users can insert own events" on public.events;
drop policy if exists "authenticated can update events" on public.events;
drop policy if exists "authenticated can delete events" on public.events;

create policy "Workspace members can read events"
on public.events for select to authenticated
using (user_id = public.workspace_owner());

create policy "Workspace admins can insert events"
on public.events for insert to authenticated
with check (user_id = (select auth.uid()) and public.is_workspace_admin(user_id));

create policy "Workspace admins can update events"
on public.events for update to authenticated
using (user_id = (select auth.uid()) and public.is_workspace_admin(user_id))
with check (user_id = (select auth.uid()) and public.is_workspace_admin(user_id));

create policy "Workspace admins can delete events"
on public.events for delete to authenticated
using (user_id = (select auth.uid()) and public.is_workspace_admin(user_id));

drop policy if exists "Owners can read participations" on public.participations;
drop policy if exists "Owners can add participations" on public.participations;
drop policy if exists "Owners can update participations" on public.participations;
drop policy if exists "Owners can delete participations" on public.participations;

create policy "Workspace members can read participations"
on public.participations for select to authenticated
using (exists (
  select 1 from public.events as event
  where event.id = participations.event_id
    and event.user_id = public.workspace_owner()
));

create policy "Workspace admins can insert participations"
on public.participations for insert to authenticated
with check (
  exists (
    select 1 from public.events as event
    where event.id = participations.event_id
      and event.user_id = (select auth.uid())
      and public.is_workspace_admin(event.user_id)
  )
  and exists (
    select 1 from public.persons as person
    where person.id = participations.person_id
      and person.user_id = (select auth.uid())
  )
  and (
    brought_by is null
    or exists (
      select 1 from public.persons as referrer
      where referrer.id = participations.brought_by
        and referrer.user_id = (select auth.uid())
    )
  )
);

create policy "Workspace admins can update participations"
on public.participations for update to authenticated
using (exists (
  select 1 from public.events as event
  where event.id = participations.event_id
    and event.user_id = (select auth.uid())
    and public.is_workspace_admin(event.user_id)
))
with check (
  exists (
    select 1 from public.events as event
    where event.id = participations.event_id
      and event.user_id = (select auth.uid())
      and public.is_workspace_admin(event.user_id)
  )
  and exists (
    select 1 from public.persons as person
    where person.id = participations.person_id
      and person.user_id = (select auth.uid())
  )
  and (
    brought_by is null
    or exists (
      select 1 from public.persons as referrer
      where referrer.id = participations.brought_by
        and referrer.user_id = (select auth.uid())
    )
  )
);

create policy "Workspace admins can delete participations"
on public.participations for delete to authenticated
using (exists (
  select 1 from public.events as event
  where event.id = participations.event_id
    and event.user_id = (select auth.uid())
    and public.is_workspace_admin(event.user_id)
));

drop policy if exists "Users can view event participants" on public.event_participants;
drop policy if exists "Users can insert event participants" on public.event_participants;
drop policy if exists "Users can update event participants" on public.event_participants;
drop policy if exists "Users can delete event participants" on public.event_participants;

create policy "Workspace members can read legacy participants"
on public.event_participants for select to authenticated
using (exists (
  select 1 from public.events as event
  where event.id = event_participants.event_id
    and event.user_id = public.workspace_owner()
));

create policy "Workspace admins can insert legacy participants"
on public.event_participants for insert to authenticated
with check (exists (
  select 1 from public.events as event
  where event.id = event_participants.event_id
    and event.user_id = (select auth.uid())
    and public.is_workspace_admin(event.user_id)
));

create policy "Workspace admins can update legacy participants"
on public.event_participants for update to authenticated
using (exists (
  select 1 from public.events as event
  where event.id = event_participants.event_id
    and event.user_id = (select auth.uid())
    and public.is_workspace_admin(event.user_id)
))
with check (exists (
  select 1 from public.events as event
  where event.id = event_participants.event_id
    and event.user_id = (select auth.uid())
    and public.is_workspace_admin(event.user_id)
));

create policy "Workspace admins can delete legacy participants"
on public.event_participants for delete to authenticated
using (exists (
  select 1 from public.events as event
  where event.id = event_participants.event_id
    and event.user_id = (select auth.uid())
    and public.is_workspace_admin(event.user_id)
));

revoke all on table public.persons, public.events, public.participations, public.event_participants from anon;
revoke truncate on table public.persons, public.events, public.participations, public.event_participants from authenticated;
grant select, insert, update, delete on table public.persons, public.events, public.participations, public.event_participants to authenticated;
