create or replace function public.restore_backup(p_backup jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_person_count integer := 0;
  v_event_count integer := 0;
  v_participation_count integer := 0;
begin
  if v_user_id is null or not public.is_workspace_admin(v_user_id) then
    raise insufficient_privilege using message = 'Admin access required';
  end if;
  if coalesce(p_backup ->> 'format', '') <> 'community-tracker-backup'
     or coalesce((p_backup ->> 'version')::integer, 0) <> 1 then
    raise invalid_parameter_value using message = 'Unsupported backup format';
  end if;
  if jsonb_typeof(p_backup -> 'persons') <> 'array'
     or jsonb_typeof(p_backup -> 'events') <> 'array'
     or jsonb_typeof(p_backup -> 'participations') <> 'array' then
    raise invalid_parameter_value using message = 'Backup sections must be arrays';
  end if;

  insert into public.persons (id, name, customer, customer_since, user_id, referred_by, customer_status)
  select row_data.id, row_data.name, coalesce(row_data.customer, false), row_data.customer_since,
         v_user_id, null,
         coalesce(nullif(row_data.customer_status, ''), case when coalesce(row_data.customer, false) then 'before_event' else 'none' end)
  from jsonb_to_recordset(p_backup -> 'persons') as row_data(id uuid, name text, customer boolean, customer_since date, referred_by uuid, customer_status text)
  where row_data.id is not null
    and nullif(btrim(row_data.name), '') is not null
    and coalesce(nullif(row_data.customer_status, ''), case when coalesce(row_data.customer, false) then 'before_event' else 'none' end) in ('none', 'before_event', 'through_event')
  on conflict (id) do update
  set name = excluded.name, customer = excluded.customer, customer_since = excluded.customer_since, customer_status = excluded.customer_status
  where public.persons.user_id = v_user_id;
  get diagnostics v_person_count = row_count;

  update public.persons as person
  set referred_by = source.referred_by
  from jsonb_to_recordset(p_backup -> 'persons') as source(id uuid, referred_by uuid)
  where person.id = source.id and person.user_id = v_user_id
    and (source.referred_by is null or exists (select 1 from public.persons as referrer where referrer.id = source.referred_by and referrer.user_id = v_user_id));

  insert into public.events (id, title, event_date, notes, created_at, user_id, description, start_time, end_time, location, max_participants, updated_at, status)
  select row_data.id, row_data.title, row_data.event_date, row_data.notes, row_data.created_at, v_user_id, row_data.description, row_data.start_time, row_data.end_time, row_data.location, row_data.max_participants, row_data.updated_at, coalesce(row_data.status, 'Geplant')
  from jsonb_to_recordset(p_backup -> 'events') as row_data(id uuid, title text, event_date date, notes text, created_at timestamptz, description text, start_time time, end_time time, location text, max_participants integer, updated_at timestamptz, status text)
  where row_data.id is not null and nullif(btrim(row_data.title), '') is not null and row_data.event_date is not null
  on conflict (id) do update
  set title = excluded.title, event_date = excluded.event_date, notes = excluded.notes, description = excluded.description, start_time = excluded.start_time, end_time = excluded.end_time, location = excluded.location, max_participants = excluded.max_participants, updated_at = excluded.updated_at, status = excluded.status
  where public.events.user_id = v_user_id;
  get diagnostics v_event_count = row_count;

  insert into public.participations (id, event_id, person_id, invited, response, attended, brought_by, created_at)
  select row_data.id, row_data.event_id, row_data.person_id, coalesce(row_data.invited, true), coalesce(row_data.response, 'none'), coalesce(row_data.attended, false), row_data.brought_by, row_data.created_at
  from jsonb_to_recordset(p_backup -> 'participations') as row_data(id uuid, event_id uuid, person_id uuid, invited boolean, response text, attended boolean, brought_by uuid, created_at timestamptz)
  where row_data.id is not null
    and exists (select 1 from public.events as event where event.id = row_data.event_id and event.user_id = v_user_id)
    and exists (select 1 from public.persons as person where person.id = row_data.person_id and person.user_id = v_user_id)
    and (row_data.brought_by is null or exists (select 1 from public.persons as referrer where referrer.id = row_data.brought_by and referrer.user_id = v_user_id))
  on conflict (id) do update
  set event_id = excluded.event_id, person_id = excluded.person_id, invited = excluded.invited, response = excluded.response, attended = excluded.attended, brought_by = excluded.brought_by
  where exists (select 1 from public.events as event where event.id = public.participations.event_id and event.user_id = v_user_id);
  get diagnostics v_participation_count = row_count;

  return jsonb_build_object('persons', v_person_count, 'events', v_event_count, 'participations', v_participation_count);
end;
$$;
