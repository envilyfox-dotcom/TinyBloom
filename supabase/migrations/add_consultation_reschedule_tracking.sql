-- Run in the Supabase SQL editor.
--
-- Rescheduling (see SupabaseService.rescheduleConsultation) overwrites
-- scheduled_date/scheduled_time in place, so without these the specialist
-- has no way to see what the appointment's previous slot was. These columns
-- capture the pre-reschedule value so the "Consultation reschedule
-- reminder" notification (buildSpecialistNotifications) can say "from X to
-- Y", and rescheduled_at/previous_scheduled_date double as the marker that
-- distinguishes a rescheduled-and-awaiting-re-approval consultation from an
-- ordinary new 'pending' booking, for the specialist-side "!" badge.
alter table public.consultations
  add column if not exists previous_scheduled_date date,
  add column if not exists previous_scheduled_time text,
  add column if not exists rescheduled_at timestamptz;
