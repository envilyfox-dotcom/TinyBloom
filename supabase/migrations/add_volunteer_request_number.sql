-- Run in the Supabase SQL editor.
--
-- Adds a short, human-readable, globally unique sequence number to each
-- volunteer_requests row so it can be displayed as "VOL-00001" the same way
-- volunteer_services.service_number is (see add_volunteer_service_number.sql)
-- instead of the old hash-derived "Appointment ID"/"Request ID" that was
-- computed client-side from the row's UUID and never actually guaranteed
-- unique or sequential.

alter table public.volunteer_requests
  add column if not exists request_number bigint;

-- Backfill existing rows in creation order.
with numbered as (
  select id, row_number() over (order by created_at) as rn
  from public.volunteer_requests
  where request_number is null
)
update public.volunteer_requests v
set request_number = numbered.rn
from numbered
where v.id = numbered.id;

create sequence if not exists volunteer_requests_request_number_seq;
select setval(
  'volunteer_requests_request_number_seq',
  coalesce((select max(request_number) from public.volunteer_requests), 0)
);

alter table public.volunteer_requests
  alter column request_number
  set default nextval('volunteer_requests_request_number_seq');

alter table public.volunteer_requests
  alter column request_number set not null;

alter table public.volunteer_requests
  add constraint volunteer_requests_request_number_key unique (request_number);
