-- Run in the Supabase SQL editor (after add_consultation_booking_fields.sql).
-- Prevents a specialist/volunteer from being double-booked for the same
-- date + time slot -- by any patient, including the same one booking twice
-- (e.g. via the app's back button after a confirmed booking). Cancelled
-- bookings are excluded so a freed-up slot can be rebooked.

-- Existing data can already contain duplicates from before this constraint
-- existed (that's the exact bug this migration fixes). Resolve those first:
-- keep the earliest-created booking per slot active and cancel the rest,
-- or the unique index below will fail to create.
with ranked as (
  select id,
         row_number() over (
           partition by specialist_id, scheduled_date, scheduled_time
           order by created_at asc
         ) as rn
  from public.consultations
  where status <> 'cancelled'
)
update public.consultations c
set status = 'cancelled',
    cancellation_reason = 'Automatically cancelled: duplicate booking for the same slot'
from ranked
where c.id = ranked.id
  and ranked.rn > 1;

create unique index if not exists consultations_specialist_slot_unique
  on public.consultations (specialist_id, scheduled_date, scheduled_time)
  where status <> 'cancelled';
