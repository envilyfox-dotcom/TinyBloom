-- Run in the Supabase SQL editor, after add_content_review_pipeline.sql.
-- Lets any authenticated user (not just review-scope doctors) see who
-- approved a *published* article, for the "Approved by" panel on the public
-- Educational Post detail screen. Postgres ORs every permissive policy for
-- the same command together, so this only ever ADDS visibility — approvals
-- on content that hasn't published yet stay restricted to review-scope
-- doctors via the existing "Review-scope doctors can view approvals" policy.

drop policy if exists "Anyone can view approvals on published articles" on public.approvals;
create policy "Anyone can view approvals on published articles"
on public.approvals for select to authenticated
using (
  decision = 'approve'
  and superseded = false
  and exists (
    select 1 from public.articles a
    where a.id = content_id and a.status = 'published'
  )
);
