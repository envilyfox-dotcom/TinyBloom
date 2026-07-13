-- Run in the Supabase SQL editor.
--
-- getLinkedMum() makes a second, best-effort query against pregnancy_profiles
-- to get the linked mum's due_date/current_week (used for "Week N of
-- Pregnancy" on the next-of-kin dashboard). This was flagged as a likely
-- gap when getLinkedMum() was first written — pregnancy_profiles almost
-- certainly only has a SELECT policy for auth.uid() = user_id (the mum
-- reading her own row), so it comes back empty for a next-of-kin instead
-- of erroring, showing "Week 0 / No pregnancy details available yet" even
-- when the mum has real data.
--
-- Same scoped pattern as the other next-of-kin policies — only readable
-- for a mum the requester is actually linked to.

create policy "Next of kin can view linked mum's pregnancy profile"
on public.pregnancy_profiles
for select
to authenticated
using (
  exists (
    select 1 from public.next_of_kin_profiles nok
    where nok.linked_pregnant_user_id = pregnancy_profiles.user_id
      and nok.user_id = auth.uid()
  )
);
