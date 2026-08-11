-- Run in the Supabase SQL editor.
-- Safe to re-run.
--
-- The seed data in add_mood_options_and_learn_tags.sql was a guess (no
-- access to the live database at the time) and didn't match the tags
-- actually in use across your articles. This replaces it with the real
-- list, which is what the specialist Create/Edit Article tag picker used
-- to show before it was switched from deriving tags live off `articles`
-- to reading the admin-managed `learn_tags` table.

delete from public.learn_tags
where label in ('Pregnancy', 'Wellness', 'Fitness', 'General');

insert into public.learn_tags (label, sort_order) values
  ('Antenatal Care', 0),
  ('Antenatal Check', 1),
  ('Baby Development', 2),
  ('Exercise', 3),
  ('First Trimester', 4),
  ('Healthy Habits', 5),
  ('Labour & Delivery', 6),
  ('Lifestyle', 7),
  ('Mental Health', 8),
  ('Nutrition', 9),
  ('Postpartum', 10),
  ('Pregnancy Conditions', 11),
  ('Pregnancy Lifestyle', 12),
  ('Second Trimester', 13),
  ('Third Trimester', 14),
  ('Wellbeing', 15)
on conflict (label) do update set sort_order = excluded.sort_order;
