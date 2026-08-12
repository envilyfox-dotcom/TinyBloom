-- Run in the Supabase SQL editor, after add_approval_issue_resolution.sql.
-- Lets a review comment be tied to a specific rejection ("issue") so a
-- non-author reviewer's reply shows up inline on that issue's card instead
-- of only in the general Discussion feed.

-- lets a comment attach to one specific rejection issue instead of just floating in the general thread
alter table public.review_comments
  add column if not exists approval_id uuid references public.approvals(id) on delete cascade;

-- any doctor in the review scope can comment, but if they tag an issue (approval_id) it has to belong to this same article
drop policy if exists "Review-scope doctors can comment" on public.review_comments;
create policy "Review-scope doctors can comment"
on public.review_comments for insert to authenticated
with check (
  author_id = auth.uid()
  and public.can_view_review_thread(content_id, auth.uid())
  and (
    approval_id is null
    or exists (
      select 1 from public.approvals ap
      where ap.id = approval_id and ap.content_id = content_id
    )
  )
);
