-- Run in the Supabase SQL editor.
--
-- Publishing a volunteer service fails with:
--   "new row violates row-level security policy for table volunteer_services"
-- RLS is enabled on the table but there's no policy letting a volunteer
-- insert/update/delete their own rows (lib/screens/volunteer/volunteer_services_screen.dart
-- always sets volunteer_id = auth.uid() on insert).

-- volunteers can create their own service listings
create policy "Volunteers can insert their own services"
on public.volunteer_services
for insert
to authenticated
with check (volunteer_id = auth.uid());

-- volunteers can see their own listings (needed so the form can load them back)
create policy "Volunteers can view their own services"
on public.volunteer_services
for select
to authenticated
using (volunteer_id = auth.uid());

-- volunteers can edit their own listings
create policy "Volunteers can update their own services"
on public.volunteer_services
for update
to authenticated
using (volunteer_id = auth.uid())
with check (volunteer_id = auth.uid());

-- volunteers can remove their own listings
create policy "Volunteers can delete their own services"
on public.volunteer_services
for delete
to authenticated
using (volunteer_id = auth.uid());
