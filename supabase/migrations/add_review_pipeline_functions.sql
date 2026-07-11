-- Run in the Supabase SQL editor, after add_content_review_pipeline.sql.
-- Part 3 of the specialist article review pipeline: the RPC functions the
-- Flutter app calls for every state transition, plus the scheduled job for
-- the 24h publish buffer. These are the ONLY way approvals/rejects/
-- emergency-pending rows get written or `articles.status` moves between
-- review states — the app never writes those directly, so every rule in
-- Article_System_specialist.md §7 is enforced here, not just in the UI.

-- ── Safety-net triggers (defense in depth even though the RPCs below are the
--    only insert path today) ─────────────────────────────────────────────
create or replace function public.enforce_reviewer_2_distinct()
returns trigger
language plpgsql
as $$
declare
  v_reviewer_1 uuid;
begin
  if new.stage = 2 and new.decision = 'approve' then
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

drop trigger if exists approvals_enforce_reviewer_2_distinct on public.approvals;
create trigger approvals_enforce_reviewer_2_distinct
before insert on public.approvals
for each row execute function public.enforce_reviewer_2_distinct();

create or replace function public.enforce_emergency_click_distinct()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from public.emergency_pending_clicks
    where content_id = new.content_id and clicker_id = new.clicker_id and resolved = false
  ) then
    raise exception 'You already flagged this item; waiting on a second reviewer.';
  end if;
  return new;
end;
$$;

drop trigger if exists emergency_clicks_enforce_distinct on public.emergency_pending_clicks;
create trigger emergency_clicks_enforce_distinct
before insert on public.emergency_pending_clicks
for each row execute function public.enforce_emergency_click_distinct();

-- ── Approval 1 / Approval 2 ──────────────────────────────────────────────
create or replace function public.approve_content(p_content_id uuid, p_stage smallint)
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

    insert into public.approvals (content_id, stage, reviewer_id, decision)
    values (p_content_id, 1, v_uid, 'approve');

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

    insert into public.approvals (content_id, stage, reviewer_id, decision)
    values (p_content_id, 2, v_uid, 'approve');

    update public.articles
    set status = 'publish_buffer', buffer_started_at = now()
    where id = p_content_id;
  end if;
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

    insert into public.approvals (content_id, stage, reviewer_id, decision, reject_category, reason)
    values (p_content_id, 2, v_uid, 'reject', p_category, p_reason);

    if p_category = 'clinical' then
      -- Full reset: void the existing approval 1 too.
      update public.approvals set superseded = true
      where content_id = p_content_id and stage = 1 and decision = 'approve' and superseded = false;
      update public.articles set status = 'pending_approval_1' where id = p_content_id;
    else
      -- Partial reset: approval 1 stays valid; author edits and resubmits
      -- straight back to approval 2 (see resubmit_content below).
      update public.articles set status = 'changes_requested' where id = p_content_id;
    end if;
  end if;
end;
$$;

-- Author submits a draft for the first time, or resubmits after
-- changes_requested. Whether it lands back on approval 1 or approval 2
-- depends on whether an un-superseded approval 1 still exists.
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

  select exists (
    select 1 from public.approvals
    where content_id = p_content_id and stage = 1 and decision = 'approve' and superseded = false
  ) into v_has_active_stage1;

  update public.articles
  set status = (case when v_has_active_stage1 then 'pending_approval_2' else 'pending_approval_1' end)::content_status
  where id = p_content_id;
end;
$$;

