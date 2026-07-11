-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- Two changes to the specialist Review tab's "Needs Action" grouping:
-- 1. publish_buffer no longer flags needs_action for primary/secondary
--    reviewers — there's nothing to do during the buffer window itself
--    (emergency-pending is still reachable from the thread), so it now
--    only shows up under "All Visible".
-- 2. changes_requested now flags needs_action for the author — they're the
--    one who has to edit and resubmit, not a reviewer.

create or replace function public.get_review_queue()
returns table (
  id uuid,
  title text,
  status text,
  primary_group_id integer,
  buffer_started_at timestamptz,
  created_by uuid,
  created_at timestamptz,
  needs_action boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    a.id, a.title, a.status, a.primary_group_id, a.buffer_started_at, a.created_by, a.created_at,
    (
      (a.created_by = auth.uid() and a.status = 'changes_requested')
      or (a.created_by <> auth.uid() and (
        (a.status = 'pending_approval_1' and exists (
          select 1 from public.doctor_group_ids(auth.uid()) dg where dg = a.primary_group_id
        ))
        or (a.status = 'pending_approval_2' and exists (
          select 1 from public.doctor_group_ids(auth.uid()) dg
          where dg in (select * from public.content_visible_group_ids(a.id))
        ) and not exists (
          select 1 from public.approvals ap
          where ap.content_id = a.id and ap.stage = 1 and ap.decision = 'approve' and ap.superseded = false
            and ap.reviewer_id = auth.uid()
        ))
      ))
    ) as needs_action
  from public.articles a
  where public.can_view_review_thread(a.id, auth.uid())
    and a.status <> 'published';
$$;

grant execute on function public.get_review_queue() to authenticated;
