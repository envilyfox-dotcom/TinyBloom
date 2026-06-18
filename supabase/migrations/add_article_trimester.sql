-- Run this in the Supabase SQL editor (after add_specialist_article_links.sql).
-- Lets specialists tag an article link with the trimester it's most
-- relevant to, so the app can recommend articles based on the baby's
-- current week instead of just category keywords.

alter table public.articles
  add column if not exists trimester smallint check (trimester in (1, 2, 3));
