alter table public.persons
  add column referred_by uuid;

alter table public.persons
  add constraint persons_id_user_id_unique unique (id, user_id);

alter table public.persons
  add constraint persons_referred_by_owner_fkey
  foreign key (referred_by, user_id)
  references public.persons (id, user_id);

alter table public.persons
  add constraint persons_not_referred_by_self
  check (referred_by is null or referred_by <> id);

drop policy if exists "authenticated can update persons" on public.persons;

create policy "authenticated can update persons"
on public.persons for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
