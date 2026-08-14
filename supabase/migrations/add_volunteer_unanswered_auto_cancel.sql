-- Extend the client-triggered 48-hour quick-chat sweep to unanswered
-- requests. A pending request with no volunteer response becomes cancelled;
-- a responded request remains governed by the existing responded -> closed
-- policy.

drop policy if exists "Participant can auto-cancel unanswered request"
  on public.volunteer_requests;

create policy "Participant can auto-cancel unanswered request"
on public.volunteer_requests
for update
to authenticated
using (
  status in ('pending', 'open', 'waiting')
  and created_at < now() - interval '48 hours'
  and patient_id = auth.uid()
)
with check (
  status = 'cancelled'
  and patient_id = auth.uid()
);
