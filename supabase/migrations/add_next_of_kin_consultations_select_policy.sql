-- Run in the Supabase SQL editor.
--
-- Next-of-kin's Consultations screen was fixed to query
-- SupabaseService.getConsultationsForPatient(linkedMum.id) instead of the
-- next-of-kin's own (always-empty) bookings, but the linked mum's
-- consultations still didn't show up. The consultations table's existing
-- SELECT policy only covers patient_id = auth.uid() OR
-- specialist_id = auth.uid() — a next-of-kin querying by the MUM's id
-- matches neither, so RLS silently filtered every row instead of
-- erroring.
--
-- This adds an additional SELECT policy scoped to the next_of_kin_profiles
-- link. RLS policies on the same table are OR'd together, so this only
-- WIDENS visibility for a linked next-of-kin — it can't narrow the mum's
-- or specialist's own existing access.

create policy "Next of kin can view the linked mum's consultations"
on public.consultations
for select
to authenticated
using (
  exists (
    select 1 from public.next_of_kin_profiles nok
    where nok.user_id = auth.uid()
      and nok.linked_pregnant_user_id = consultations.patient_id
  )
);