-- ── Emergency pending (recall during the publish buffer) ────────────────
create or replace function public.trigger_emergency_pending(
  p_content_id uuid,
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
  v_unresolved_count integer;
begin
  if p_category not in ('clinical', 'non_clinical') then
    raise exception 'Invalid category';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'A reason is required';
  end if;

  select created_by, status into v_author, v_status
  from public.articles where id = p_content_id for update;

  if v_status is null then
    raise exception 'Content not found';
  end if;
  if v_status not in ('publish_buffer', 'emergency_pending') then
    raise exception 'Emergency pending can only be triggered during the publish buffer';
  end if;
  if v_uid = v_author then
    raise exception 'Authors cannot trigger emergency pending on their own content';
  end if;
  if not exists (
    select 1 from public.doctor_group_ids(v_uid) dg
    where dg in (select * from public.content_visible_group_ids(p_content_id))
  ) then
    raise exception 'Only primary or secondary group doctors can trigger emergency pending';
  end if;

  insert into public.emergency_pending_clicks (content_id, clicker_id, reason, category)
  values (p_content_id, v_uid, p_reason, p_category);

  select count(*) into v_unresolved_count
  from public.emergency_pending_clicks
  where content_id = p_content_id and resolved = false;

  if v_unresolved_count >= 2 then
    update public.emergency_pending_clicks
    set resolved = true
    where content_id = p_content_id and resolved = false;

    if p_category = 'clinical' then
      update public.approvals set superseded = true
      where content_id = p_content_id and stage in (1, 2) and decision = 'approve' and superseded = false;
      update public.articles set status = 'pending_approval_1', buffer_started_at = null where id = p_content_id;
    else
      update public.approvals set superseded = true
      where content_id = p_content_id and stage = 2 and decision = 'approve' and superseded = false;
      update public.articles set status = 'pending_approval_2', buffer_started_at = null where id = p_content_id;
    end if;
  else
    -- First click: pause the countdown's visible state (flagged "under
    -- review") but keep buffer_started_at as-is — doc §3.5: if the second
    -- click never comes, the original 24h deadline still applies and the
    -- lone click is discarded (see process_buffer_expirations below).
    update public.articles set status = 'emergency_pending' where id = p_content_id;
  end if;
end;
$$;

-- ── Scheduled 24h auto-publish ───────────────────────────────────────────
create or replace function public.process_buffer_expirations()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.articles a
  set status = 'published',
      published_at = now(),
      buffer_started_at = null
  where a.status in ('publish_buffer', 'emergency_pending')
    and a.buffer_started_at is not null
    and now() >= a.buffer_started_at + interval '24 hours'
    and (
      select count(*) from public.emergency_pending_clicks c
      where c.content_id = a.id and c.resolved = false
    ) < 2;

  -- Discard any lone unresolved click left over on rows that just published.
  update public.emergency_pending_clicks c
  set resolved = true
  where c.resolved = false
    and exists (
      select 1 from public.articles a
      where a.id = c.content_id and a.status = 'published' and a.buffer_started_at is null
    );
end;
$$;

-- ── Review queue (used by the specialist Review tab) ────────────────────
-- Centralizes "does this need my action" so the eligibility logic lives in
-- one place, matching the checks approve_content/reject_content enforce.
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
      a.created_by <> auth.uid() and (
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
        or (a.status = 'publish_buffer' and exists (
          select 1 from public.doctor_group_ids(auth.uid()) dg
          where dg in (select * from public.content_visible_group_ids(a.id))
        ))
      )
    ) as needs_action
  from public.articles a
  where public.can_view_review_thread(a.id, auth.uid())
    and a.status <> 'published';
$$;

grant execute on function public.get_review_queue() to authenticated;

grant execute on function public.approve_content(uuid, smallint) to authenticated;
grant execute on function public.reject_content(uuid, smallint, text, text) to authenticated;
grant execute on function public.resubmit_content(uuid) to authenticated;
grant execute on function public.trigger_emergency_pending(uuid, text, text) to authenticated;

-- Requires the pg_cron extension. On most Supabase projects this can be
-- enabled directly from SQL; if this errors with a permissions message,
-- enable it once via Dashboard → Database → Extensions → pg_cron, then
-- re-run just the block below.
create extension if not exists pg_cron;

select cron.schedule(
  'process-buffer-expirations',
  '*/15 * * * *',
  $$ select public.process_buffer_expirations(); $$
) where not exists (
  select 1 from cron.job where jobname = 'process-buffer-expirations'
);
