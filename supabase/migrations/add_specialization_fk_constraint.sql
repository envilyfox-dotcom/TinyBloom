-- Run after fix_specialty_id_matching.sql, and only once that file's final
-- diagnostic query returns zero rows.
--
-- Guarantees the "?" (Unassigned) group bug can't silently recur: any
-- future insert/update that sets specialist_profiles.specialization to
-- anything other than one of the exact 17 canonical names now fails loudly
-- at the database level instead of quietly leaving specialty_id null.
-- NULL itself is still allowed (profiles mid-registration).
alter table public.specialist_profiles
  add constraint specialist_profiles_specialization_fkey
  foreign key (specialization) references public.specialties(name);
