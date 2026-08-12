-- Adds a short, human-readable, globally unique sequence number to each
-- volunteer_services row so it can be displayed as "VOL-Session(00001)"
-- alongside the title, instead of the raw UUID id.

alter table public.volunteer_services
  add column if not exists service_number bigint;

-- backfill existing rows in creation order
with numbered as (
  select id, row_number() over (order by created_at) as rn
  from public.volunteer_services
  where service_number is null
)
update public.volunteer_services v
set service_number = numbered.rn
from numbered
where v.id = numbered.id;

-- sequence to hand out numbers for new rows, picking up after the backfill
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

-- guarantees no two services can end up with the same displayed number
alter table public.volunteer_services
  add constraint volunteer_services_service_number_key unique (service_number);
