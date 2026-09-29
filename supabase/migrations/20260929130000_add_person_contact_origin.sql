alter table public.persons
  add column if not exists contact_origin text not null default 'unknown';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'persons_contact_origin_check'
      and conrelid = 'public.persons'::regclass
  ) then
    alter table public.persons
      add constraint persons_contact_origin_check
      check (contact_origin = any (array['unknown'::text, 'existing'::text, 'through_event'::text]));
  end if;
end $$;
