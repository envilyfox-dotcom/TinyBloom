-- Run in the Supabase SQL editor.
--
-- Authors can now delete their own articles even after publication, not just
-- pre-publish. Replaces the policy from restrict_article_delete_to_unpublished.sql
-- with one that drops the "status <> 'published'" check, keeping the
-- created_by = auth.uid() ownership check as the only guard.

-- clear out the old delete policies (one blocked deleting published articles,
-- the other may or may not exist depending on when this is run)
drop policy if exists "Specialists can delete their own unpublished articles" on public.articles;
drop policy if exists "Specialists can delete their own articles" on public.articles;

-- a specialist can delete any article they wrote, published or not
create policy "Specialists can delete their own articles"
on public.articles
for delete
to authenticated
using (created_by = auth.uid());
