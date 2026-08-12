-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- Fixes content_visible_group_ids() (Article_System_specialist.md §4.1/§5):
-- primary group members should see an article as soon as it's submitted,
-- but secondary group members should only see it once approval 2 opens up
-- (i.e. an active, non-superseded approval 1 exists) — not just because
-- they're in the mapped secondary group regardless of what stage it's at.
-- Drafts stay visible only to their author, which is handled separately by
-- can_view_review_thread. Everything else that cares about visibility
-- (RLS policies, get_review_queue, approve/reject/emergency functions)
-- reads through this one function, so nothing else needs to change.
create or replace function public.content_visible_group_ids(cid uuid)
returns setof integer
language sql
stable
security definer
set search_path = public
as $$
  -- primary group can see it as soon as it's out of draft
  select a.primary_group_id
  from public.articles a
  where a.id = cid
    and a.primary_group_id is not null
    and a.status <> 'draft'
  union
  -- secondary group only sees it once approval 1 has actually passed
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
