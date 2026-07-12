-- Run in the Supabase SQL editor.
-- Adds one-level reply support to public_comments (Learn tab article
-- comments), mirroring review_comments.parent_comment_id. No RLS changes
-- needed — the existing insert/select policies already cover replies since
-- they only key off content_id/user_id, not parent_comment_id.

alter table public.public_comments
  add column if not exists parent_comment_id uuid
  references public.public_comments(id) on delete cascade;
