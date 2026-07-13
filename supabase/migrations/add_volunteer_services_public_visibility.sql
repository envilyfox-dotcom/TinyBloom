-- Run in the Supabase SQL editor.
--
-- The earlier volunteer_services SELECT policy only let the owning
-- volunteer read their own rows (volunteer_id = auth.uid()). That's why a
-- mum browsing the Volunteer Consultation list sees "Services Provided"
-- come back empty for every volunteer — RLS silently drops all rows for
-- anyone who isn't that specific volunteer.
--
-- This adds a second policy (policies for the same command are OR'd
-- together) so any authenticated user can see a service that's currently
-- published as available, while non-available ones stay private to the
-- volunteer who owns them.

create policy "Authenticated users can view available volunteer services"
on public.volunteer_services
for select
to authenticated
using (status = 'available');
