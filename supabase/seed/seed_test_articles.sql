-- Run this in the Supabase SQL editor to seed a few test articles so you
-- can see them from a mum's account (Education tab, and Recommended
-- Articles on the Baby Development screen).
--
-- Run AFTER add_specialist_article_links.sql, since the last two rows use
-- the `url` column added by that migration.

insert into public.articles (title, slug, category, excerpt, content, status, published_at)
values
  (
    'Eating Healthy During Pregnancy',
    'eating-healthy-during-pregnancy',
    'Nutrition',
    'A quick guide to balanced meals and key nutrients for you and baby.',
    'During pregnancy, your body needs extra folate, iron, calcium and protein. '
    || 'Aim for a colourful plate with whole grains, lean protein, dairy, and plenty '
    || 'of fruits and vegetables. Stay hydrated and limit caffeine and processed sugar.',
    'published',
    now()
  ),
  (
    'Understanding Baby Kicks',
    'understanding-baby-kicks',
    'Pregnancy',
    'What baby''s movements can tell you at each stage.',
    'Most mums start feeling flutters around weeks 16–20, becoming stronger kicks '
    || 'by week 24. Tracking daily movement helps you notice your baby''s normal pattern '
    || '— and when to call your provider if it changes.',
    'published',
    now()
  ),
  (
    'Sleep Tips for Pregnant Mothers',
    'sleep-tips-for-pregnant-mothers',
    'Wellness',
    'Simple changes that can help you rest better as your bump grows.',
    'Sleeping on your left side improves blood flow to the placenta. A pregnancy '
    || 'pillow between your knees and under your belly can ease hip pressure. Avoid '
    || 'screens an hour before bed and keep a consistent sleep schedule.',
    'published',
    now()
  ),
  (
    'NHS: Exercise in Pregnancy',
    'nhs-exercise-in-pregnancy',
    'Fitness',
    'A specialist-recommended external guide on safe exercise during pregnancy.',
    'This is an external article shared by a specialist. Tap "Open Article" to read it on the NHS website.',
    'published',
    now()
  ),
  (
    'Mayo Clinic: Pregnancy Nutrition Basics',
    'mayo-clinic-pregnancy-nutrition-basics',
    'Nutrition',
    'A specialist-recommended external guide on pregnancy nutrition.',
    'This is an external article shared by a specialist. Tap "Open Article" to read it on the Mayo Clinic website.',
    'published',
    now()
  );

-- Add the external link for the two specialist-style rows above.
update public.articles set url = 'https://www.nhs.uk/pregnancy/keeping-well/exercise/'
  where title = 'NHS: Exercise in Pregnancy';
update public.articles set url = 'https://www.mayoclinic.org/healthy-lifestyle/pregnancy-week-by-week/in-depth/pregnancy-nutrition/art-20045082'
  where title = 'Mayo Clinic: Pregnancy Nutrition Basics';
