-- Run in the Supabase SQL editor, after cleanup_noisy_article_tags.sql.
-- A second pass: a few more overly granular tags were still showing up
-- after that cleanup. Matched case-insensitively this time (via lower())
-- since the live data's actual casing didn't line up with the exact-case
-- list used in the first pass — this is why some survived it.

-- 1. Strip these tags out of every article's `tags` array, regardless of
--    which earlier article used them.
with removed(name) as (
  values
    ('weight'), ('trimester 1'), ('trimester 2'), ('trimester 3'),
    ('screening'), ('pregnancy'), ('healthy pregnancy'), ('folic acid'),
    ('gestational diabetes'), ('folate'), ('foetal heart rate'),
    ('blood pressure'), ('antenatal visits'), ('antenatal depression')
)
update public.articles
set tags = (
  select coalesce(array_agg(t), '{}')
  from unnest(tags) t
  where lower(t) not in (select name from removed)
)
where exists (
  select 1 from unnest(tags) t
  where lower(t) in (select name from removed)
);

-- 2. `category` (still read directly by baby_development_screen/
--    features_screens for keyword matching) falls back to another
--    remaining tag, or 'General', if it was one of the removed values.
with removed(name) as (
  values
    ('weight'), ('trimester 1'), ('trimester 2'), ('trimester 3'),
    ('screening'), ('pregnancy'), ('healthy pregnancy'), ('folic acid'),
    ('gestational diabetes'), ('folate'), ('foetal heart rate'),
    ('blood pressure'), ('antenatal visits'), ('antenatal depression')
)
update public.articles
set category = coalesce(
  (select t from unnest(tags) t
   where t not in ('1st Trimester', '2nd Trimester', '3rd Trimester')
   limit 1),
  'General'
)
where lower(category) in (select name from removed);
