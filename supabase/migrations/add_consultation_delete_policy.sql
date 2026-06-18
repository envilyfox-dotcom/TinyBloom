-- Run in the Supabase SQL editor.
--
-- Cancelling now deletes the consultation row outright (no need to keep a
-- "cancelled" record around), so this replaces the update-based cancel with
-- a DELETE policy letting a patient remove only their own consultations.
-- (You can keep add_consultation_update_policy.sql too — it's harmless and
-- may be useful later for rescheduling — but it's no longer required for
-- cancel to work.)

create policy "Patients can delete their own consultations"
on public.consultations
for delete
to authenticated
using (patient_id = auth.uid());
