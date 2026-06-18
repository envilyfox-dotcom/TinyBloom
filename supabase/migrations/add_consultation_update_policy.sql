-- Run in the Supabase SQL editor.
--
-- Cancelling a consultation does an UPDATE on consultations.status, but
-- there's likely no RLS policy letting a patient update their own
-- consultation row — Postgres/PostgREST doesn't error in that case, it just
-- silently updates zero rows, which looks like cancel "did nothing."
--
-- This lets a patient cancel (or otherwise update) only their own
-- consultations.

create policy "Patients can update their own consultations"
on public.consultations
for update
to authenticated
using (patient_id = auth.uid())
with check (patient_id = auth.uid());
