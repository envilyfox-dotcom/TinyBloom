-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- Article_System_specialist.md §3.3/§7.1: the "approval 2 reviewer must
-- differ from the approval 1 reviewer" rule applies to the whole approval-2
-- reviewer pool, not just the approve path. approve_content already
-- enforced this; reject_content's stage-2 branch didn't, so the stage-1
-- approver could reject their own approval at stage 2. Also widens the
-- safety-net trigger to cover rejects, matching the approve path.

create or replace function public.enforce_reviewer_2_distinct()
returns trigger
language plpgsql
as $$
declare
  v_reviewer_1 uuid;
begin
  if new.stage = 2 then
    select reviewer_id into v_reviewer_1 from public.approvals
    where content_id = new.content_id and stage = 1 and decision = 'approve' and superseded = false
    order by created_at desc limit 1;

    if v_reviewer_1 is not null and v_reviewer_1 = new.reviewer_id then
      raise exception 'Approval 2 reviewer must differ from the approval 1 reviewer';
    end if;
  end if;
  return new;
end;
$$;

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

    if p_category = 'clinical' then
      -- Full reset: void the existing approval 1 too.
      update public.approvals set superseded = true
      where content_id = p_content_id and stage = 1 and decision = 'approve' and superseded = false;
      update public.articles set status = 'pending_approval_1' where id = p_content_id;
    else
      -- Partial reset: approval 1 stays valid; author edits and resubmits
      -- straight back to approval 2 (see resubmit_content).
      update public.articles set status = 'changes_requested' where id = p_content_id;
    end if;
  end if;
end;
$$;
