-- Run in the Supabase SQL editor.
--
-- A next-of-kin account's link row was confirmed to exist in
-- next_of_kin_profiles (user_id correctly pointing at the logged-in user),
-- yet the app's Profile page and Link to Pregnant User screen both showed
-- "not linked." The query itself is valid (verified directly via REST), so
-- the cause is that next_of_kin_profiles has RLS enabled with no SELECT
-- policy at all — rows are silently filtered to empty for every requester,
-- including the row's own owner, rather than erroring. Supabase Studio's
-- Table Editor runs as the postgres superuser and bypasses RLS, which is why
-- the row was visible there but not through the app.
--
-- This lets a next-of-kin user read their own link row.

create policy "Next of kin can view their own link"
on public.next_of_kin_profiles
for select
to authenticated
using (user_id = auth.uid());
