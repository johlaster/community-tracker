alter table public.potential_contacts
  add column if not exists ready_via_event_contact boolean not null default false,
  add column if not exists ready_via_event_contact_at timestamptz null;
