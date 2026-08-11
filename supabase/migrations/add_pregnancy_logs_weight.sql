-- Lets a mum record her weight on each log entry, in addition to the
-- pregnancy_profiles.weight_kg snapshot shown on her profile.
alter table public.pregnancy_logs
  add column if not exists weight_kg numeric;
