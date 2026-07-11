-- Run in the Supabase SQL editor.
--
-- Publishing a volunteer service fails with:
--   "new row violates row-level security policy for table volunteer_services"
-- RLS is enabled on the table but there's no policy letting a volunteer
-- insert/update/delete their own rows (lib/screens/volunteer/volunteer_services_screen.dart
-- always sets volunteer_id = auth.uid() on insert).

create policy "Volunteers can insert their own services"
on public.volunteer_services
for insert
to authenticated
with check (volunteer_id = auth.uid());

create policy "Volunteers can view their own services"
on public.volunteer_services
for select
to authenticated
using (volunteer_id = auth.uid());

create policy "Volunteers can update their own services"
on public.volunteer_services
for update
to authenticated
using (volunteer_id = auth.uid())
with check (volunteer_id = auth.uid());

create policy "Volunteers can delete their own services"
on public.volunteer_services
for delete
to authenticated
using (volunteer_id = auth.uid());
