-- Run in the Supabase SQL editor, after add_approval_issue_resolution.sql and
-- add_superseded_reason_for_emergency_recall.sql.
-- Backs the Review Thread redesign:
--   1. Edits no longer void approvals / reset status (edit_article_content
--      replaced below) — instead every edit that actually changes a field is
--      logged to the new article_edit_history table with full old/new text,
--      so the Checks dropdown can show "what changed" as proof instead of
--      silently discarding the prior review progress.
--   2. "Approved with suggestion" — a third reviewer action alongside
--      approve/reject. It advances the stage exactly like a plain approval
--      (approvals.has_suggestion marks it as such) but requires a comment
--      and displays/resolves like a rejection issue in the UI — except it
--      never blocks resubmit_content, which only counts unresolved
--      decision = 'reject' rows.

-- ── 1. Edit history (replaces the void-approvals-on-edit behavior) ─────────
create table if not exists public.article_edit_history (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  editor_id uuid not null references public.profiles(id),
  changed_fields text[] not null,
  old_title text,
  new_title text,
  old_content text,
  new_content text,
  old_category text,
  new_category text,
  old_trimester smallint,
  new_trimester smallint,
  created_at timestamptz not null default now()
);

alter table public.article_edit_history enable row level security;

-- Same visibility scope as approvals/review_comments — written exclusively
-- by edit_article_content (security definer), so no insert policy needed.
drop policy if exists "Review-scope doctors can view edit history" on public.article_edit_history;
create policy "Review-scope doctors can view edit history"
on public.article_edit_history for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

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
  v_old_title text;
  v_old_content text;
  v_old_category text;
  v_old_trimester smallint;
  v_changed text[] := '{}';
begin
  select created_by, status, title, content, category, trimester
    into v_author, v_status, v_old_title, v_old_content, v_old_category, v_old_trimester
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

  if v_old_title is distinct from p_title then
    v_changed := array_append(v_changed, 'title');
  end if;
  if v_old_content is distinct from p_content then
    v_changed := array_append(v_changed, 'content');
  end if;
  if v_old_category is distinct from p_category then
    v_changed := array_append(v_changed, 'category');
  end if;
  if v_old_trimester is distinct from p_trimester then
    v_changed := array_append(v_changed, 'trimester');
  end if;

  if array_length(v_changed, 1) > 0 then
    insert into public.article_edit_history (
      content_id, editor_id, changed_fields,
      old_title, new_title, old_content, new_content,
      old_category, new_category, old_trimester, new_trimester
    ) values (
      p_content_id, v_uid, v_changed,
      v_old_title, p_title, v_old_content, p_content,
      v_old_category, p_category, v_old_trimester, p_trimester
    );
  end if;

  -- Note: unlike the previous version of this function, approvals and
  -- status are intentionally left untouched — an edit is now just logged
  -- as history, not a reset of review progress.
  update public.articles
  set title = p_title, content = p_content, category = p_category, trimester = p_trimester
  where id = p_content_id;
end;
$$;

grant execute on function public.edit_article_content(uuid, text, text, text, smallint) to authenticated;

-- ── 2. Approved with suggestion ─────────────────────────────────────────
alter table public.approvals
  add column if not exists has_suggestion boolean not null default false;

create or replace function public.approve_content_with_suggestion(
  p_content_id uuid,
  p_stage smallint,
  p_comment text
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
  v_primary_group integer;
  v_reviewer_1 uuid;
begin
  if p_stage not in (1, 2) then
    raise exception 'Invalid stage';
  end if;
  if p_comment is null or length(trim(p_comment)) = 0 then
    raise exception 'A comment is required for approval with suggestion';
  end if;

  select created_by, status, primary_group_id into v_author, v_status, v_primary_group
  from public.articles where id = p_content_id for update;

  if v_status is null then
    raise exception 'Content not found';
  end if;
  if v_uid = v_author then
    raise exception 'Authors cannot review their own content';
  end if;

  if p_stage = 1 then
    if v_status <> 'pending_approval_1' then
      raise exception 'Content is not awaiting approval 1';
    end if;
    if not exists (select 1 from public.doctor_group_ids(v_uid) dg where dg = v_primary_group) then
      raise exception 'Only primary-group doctors can grant approval 1';
    end if;

    insert into public.approvals (content_id, stage, reviewer_id, decision, has_suggestion, reason)
    values (p_content_id, 1, v_uid, 'approve', true, p_comment);

    update public.articles set status = 'pending_approval_2' where id = p_content_id;
  else
    if v_status <> 'pending_approval_2' then
      raise exception 'Content is not awaiting approval 2';
    end if;
    if not exists (
      select 1 from public.doctor_group_ids(v_uid) dg
      where dg in (select * from public.content_visible_group_ids(p_content_id))
    ) then
      raise exception 'Only primary or secondary group doctors can grant approval 2';
    end if;

    select reviewer_id into v_reviewer_1 from public.approvals
    where content_id = p_content_id and stage = 1 and decision = 'approve' and superseded = false
    order by created_at desc limit 1;

    if v_reviewer_1 is not null and v_reviewer_1 = v_uid then
      raise exception 'Approval 2 reviewer must differ from the approval 1 reviewer';
    end if;

    insert into public.approvals (content_id, stage, reviewer_id, decision, has_suggestion, reason)
    values (p_content_id, 2, v_uid, 'approve', true, p_comment);

    update public.articles
    set status = 'publish_buffer', buffer_started_at = now()
    where id = p_content_id;
  end if;
end;
$$;

grant execute on function public.approve_content_with_suggestion(uuid, smallint, text) to authenticated;

-- ── 3. resolve_review_issue: also accept suggestion rows ───────────────
-- Reject issues keep the existing "only while changes_requested" gate;
-- suggestion rows are advisory only, so they're resolvable at any status.
create or replace function public.resolve_review_issue(p_approval_id uuid, p_reply text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_content_id uuid;
  v_decision text;
  v_resolved boolean;
  v_has_suggestion boolean;
  v_author uuid;
  v_status text;
begin
  if p_reply is null or length(trim(p_reply)) = 0 then
    raise exception 'A reply is required';
  end if;

  select content_id, decision, resolved, has_suggestion
    into v_content_id, v_decision, v_resolved, v_has_suggestion
  from public.approvals where id = p_approval_id for update;

  if v_content_id is null then
    raise exception 'Issue not found';
  end if;
  if v_resolved then
    raise exception 'This issue is already resolved';
  end if;
  if v_decision <> 'reject' and not (v_decision = 'approve' and v_has_suggestion) then
    raise exception 'Only rejection issues or approval suggestions can be resolved';
  end if;

  select created_by, status into v_author, v_status
  from public.articles where id = v_content_id for update;

  if v_uid <> v_author then
    raise exception 'Only the author can resolve this issue';
  end if;
  if v_decision = 'reject' and v_status <> 'changes_requested' then
    raise exception 'Content is not awaiting changes';
  end if;

  update public.approvals
  set resolved = true, resolution_reply = p_reply
  where id = p_approval_id;
end;
$$;

grant execute on function public.resolve_review_issue(uuid, text) to authenticated;
