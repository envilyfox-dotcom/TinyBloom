-- Mums were seeing "No specialists/volunteers available" even though the
-- rows existed and were verified — there was just no RLS policy letting a
-- regular signed-in user SELECT these tables, so it silently came back empty.

-- lets any signed-in user see verified specialists (not unverified ones)
create policy "Authenticated users can view verified specialists"
on public.specialist_profiles
for select
to authenticated
using (is_verified = true);

-- same, but for volunteers
create policy "Authenticated users can view verified volunteers"
on public.volunteer_profiles
for select
to authenticated
using (is_verified = true);
