-- Cancelling a consultation is an UPDATE on consultations.status, but
-- without an RLS policy for it, Postgres just silently updates zero rows
-- instead of erroring — cancel button looks like it does nothing.

-- lets a patient update (e.g. cancel) only their own consultations
create policy "Patients can update their own consultations"
on public.consultations
for update
to authenticated
using (patient_id = auth.uid())
with check (patient_id = auth.uid());
