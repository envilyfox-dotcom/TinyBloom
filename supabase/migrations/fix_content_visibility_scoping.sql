-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- Fixes content_visible_group_ids() to match Article_System_specialist.md
-- §4.1 / §5, which this initially missed: primary group members can see
-- content the moment it's submitted, but secondary group members only gain
-- visibility "once approval 2 opens" (i.e. once an active, non-superseded
-- approval 1 exists) — not simply by being in the mapped secondary group
-- regardless of review stage. Drafts stay visible only to their author
-- (handled by the separate created_by check in can_view_review_thread)
-- until submitted.
--
-- Every policy/function that depends on this (can_view_review_thread,
-- approve_content, reject_content, trigger_emergency_pending,
-- get_review_queue, and the articles/approvals/review_comments RLS
-- policies) reads through this one function, so no other object needs to
-- change.
create or replace function public.content_visible_group_ids(cid uuid)
returns setof integer
language sql
stable
security definer
set search_path = public
as $$
  select a.primary_group_id
  from public.articles a
  where a.id = cid
    and a.primary_group_id is not null
    and a.status <> 'draft'
  union
  select gsm.secondary_group_id
  from public.articles a
  join public.group_secondary_map gsm on gsm.primary_group_id = a.primary_group_id
  where a.id = cid
    and exists (
      select 1 from public.approvals ap
      where ap.content_id = a.id
        and ap.stage = 1
        and ap.decision = 'approve'
        and ap.superseded = false
    );
$$;
