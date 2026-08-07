-- Run in the Supabase SQL editor, after cleanup_noisy_article_tags_3.sql.
-- Tag capitalization had drifted: most tags were lowercase (e.g.
-- "postpartum recovery", "mental health") while a couple, like
-- "Antenatal Care" and "Pregnancy Conditions", were already title-cased.
-- This normalizes every tag to title case so a single-word tag has one
-- capital letter and a two-word tag has both words capitalized.
--
-- initcap() is used for this: it's a no-op on tags already in the right
-- form, and it leaves the "1st/2nd/3rd Trimester" tags untouched since a
-- leading digit has no case to change.

update public.articles
set tags = (
  select array_agg(initcap(t) order by ord)
  from unnest(tags) with ordinality as u(t, ord)
)
where tags <> '{}';

-- `category` (still read directly by baby_development_screen/
-- features_screens for keyword matching) is derived from tags the same
-- way the earlier cleanup passes did, so it stays in sync with the
-- newly-normalized casing.
update public.articles
set category = coalesce(
  (select t from unnest(tags) t
   where t not in ('1st Trimester', '2nd Trimester', '3rd Trimester')
   limit 1),
  'General'
)
where tags <> '{}';
