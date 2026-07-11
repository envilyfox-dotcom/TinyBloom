-- Run in the Supabase SQL editor, after add_review_groups_schema.sql.
-- Seeds the 5 review groups, their member specialties (named to exactly
-- match the website's fixed specialization dropdown, verbatim), and the
-- primary -> secondary group fallback mapping from
-- Article_System_specialist.md §2. Also backfills
-- specialist_profiles.specialty_id for rows that already existed before the
-- specialist_profiles_sync_specialty_id trigger was created — every insert/
-- update from here on keeps specialty_id in sync automatically.

insert into public.review_groups (id, name) values
  (1, 'Core Obstetric & Birth Care'),
  (2, 'Fertility & Genetics'),
  (3, 'Medical Complications in Pregnancy'),
  (4, 'Newborn & Pediatric Care'),
  (5, 'Postpartum Recovery & Allied Health')
on conflict (id) do nothing;

insert into public.specialties (name) values
  ('OB/GYN'),
  ('Maternal-Fetal Medicine (Perinatologist)'),
  ('Midwife (CNM)'),
  ('Anesthesiologist'),
  ('Reproductive Endocrinologist (REI)'),
  ('Genetic Counselor'),
  ('Urologist/Andrologist'),
  ('Endocrinologist'),
  ('Cardiologist'),
  ('Nephrologist'),
  ('Hematologist'),
  ('Neonatologist'),
  ('Pediatrician'),
  ('Psychiatrist/Psychologist (perinatal)'),
  ('Pelvic Floor PT'),
  ('Lactation Consultant (IBCLC)'),
  ('Dietitian/Nutritionist')
on conflict (name) do nothing;

insert into public.specialty_group_map (specialty_id, group_id)
select s.id, g.group_id from public.specialties s
join (values
  ('OB/GYN', 1),
  ('Maternal-Fetal Medicine (Perinatologist)', 1),
  ('Midwife (CNM)', 1),
  ('Anesthesiologist', 1),
  ('Reproductive Endocrinologist (REI)', 2),
  ('Genetic Counselor', 2),
  ('Urologist/Andrologist', 2),
  ('Endocrinologist', 3),
  ('Cardiologist', 3),
  ('Nephrologist', 3),
  ('Hematologist', 3),
  ('Neonatologist', 4),
  ('Pediatrician', 4),
  ('Psychiatrist/Psychologist (perinatal)', 5),
  ('Pelvic Floor PT', 5),
  ('Lactation Consultant (IBCLC)', 5),
  ('Dietitian/Nutritionist', 5)
) as g(specialty_name, group_id) on g.specialty_name = s.name
on conflict (specialty_id, group_id) do nothing;

insert into public.group_secondary_map (primary_group_id, secondary_group_id)
values
  (1, 3), (1, 5),
  (2, 1),
  (3, 1),
  (4, 1), (4, 5),
  (5, 1), (5, 3)
on conflict (primary_group_id, secondary_group_id) do nothing;

-- Backfill pre-existing rows by exact match — specialization is a fixed
-- dropdown value (no typos/free text), so this is a straight equality join,
-- not fuzzy matching. Anything left null means that row's specialization
-- string doesn't exactly match one of the 17 names seeded above; check for
-- a spelling/casing mismatch between this list and the website's dropdown
-- if so.
update public.specialist_profiles sp
set specialty_id = s.id
from public.specialties s
where sp.specialty_id is null
  and sp.specialization = s.name;
