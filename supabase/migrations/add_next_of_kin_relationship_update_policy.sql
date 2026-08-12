-- Run in the Supabase SQL editor.
--
-- Editing the relationship on an existing link (without re-entering the
-- mum's user code) needs an UPDATE on next_of_kin_profiles. Like the
-- earlier SELECT/INSERT/DELETE gaps on this table, there's no UPDATE
-- policy yet, so the update would silently affect zero rows instead of
-- erroring.
--
-- This lets a next-of-kin user update only the relationship field on
-- their own link row (linked_pregnant_user_id can't be changed this way —
-- re-linking to a different mum still goes through linkToMum's
-- delete+insert flow).

-- a next-of-kin can edit the relationship label on their own link, nothing else
create policy "Next of kin can update their own link's relationship"
on public.next_of_kin_profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
