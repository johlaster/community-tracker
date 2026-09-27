alter table public.persons
  add column customer_status text not null default 'none';

update public.persons
set customer_status = case when customer then 'before_event' else 'none' end
where customer_status = 'none';

alter table public.persons
  add constraint persons_customer_status_check
  check (customer_status in ('none', 'before_event', 'through_event'));

create index persons_customer_status_owner_idx
on public.persons (customer_status, user_id);
