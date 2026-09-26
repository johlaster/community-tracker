create or replace function public.delete_person(p_person_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise insufficient_privilege using message = 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.persons
    where id = p_person_id and user_id = v_user_id
  ) then
    return false;
  end if;

  update public.persons
  set referred_by = null
  where referred_by = p_person_id and user_id = v_user_id;

  update public.participations as participation
  set brought_by = null
  where brought_by = p_person_id
    and exists (
      select 1
      from public.events as event
      where event.id = participation.event_id
        and event.user_id = v_user_id
    );

  delete from public.persons
  where id = p_person_id and user_id = v_user_id;

  return found;
end;
$$;

create or replace function public.delete_event(p_event_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise insufficient_privilege using message = 'Authentication required';
  end if;

  delete from public.events
  where id = p_event_id and user_id = v_user_id;

  return found;
end;
$$;

revoke all on function public.delete_person(uuid) from public;
revoke all on function public.delete_person(uuid) from anon;
grant execute on function public.delete_person(uuid) to authenticated;

revoke all on function public.delete_event(uuid) from public;
revoke all on function public.delete_event(uuid) from anon;
grant execute on function public.delete_event(uuid) to authenticated;
