-- Run in the Supabase SQL editor, after add_article_tags.sql.
-- The tag picker/filter had accumulated a long tail of overly granular or
-- one-off tags (hospital names, lab-test names, single clinical terms) that
-- cluttered the Create Article tag picker and the Learn tab filter, plus
-- duplicate "Trimester N" variants of the canonical "Nth Trimester" tags.
-- This is a one-off data cleanup — nothing here needs to run again.

-- 1. Consolidate "Trimester 1/2/3" into the canonical "1st/2nd/3rd Trimester"
--    tags (de-duping if an article already carries both forms).
update public.articles
set tags = array(
  select distinct case t
    when 'Trimester 1' then '1st Trimester'
    when 'Trimester 2' then '2nd Trimester'
    when 'Trimester 3' then '3rd Trimester'
    else t
  end
  from unnest(tags) t
)
where tags && array['Trimester 1', 'Trimester 2', 'Trimester 3'];

-- 2. Strip out the noisy/overly granular tags entirely. Case-sensitive —
--    'antenatal care' here is the lowercase variant specifically.
update public.articles
set tags = (
  select coalesce(array_agg(t), '{}')
  from unnest(tags) t
  where t not in (
    'Weight', 'Week by Week', 'Urine Test', 'Screening', 'Pregnancy',
    'Gestational Diabetes', 'Folic Acid', 'Folate', 'Foetal Heart Rate',
    'Antenatal Depression', 'Check', 'Visits', 'SingHealth', 'NUH', 'KKH',
    'HealthHub', 'GDM', 'antenatal care', 'BMI'
  )
)
where tags && array[
  'Weight', 'Week by Week', 'Urine Test', 'Screening', 'Pregnancy',
  'Gestational Diabetes', 'Folic Acid', 'Folate', 'Foetal Heart Rate',
  'Antenatal Depression', 'Check', 'Visits', 'SingHealth', 'NUH', 'KKH',
  'HealthHub', 'GDM', 'antenatal care', 'BMI'
];

-- 3. `category` (still read directly by baby_development_screen/
--    features_screens for keyword matching) falls back to another
--    remaining tag, or 'General', if it was one of the removed values.
update public.articles
set category = coalesce(
  (select t from unnest(tags) t
   where t not in ('1st Trimester', '2nd Trimester', '3rd Trimester')
   limit 1),
  'General'
)
where category in (
  'Weight', 'Week by Week', 'Urine Test', 'Screening', 'Pregnancy',
  'Gestational Diabetes', 'Folic Acid', 'Folate', 'Foetal Heart Rate',
  'Antenatal Depression', 'Check', 'Visits', 'SingHealth', 'NUH', 'KKH',
  'HealthHub', 'GDM', 'antenatal care', 'BMI'
);
