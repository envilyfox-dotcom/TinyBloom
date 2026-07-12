-- Run in the Supabase SQL editor, after add_review_thread_redesign.sql.
-- Adds author info (name/photo/specialization) to get_review_queue() so the
-- Review tab list items can show the same pfp/name/specialization/time
-- header the Learn tab uses, and orders the queue newest-first to match
-- every other list in the app.

-- create or replace can't change the OUT-parameter row type (we're adding
-- the `author` column), so the old signature must be dropped first.
drop function if exists public.get_review_queue();

create or replace function public.get_review_queue()
returns table (
  id uuid,
  title text,
  status text,
  primary_group_id integer,
  buffer_started_at timestamptz,
  created_by uuid,
  created_at timestamptz,
  needs_action boolean,
  author jsonb
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
    ) as needs_action,
    jsonb_build_object(
      'full_name', p.full_name,
      'profile_picture_url', p.profile_picture_url,
      'specialist_profiles', jsonb_build_object('specialization', sp.specialization)
    ) as author
  from public.articles a
  join public.profiles p on p.id = a.created_by
  left join public.specialist_profiles sp on sp.user_id = a.created_by
  where public.can_view_review_thread(a.id, auth.uid())
    and a.status <> 'published'
  order by a.created_at desc;
$$;

grant execute on function public.get_review_queue() to authenticated;
