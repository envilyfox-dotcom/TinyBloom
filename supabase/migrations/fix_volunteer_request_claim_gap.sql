-- Run in the Supabase SQL editor (after add_volunteer_request_threads.sql).
--
-- "Unclaimed" should mean exactly one thing: volunteer_id is null. The
-- previous policies also required status = 'pending', which created a gap
-- for rows created before this thread system existed (their response was
-- written straight into the old `response` column, so volunteer_id is null
-- but status is already 'responded'). Those rows were invisible to every
-- volunteer — not actually claimed by anyone, just stuck.

drop policy if exists "View own, assigned, or open volunteer requests" on public.volunteer_requests;
create policy "View own, assigned, or open volunteer requests"
on public.volunteer_requests
for select
to authenticated
using (
  patient_id = auth.uid()
  or volunteer_id = auth.uid()
  or volunteer_id is null
);

drop policy if exists "Claim an open volunteer request" on public.volunteer_requests;
create policy "Claim an open volunteer request"
on public.volunteer_requests
for update
to authenticated
using (volunteer_id is null)
with check (volunteer_id = auth.uid() and status = 'responded');
