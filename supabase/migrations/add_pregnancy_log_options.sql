-- Run in the Supabase SQL editor.
--
-- The Symptoms & Milestones chip options on CreateLogScreen were hardcoded
-- in the Flutter app (_allSymptoms/_allMilestones). Moves them into a table
-- so they can be added/renamed/reordered/removed directly from the Table
-- Editor instead of requiring an app release.

-- new table to hold the symptom/milestone chip choices
create table public.pregnancy_log_options (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('symptom', 'milestone')),
  label text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (category, label)
);

-- turn on RLS so the read policy below actually applies
alter table public.pregnancy_log_options enable row level security;

-- Read-only from the app; edits happen via the Supabase dashboard (which
-- uses the postgres role and bypasses RLS), so no insert/update/delete
-- policy is needed here.
create policy "Anyone can view pregnancy log options"
on public.pregnancy_log_options
for select
to authenticated
using (true);

-- seed the initial symptom and milestone options
insert into public.pregnancy_log_options (category, label, sort_order) values
  ('symptom', 'Morning sickness', 0),
  ('symptom', 'Nausea', 1),
  ('symptom', 'Vomiting', 2),
  ('symptom', 'Fatigue', 3),
  ('symptom', 'Headache', 4),
  ('symptom', 'Back pain', 5),
  ('symptom', 'Pelvic pain', 6),
  ('symptom', 'Round ligament pain', 7),
  ('symptom', 'Leg cramps', 8),
  ('symptom', 'Swollen feet', 9),
  ('symptom', 'Swollen hands', 10),
  ('symptom', 'Heartburn', 11),
  ('symptom', 'Indigestion', 12),
  ('symptom', 'Constipation', 13),
  ('symptom', 'Diarrhoea', 14),
  ('symptom', 'Bloating', 15),
  ('symptom', 'Frequent urination', 16),
  ('symptom', 'Breast tenderness', 17),
  ('symptom', 'Braxton Hicks contractions', 18),
  ('symptom', 'Baby kicking', 19),
  ('symptom', 'Reduced baby movement', 20),
  ('symptom', 'Dizziness', 21),
  ('symptom', 'Shortness of breath', 22),
  ('symptom', 'Nasal congestion', 23),
  ('symptom', 'Insomnia', 24),
  ('symptom', 'Mood swings', 25),
  ('symptom', 'Food cravings', 26),
  ('symptom', 'Food aversions', 27),
  ('symptom', 'Acne', 28),
  ('symptom', 'Stretch marks', 29),
  ('symptom', 'Itchy skin', 30),
  ('symptom', 'Bleeding gums', 31),
  ('symptom', 'Varicose veins', 32),
  ('symptom', 'Haemorrhoids', 33),
  ('symptom', 'Vaginal discharge', 34),
  ('symptom', 'Water retention', 35),
  ('symptom', 'Hot flashes', 36),
  ('symptom', 'Chills', 37),
  ('symptom', 'Fever', 38),
  ('symptom', 'No symptoms', 39),
  ('milestone', 'Positive pregnancy test', 0),
  ('milestone', 'Heartbeat detected', 1),
  ('milestone', 'First ultrasound', 2),
  ('milestone', 'Dating scan', 3),
  ('milestone', 'NT scan', 4),
  ('milestone', 'NIPT completed', 5),
  ('milestone', 'Baby heartbeat heard', 6),
  ('milestone', 'Baby started moving', 7),
  ('milestone', 'First kick felt', 8),
  ('milestone', 'Partner felt baby kick', 9),
  ('milestone', '20-week anatomy scan', 10),
  ('milestone', 'Baby responds to sound', 11),
  ('milestone', 'Gender revealed', 12),
  ('milestone', 'Baby hiccups', 13),
  ('milestone', 'Third trimester begins', 14),
  ('milestone', 'Hospital tour completed', 15),
  ('milestone', 'Birth plan completed', 16),
  ('milestone', 'Hospital bag packed', 17),
  ('milestone', 'Car seat installed', 18),
  ('milestone', 'Baby shower', 19),
  ('milestone', 'Nursery completed', 20),
  ('milestone', 'Maternity leave begins', 21),
  ('milestone', 'Breastfeeding class completed', 22),
  ('milestone', 'Parenting class completed', 23),
  ('milestone', 'Baby dropped', 24),
  ('milestone', 'Cervix dilating', 25),
  ('milestone', 'Labour contractions started', 26),
  ('milestone', 'Water broke', 27),
  ('milestone', 'Delivery day', 28),
  ('milestone', 'Baby born', 29),
  ('milestone', 'Skin-to-skin completed', 30),
  ('milestone', 'First breastfeed', 31),
  ('milestone', 'Discharged home', 32),
  ('milestone', 'First paediatric visit', 33),
  ('milestone', 'Postpartum check-up', 34);
