-- Run in the Supabase SQL editor.
--
-- Allow specialists to update their own consultation rows, for example when
-- approving a pending appointment.

create policy "Specialists can update their own consultations"
  on public.consultations
  for update
  to authenticated
  using (specialist_id = auth.uid())
  with check (specialist_id = auth.uid());
