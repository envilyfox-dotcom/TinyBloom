-- Run in the Supabase SQL editor, after add_review_pipeline_functions.sql.
-- TESTING ONLY. Shrinks the publish_buffer window from 24h to 0 so
-- articles auto-publish as soon as process_buffer_expirations() next runs
-- (cron ticks every 15 min — call the function manually below for an
-- immediate result), instead of waiting a full day. Revert before
-- shipping by re-running add_review_pipeline_functions.sql, which
-- restores the interval '24 hours' version of this function.
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
    and now() >= a.buffer_started_at + interval '0 minutes'
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

-- To publish immediately instead of waiting for the next cron tick, run:
-- select public.process_buffer_expirations();
