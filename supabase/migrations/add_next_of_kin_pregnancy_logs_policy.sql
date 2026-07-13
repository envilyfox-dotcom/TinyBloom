-- Run in the Supabase SQL editor.
--
-- The next-of-kin Logs screen now reads a linked mum's pregnancy_logs via
-- getLogsForPatient(). Like next_of_kin_profiles and pregnancy_profiles
-- before it, pregnancy_logs almost certainly only has a SELECT policy for
-- auth.uid() = user_id (the mum reading her own logs), which would make
-- this come back empty for a next-of-kin rather than erroring.
--
-- This lets a next-of-kin read logs for a mum they're actually linked to,
-- scoped the same way as the earlier gift-subscription policy — via an
-- exists() check against next_of_kin_profiles, not a blanket grant.

create policy "Next of kin can view linked mum's pregnancy logs"
on public.pregnancy_logs
for select
to authenticated
using (
  exists (
    select 1 from public.next_of_kin_profiles nok
    where nok.linked_pregnant_user_id = pregnancy_logs.user_id
      and nok.user_id = auth.uid()
  )
);
