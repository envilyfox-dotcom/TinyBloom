-- Run in the Supabase SQL editor.
--
-- pregnancy_logs has RLS enabled but only ever got the next-of-kin SELECT
-- policy (add_next_of_kin_pregnancy_logs_policy.sql). There was never a
-- policy letting a mum read/write her own logs, so every insert from
-- CreateLogScreen has been rejected with 42501 (row-level security
-- violation) regardless of app-side code. Mirrors the mum-owner policies
-- already on pregnancy_profiles.

create policy "Mums can insert own pregnancy logs"
on public.pregnancy_logs
for insert
to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role in ('free_user', 'premium_user')
  )
);

create policy "Mums can view own pregnancy logs"
on public.pregnancy_logs
for select
to authenticated
using (
  auth.uid() = user_id
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role in ('free_user', 'premium_user')
  )
);

create policy "Mums can update own pregnancy logs"
on public.pregnancy_logs
for update
to authenticated
using (
  auth.uid() = user_id
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role in ('free_user', 'premium_user')
  )
)
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role in ('free_user', 'premium_user')
  )
);

create policy "Mums can delete own pregnancy logs"
on public.pregnancy_logs
for delete
to authenticated
using (
  auth.uid() = user_id
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
      and profiles.role in ('free_user', 'premium_user')
  )
);
