-- Run in the Supabase SQL editor.
--
-- The original SELECT policy checked "is this user a volunteer?" via a
-- subquery against public.profiles. That subquery is itself subject to
-- profiles' own RLS — if profiles has no policy letting a user read their
-- own row, the subquery silently returns nothing, so the check fails for
-- every volunteer even though they really are one. A mum viewing her own
-- question was unaffected (patient_id = auth.uid() alone is enough), which
-- is exactly the lopsided symptom we saw: her own row invisible to no one,
-- but volunteers seeing nothing at all.
--
-- Fix: drop the profiles dependency entirely. This is an open board, so any
-- authenticated user (mum or volunteer) can simply see every question.

drop policy if exists "Owner or any volunteer can view volunteer requests"
  on public.volunteer_requests;

create policy "Any authenticated user can view volunteer requests"
on public.volunteer_requests
for select
to authenticated
using (true);

-- Same profiles-subquery problem would silently block every reply too, so
-- fix it the same way. (The separate "amend own pending question" policy
-- is unaffected — it never touched profiles.)
drop policy if exists "Volunteers can respond to volunteer requests"
  on public.volunteer_requests;

create policy "Authenticated users can respond to volunteer requests"
on public.volunteer_requests
for update
to authenticated
using (true)
with check (true);
