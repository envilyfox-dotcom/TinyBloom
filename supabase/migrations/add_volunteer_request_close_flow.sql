-- Run in the Supabase SQL editor (after the earlier volunteer_requests
-- migrations already applied).
--
-- Adds a third state to the thread lifecycle: 'closed' ("Completed" in the
-- UI), reached either by the assigned volunteer tapping "Close Chat" or
-- automatically once 48 hours pass with no new message. 'pending'
-- (unclaimed) and 'responded' (claimed, actively chatting) both display as
-- "Ongoing" in the app — only 'closed' shows as "Completed".
--
-- last_activity_at tracks the most recent message so the 48h auto-close
-- check has something to compare against; a trigger keeps it current
-- instead of relying on the app to remember to bump it on every send.

alter table public.volunteer_requests
  add column if not exists last_activity_at timestamptz not null default now();

-- Backfill existing rows: last activity is the newest message if any
-- messages exist yet, otherwise the question's own created_at.
update public.volunteer_requests r
set last_activity_at = coalesce(
  (select max(m.created_at) from public.volunteer_request_messages m where m.request_id = r.id),
  r.created_at
);

create or replace function public.touch_volunteer_request_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.volunteer_requests
  set last_activity_at = now()
  where id = new.request_id;
  return new;
end;
$$;

drop trigger if exists trg_touch_volunteer_request_activity on public.volunteer_request_messages;
create trigger trg_touch_volunteer_request_activity
after insert on public.volunteer_request_messages
for each row execute function public.touch_volunteer_request_activity();

-- The assigned volunteer can close the chat at any time.
drop policy if exists "Assigned volunteer can close chat" on public.volunteer_requests;
create policy "Assigned volunteer can close chat"
on public.volunteer_requests
for update
to authenticated
using (volunteer_id = auth.uid())
with check (status = 'closed' and volunteer_id = auth.uid());

-- Either participant's client can flip a stale, inactive-for-48h thread to
-- closed the next time they load it (no server cron needed — the app
-- checks this on every list/detail load, see autoCloseStaleRequests).
drop policy if exists "Participant can auto-close stale request" on public.volunteer_requests;
create policy "Participant can auto-close stale request"
on public.volunteer_requests
for update
to authenticated
using (
  status = 'responded'
  and last_activity_at < now() - interval '48 hours'
  and (patient_id = auth.uid() or volunteer_id = auth.uid())
)
with check (
  status = 'closed'
  and (patient_id = auth.uid() or volunteer_id = auth.uid())
);
