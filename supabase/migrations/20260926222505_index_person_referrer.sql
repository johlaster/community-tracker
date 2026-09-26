create index persons_referred_by_owner_idx
on public.persons (referred_by, user_id)
where referred_by is not null;
