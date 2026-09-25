-- Give signed-in users access only to participation rows from their own events.
grant select, insert, update, delete on table public.participations to authenticated;
revoke all on table public.participations from anon;

create policy "Owners can read participations"
on public.participations for select to authenticated
using (exists (
  select 1 from public.events e
  where e.id = participations.event_id and e.user_id = (select auth.uid())
));

create policy "Owners can add participations"
on public.participations for insert to authenticated
with check (
  exists (select 1 from public.events e
    where e.id = participations.event_id and e.user_id = (select auth.uid()))
  and exists (select 1 from public.persons p
    where p.id = participations.person_id and p.user_id = (select auth.uid()))
  and (brought_by is null or exists (select 1 from public.persons p
    where p.id = participations.brought_by and p.user_id = (select auth.uid())))
);

create policy "Owners can update participations"
on public.participations for update to authenticated
using (exists (
  select 1 from public.events e
  where e.id = participations.event_id and e.user_id = (select auth.uid())
))
with check (
  exists (select 1 from public.events e
    where e.id = participations.event_id and e.user_id = (select auth.uid()))
  and exists (select 1 from public.persons p
    where p.id = participations.person_id and p.user_id = (select auth.uid()))
  and (brought_by is null or exists (select 1 from public.persons p
    where p.id = participations.brought_by and p.user_id = (select auth.uid())))
);

create policy "Owners can delete participations"
on public.participations for delete to authenticated
using (exists (
  select 1 from public.events e
  where e.id = participations.event_id and e.user_id = (select auth.uid())
));

-- Preserve the participant selections made in the older tracker.
insert into public.participations (event_id, person_id, invited, response, attended)
select ep.event_id, ep.person_id, true, 'yes', false
from public.event_participants ep
where not exists (
  select 1 from public.participations p
  where p.event_id = ep.event_id and p.person_id = ep.person_id
);
