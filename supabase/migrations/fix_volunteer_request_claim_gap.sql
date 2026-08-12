-- Run after add_volunteer_request_threads.sql.
-- "Unclaimed" should mean exactly one thing: volunteer_id is null. The old
-- policies also required status = 'pending', which left a gap for rows
-- created before the thread system existed — their reply went straight into
-- the old `response` column, so volunteer_id is null but status is already
-- 'responded'. Those rows were stuck, invisible to every volunteer.

-- widen "open" to just volunteer_id is null, drop the status check
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

-- same fix for claiming: only volunteer_id null matters, not status
drop policy if exists "Claim an open volunteer request" on public.volunteer_requests;
create policy "Claim an open volunteer request"
on public.volunteer_requests
for update
to authenticated
using (volunteer_id is null)
with check (volunteer_id = auth.uid() and status = 'responded');
