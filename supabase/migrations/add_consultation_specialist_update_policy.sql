-- lets a specialist update only the consultations assigned to them, e.g. approving a pending appointment
create policy "Specialists can update their own consultations"
  on public.consultations
  for update
  to authenticated
  using (specialist_id = auth.uid())
  with check (specialist_id = auth.uid());
