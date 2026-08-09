-- specialist_profiles.available_schedule stores per-weekday availability as
-- jsonb, e.g. {"Monday": {"start": 9, "end": 17, "allDay": false}}, replacing
-- the old flat available_hours/available_today model where one shared set of
-- times applied to every selected day. Read/written by
-- SpecialistOnboardingScreen and SpecialistEditProfileScreen via the shared
-- WeeklyAvailabilityPicker widget.

alter table public.specialist_profiles
  add column if not exists available_schedule jsonb;
