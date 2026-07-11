-- Run in the Supabase SQL editor, after add_edit_article_content.sql.
-- trigger_emergency_pending also voids approvals (a 2-click emergency
-- recall during publish_buffer — Article_System §3.5), so it needs the
-- same superseded_reason tagging edit_article_content added, otherwise a
-- recalled approval would show as "(superseded)" with no explanation.
-- `alter table ... if not exists` repeated here defensively in case this
-- runs before add_edit_article_content.sql.

alter table public.approvals
  add column if not exists superseded_reason text
  check (superseded_reason in ('edited', 'emergency_recall'));

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
      update public.approvals set superseded = true, superseded_reason = 'emergency_recall'
      where content_id = p_content_id and stage in (1, 2) and decision = 'approve' and superseded = false;
      update public.articles set status = 'pending_approval_1', buffer_started_at = null where id = p_content_id;
    else
      update public.approvals set superseded = true, superseded_reason = 'emergency_recall'
      where content_id = p_content_id and stage = 2 and decision = 'approve' and superseded = false;
      update public.articles set status = 'pending_approval_2', buffer_started_at = null where id = p_content_id;
    end if;
  else
    -- First click: pause the countdown's visible state (flagged "under
    -- review") but keep buffer_started_at as-is — doc §3.5: if the second
    -- click never comes, the original 24h deadline still applies and the
    -- lone click is discarded (see process_buffer_expirations).
    update public.articles set status = 'emergency_pending' where id = p_content_id;
  end if;
end;
$$;

grant execute on function public.trigger_emergency_pending(uuid, text, text) to authenticated;
