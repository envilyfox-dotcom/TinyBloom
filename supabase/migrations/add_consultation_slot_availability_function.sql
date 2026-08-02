-- Run in the Supabase SQL editor.
--
-- consultations' SELECT policy only allows a row to be read by
-- patient_id = auth.uid() OR specialist_id = auth.uid() (see
-- add_next_of_kin_consultations_select_policy.sql). That's correct for
-- protecting booking details, but it means ConsultationBookingScreen's
-- "which times are already taken" query silently gets zero rows back for
-- slots held by OTHER patients -- RLS filters them out rather than erroring.
-- The screen then renders that slot as pickable, and the user only finds out
-- it's taken when the consultations_specialist_slot_unique index rejects the
-- insert (see add_consultation_booking_uniqueness.sql). Two premium users can
-- race for the same slot and only the DB constraint -- not the UI -- catches
-- it.
--
-- This adds a SECURITY DEFINER function that returns *only* the taken time
-- strings for a specialist/date, with no patient identity, purpose, or other
-- booking detail -- safe to expose to any authenticated user regardless of
-- the base table's row-level restrictions, so the picker can actually hide
-- these slots instead of just erroring on submit.

create or replace function public.get_booked_consultation_slots(
  p_specialist_ids uuid[],
  p_date date
)
returns table (scheduled_time text)
language sql
security definer
set search_path = public
stable
as $$
  select c.scheduled_time
  from public.consultations c
  where c.specialist_id = any(p_specialist_ids)
    and c.scheduled_date = p_date
    and c.status in ('pending', 'confirmed');
$$;

revoke all on function public.get_booked_consultation_slots(uuid[], date) from public;
grant execute on function public.get_booked_consultation_slots(uuid[], date) to authenticated;
