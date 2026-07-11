-- Run in the Supabase SQL editor, after add_reviewer_distinctness_to_reject.sql.
-- Article_System_specialist.md §3.3 previously had `clinical` stage-2
-- rejects do a "full reset": void approval 1 and send status straight back
-- to pending_approval_1, skipping the author's edit step entirely. That
-- diverged from every other reject path (stage 1, and non_clinical stage 2)
-- and needed its own reply/visibility handling on the review thread.
--
-- Simplified: a stage-2 reject now always behaves like a stage-1 reject,
-- regardless of category — status goes to changes_requested, approval 1 is
-- left untouched. The author resolves the issue and resubmits; since
-- approval 1 is still active, resubmit_content already sends it straight
-- back to pending_approval_2 (not approval 1) for the one remaining
-- approval before publish_buffer. reject_category is still recorded on the
-- approval row, just no longer changes the reset behavior.

create or replace function public.reject_content(
  p_content_id uuid,
  p_stage smallint,
  p_category text,
  p_reason text
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
  if p_category not in ('clinical', 'non_clinical') then
    raise exception 'Invalid reject category';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'A reason is required';
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
      raise exception 'Only primary-group doctors can reject approval 1';
    end if;

    insert into public.approvals (content_id, stage, reviewer_id, decision, reject_category, reason)
    values (p_content_id, 1, v_uid, 'reject', p_category, p_reason);

    update public.articles set status = 'changes_requested' where id = p_content_id;
  else
    if v_status <> 'pending_approval_2' then
      raise exception 'Content is not awaiting approval 2';
    end if;
    if not exists (
      select 1 from public.doctor_group_ids(v_uid) dg
      where dg in (select * from public.content_visible_group_ids(p_content_id))
    ) then
      raise exception 'Only primary or secondary group doctors can reject approval 2';
    end if;

    select reviewer_id into v_reviewer_1 from public.approvals
    where content_id = p_content_id and stage = 1 and decision = 'approve' and superseded = false
    order by created_at desc limit 1;

    if v_reviewer_1 is not null and v_reviewer_1 = v_uid then
      raise exception 'Approval 2 reviewer must differ from the approval 1 reviewer';
    end if;

    insert into public.approvals (content_id, stage, reviewer_id, decision, reject_category, reason)
    values (p_content_id, 2, v_uid, 'reject', p_category, p_reason);

    -- Approval 1 stays valid regardless of category; author edits and
    -- resubmits straight back to approval 2 (see resubmit_content).
    update public.articles set status = 'changes_requested' where id = p_content_id;
  end if;
end;
$$;
