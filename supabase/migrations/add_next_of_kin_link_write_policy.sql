-- Run in the Supabase SQL editor.
--
-- The "Link" button on the next-of-kin Link to Pregnant User screen now
-- writes to next_of_kin_profiles directly (delete any existing link for
-- this user, then insert the new one). Like the SELECT case fixed in
-- add_next_of_kin_link_policy.sql, RLS is almost certainly enabled here
-- with no INSERT/DELETE policy yet, which means the insert will likely be
-- rejected outright (a policy violation on INSERT errors loudly, unlike
-- UPDATE/DELETE which silently affect zero rows).
--
-- This lets a next-of-kin user create and remove only their own link row.

create policy "Next of kin can create their own link"
on public.next_of_kin_profiles
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Next of kin can delete their own link"
on public.next_of_kin_profiles
for delete
to authenticated
using (user_id = auth.uid());
