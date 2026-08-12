-- Cancelling now deletes the consultation row outright instead of just
-- marking it cancelled. (add_consultation_update_policy.sql can stay too,
-- it's just not needed for cancel anymore — might help with rescheduling later.)

-- lets a patient delete only their own consultations
create policy "Patients can delete their own consultations"
on public.consultations
for delete
to authenticated
using (patient_id = auth.uid());
