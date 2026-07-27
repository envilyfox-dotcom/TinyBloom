-- Run in the Supabase SQL editor.
--
-- notifications has SELECT/UPDATE policies but no INSERT policy at all, so
-- the new "notify mums when a volunteer service is deleted/retimed" feature
-- (VolunteerServicesScreen._deleteService / the edit form's _handlePrimary)
-- would silently fail to insert — same class of gap as the pregnancy_logs
-- and forum_posts RLS issues fixed earlier.
--
-- Scoped narrowly on purpose: only a volunteer, only a global broadcast row
-- (user_id is null), only type='services' — this is not a general "any user
-- can insert any notification" grant, since a NULL user_id row is visible to
-- every mum in the app.

create policy "Volunteers can broadcast service update notifications"
on public.notifications
for insert
to authenticated
with check (
  user_id is null
  and type = 'services'
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'volunteer'
  )
);
