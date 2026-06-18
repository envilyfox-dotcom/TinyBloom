-- Run in the Supabase SQL editor.
--
-- Your specialist_profiles/volunteer_profiles rows were confirmed seeded
-- correctly (is_verified = true), but mums still see "No specialists/
-- volunteers available." The query itself is valid (verified directly via
-- REST), so the most likely cause is that there's no Row Level Security
-- policy letting a regular authenticated mum SELECT these tables at all —
-- only RLS-permitted rows are ever returned, everything else silently
-- comes back empty rather than as an error.
--
-- This adds a policy so any authenticated user can see *verified* provider
-- profiles (not unverified ones), which is what "Select Specialist" /
-- "Select Volunteer" needs.

create policy "Authenticated users can view verified specialists"
on public.specialist_profiles
for select
to authenticated
using (is_verified = true);

create policy "Authenticated users can view verified volunteers"
on public.volunteer_profiles
for select
to authenticated
using (is_verified = true);
