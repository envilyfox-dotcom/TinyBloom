-- Run in the Supabase SQL editor, after add_review_groups_schema.sql and
-- seed_review_groups.sql.
--
-- Diagnosed via the query at the bottom of this file's previous draft.
-- Live data had more spelling/format variants of the 17 canonical
-- specialties than expected (British spellings, missing punctuation,
-- lowercase, etc.) — none from the website's dropdown going forward, but
-- pre-existing rows need a one-time correction. Once this file's final
-- diagnostic returns zero rows, add_specialization_fk_constraint.sql is
-- safe to run.

-- Spelling/format variants -> canonical name:
update public.specialist_profiles
set specialization = 'OB/GYN'
where specialization in
  ('Obstetrician & Gynecologist', 'Obstetrician', 'Gynecologist',
   'obstetrician', 'Gynaecologist');

update public.specialist_profiles
set specialization = 'Lactation Consultant (IBCLC)'
where specialization = 'Lactation Consultant';

update public.specialist_profiles
set specialization = 'Dietitian/Nutritionist'
where specialization = 'Dietitian';

update public.specialist_profiles
set specialization = 'Midwife (CNM)'
where specialization = 'Midwife';

update public.specialist_profiles
set specialization = 'Psychiatrist/Psychologist (perinatal)'
where specialization = 'Perinatal Mental Health Specialist';

update public.specialist_profiles
set specialization = 'Maternal-Fetal Medicine (Perinatologist)'
where specialization = 'Maternal Fetal Medicine Specialist';

update public.specialist_profiles
set specialization = 'Pediatrician'
where specialization = 'Paediatrician';

-- Confirmed via user decision: "Physiotherapist" accounts are Pelvic Floor
-- PT (Group 5), just written differently.
update public.specialist_profiles
set specialization = 'Pelvic Floor PT'
where specialization = 'Physiotherapist';

-- "Prenatal Yoga Specialist" was a test account with no real dependent
-- data, so it's deleted outright rather than reassigned. Nothing else in
-- the schema has a FK pointing at specialist_profiles itself (approvals,
-- consultations, etc. reference profiles(id)/auth.users(id) directly), so
-- this can't cascade-break anything else. This only removes the specialist
-- profile row — if you also want the underlying auth account/login gone,
-- that's a separate step via the Supabase Auth dashboard/Admin API, not
-- plain SQL.
delete from public.specialist_profiles
where specialization = 'Prenatal Yoga Specialist';

-- Strict exact match — the website dropdown is fixed, so no lenient
-- trim/casing matching is needed here.
create or replace function public.sync_specialist_specialty_id()
returns trigger
language plpgsql
as $$
begin
  if new.specialization is distinct from old.specialization then
    select id into new.specialty_id
    from public.specialties
    where name = new.specialization;
  end if;
  return new;
end;
$$;

-- Re-resolve every existing row so anything fixed above (or missed by an
-- earlier one-time backfill) gets its specialty_id populated now.
update public.specialist_profiles sp
set specialty_id = s.id
from public.specialties s
where sp.specialization = s.name
  and sp.specialty_id is distinct from s.id;

-- Diagnostic: should return zero rows now. If anything shows up, it's a
-- new, unaccounted-for mismatch and needs the same treatment as the
-- corrections above before add_specialization_fk_constraint.sql can be run
-- safely.
select sp.user_id, sp.specialization
from public.specialist_profiles sp
where sp.specialization is not null
  and sp.specialization not in (select name from public.specialties);
