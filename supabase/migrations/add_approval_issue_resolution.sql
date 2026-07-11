-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- Lets an author resolve individual rejection issues (reply + mark solved)
-- before resubmitting, instead of a single blanket "resubmit as-is"/"edit
-- and resubmit" choice. `resubmit_content` now refuses to run while any
-- reject row on the content is still unresolved.

alter table public.approvals
  add column if not exists resolved boolean not null default false,
  add column if not exists resolution_reply text;

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
  v_author uuid;
  v_status text;
begin
  if p_reply is null or length(trim(p_reply)) = 0 then
    raise exception 'A reply is required';
  end if;

  select content_id, decision, resolved into v_content_id, v_decision, v_resolved
  from public.approvals where id = p_approval_id for update;

  if v_content_id is null then
    raise exception 'Issue not found';
  end if;
  if v_decision <> 'reject' then
    raise exception 'Only rejection issues can be resolved';
  end if;
  if v_resolved then
    raise exception 'This issue is already resolved';
  end if;

  select created_by, status into v_author, v_status
  from public.articles where id = v_content_id for update;

  if v_uid <> v_author then
    raise exception 'Only the author can resolve this issue';
  end if;
  if v_status <> 'changes_requested' then
    raise exception 'Content is not awaiting changes';
  end if;

  update public.approvals
  set resolved = true, resolution_reply = p_reply
  where id = p_approval_id;
end;
$$;

grant execute on function public.resolve_review_issue(uuid, text) to authenticated;

-- Defense in depth: a resubmit can't skip the reply workflow even if a
-- client tries to call the RPC directly with outstanding issues.
create or replace function public.resubmit_content(p_content_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid;
  v_status text;
  v_has_active_stage1 boolean;
  v_unresolved_count integer;
begin
  select created_by, status into v_author, v_status
  from public.articles where id = p_content_id for update;

  if v_status is null then
    raise exception 'Content not found';
  end if;
  if v_uid <> v_author then
    raise exception 'Only the author can submit this content';
  end if;
  if v_status not in ('draft', 'changes_requested') then
    raise exception 'Content is not in a submittable state';
  end if;

  if v_status = 'changes_requested' then
    select count(*) into v_unresolved_count
    from public.approvals
    where content_id = p_content_id and decision = 'reject' and resolved = false;

    if v_unresolved_count > 0 then
      raise exception 'Resolve all outstanding issues before resubmitting';
    end if;
  end if;

  select exists (
    select 1 from public.approvals
    where content_id = p_content_id and stage = 1 and decision = 'approve' and superseded = false
  ) into v_has_active_stage1;

  update public.articles
  set status = (case when v_has_active_stage1 then 'pending_approval_2' else 'pending_approval_1' end)::content_status
  where id = p_content_id;
end;
$$;
