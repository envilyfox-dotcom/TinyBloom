-- Run in the Supabase SQL editor.
--
-- specialist_profiles.available_hours (the "<days>\n<times>" summary string
-- read/written by SpecialistEditProfileScreen and SpecialistOnboardingScreen)
-- was never added via a tracked migration in this repo — it was created
-- directly in the dashboard on the original project. This makes it
-- idempotently present in any environment, since AuthProvider now reads it
-- to decide whether a specialist needs the new availability onboarding step.

alter table public.specialist_profiles
  add column if not exists available_hours text;
