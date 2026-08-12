-- The old SELECT policy only let a volunteer read their own services, which
-- is why mums browsing the Volunteer Consultation list saw "Services
-- Provided" come back empty for everyone. This adds a second policy
-- (policies for the same command get OR'd together), so any authenticated
-- user can see a service that's published as available, while non-available
-- ones stay private to the volunteer who owns them.
create policy "Authenticated users can view available volunteer services"
on public.volunteer_services
for select
to authenticated
using (status = 'available');
