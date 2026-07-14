-- Run in the Supabase SQL editor.
--
-- Adds a short, human-readable, globally unique sequence number to each
-- volunteer_services row so it can be displayed as "VOL-Session(00001)"
-- alongside the title, instead of the raw UUID id.

alter table public.volunteer_services
  add column if not exists service_number bigint;

-- Backfill existing rows in creation order.
with numbered as (
  select id, row_number() over (order by created_at) as rn
  from public.volunteer_services
  where service_number is null
)
update public.volunteer_services v
set service_number = numbered.rn
from numbered
where v.id = numbered.id;

create sequence if not exists volunteer_services_service_number_seq;
select setval(
  'volunteer_services_service_number_seq',
  coalesce((select max(service_number) from public.volunteer_services), 0)
);

alter table public.volunteer_services
  alter column service_number
  set default nextval('volunteer_services_service_number_seq');

alter table public.volunteer_services
  alter column service_number set not null;

alter table public.volunteer_services
  add constraint volunteer_services_service_number_key unique (service_number);
