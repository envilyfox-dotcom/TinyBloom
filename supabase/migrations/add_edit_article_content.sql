-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- Lets the author edit their article's title/content/category/trimester at
-- any point before it's published, not just while draft or
-- changes_requested. Editing while a review is already in progress
-- (pending_approval_1, pending_approval_2, publish_buffer,
-- emergency_pending) voids any approval already granted — a reviewer
-- approved the text as it stood, not whatever the author changes it to —
-- and resets the pipeline back to pending_approval_1 for a fresh review of
-- the edited text. Editing during draft/changes_requested is unaffected:
-- fields update in place, no status/approval change.
--
-- Replaces the plain `articles` table UPDATE the client previously used
-- (SupabaseService.updateArticleDraft) — like every other state-changing
-- action in this pipeline, edits now go through a security-definer RPC so
-- the reset side effects can't be skipped by calling the table directly.
--
-- superseded_reason records why an approval was voided, so the review
-- thread's History can show *why* (e.g. "Article edited") instead of just
-- a bare "(superseded)". Also set by trigger_emergency_pending — see
-- add_superseded_reason_for_emergency_recall.sql.

alter table public.approvals
  add column if not exists superseded_reason text
  check (superseded_reason in ('edited', 'emergency_recall'));

create or replace function public.edit_article_content(
  p_content_id uuid,
  p_title text,
  p_content text,
  p_category text,
  p_trimester smallint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid;
  v_status text;
begin
  select created_by, status into v_author, v_status
  from public.articles where id = p_content_id for update;

  if v_status is null then
    raise exception 'Content not found';
  end if;
  if v_uid <> v_author then
    raise exception 'Only the author can edit this content';
  end if;
  if v_status = 'published' then
    raise exception 'Published content cannot be edited here';
  end if;

  update public.articles
  set title = p_title, content = p_content, category = p_category, trimester = p_trimester
  where id = p_content_id;

  if v_status in ('pending_approval_1', 'pending_approval_2', 'publish_buffer', 'emergency_pending') then
    update public.approvals set superseded = true, superseded_reason = 'edited'
    where content_id = p_content_id and decision = 'approve' and superseded = false;

    update public.emergency_pending_clicks set resolved = true
    where content_id = p_content_id and resolved = false;

    update public.articles
    set status = 'pending_approval_1', buffer_started_at = null
    where id = p_content_id;
  end if;
end;
$$;

grant execute on function public.edit_article_content(uuid, text, text, text, smallint) to authenticated;
