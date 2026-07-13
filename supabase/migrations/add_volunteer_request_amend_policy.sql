-- Run in the Supabase SQL editor (after create_volunteer_requests.sql).
--
-- Lets the asking mum edit her own question's text, but only while it's
-- still pending — once a volunteer has replied, changing the question out
-- from under their answer would be confusing, so this policy (and the app)
-- both block edits once status = 'responded'.

create policy "Users can amend their own pending question"
on public.volunteer_requests
for update
to authenticated
using (patient_id = auth.uid() and status = 'pending')
with check (patient_id = auth.uid() and status = 'pending');
