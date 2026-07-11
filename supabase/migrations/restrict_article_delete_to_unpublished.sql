-- Run in the Supabase SQL editor.
--
-- The "My Submissions" tab on the Review screen now lets a specialist delete
-- any of their own articles regardless of review stage, as long as it isn't
-- live yet. The existing delete policy (add_specialist_article_links.sql)
-- had no status check at all, so this replaces it with one that blocks
-- deleting a published article at the database level too, not just in the UI.

drop policy if exists "Specialists can delete their own article links" on public.articles;
drop policy if exists "Specialists can delete their own unpublished articles" on public.articles;

create policy "Specialists can delete their own unpublished articles"
on public.articles
for delete
to authenticated
using (created_by = auth.uid() and status <> 'published');
