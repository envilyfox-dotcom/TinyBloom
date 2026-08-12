-- Run after add_specialist_article_links.sql.

-- lets specialists tag an article with the trimester it's most relevant to,
-- so we can recommend articles based on how far along the baby is
alter table public.articles
  add column if not exists trimester smallint check (trimester in (1, 2, 3));
