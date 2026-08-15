-- Adds one-level forum comment replies and lets users edit their own comments.
alter table public.forum_comments
  add column if not exists parent_comment_id uuid
  references public.forum_comments(id) on delete cascade;

drop policy if exists "Users can update their own comments" on public.forum_comments;
create policy "Users can update their own comments"
on public.forum_comments for update to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());
