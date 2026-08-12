-- Run in the Supabase SQL editor.
--
-- Fixes timestamps that got saved 8 hours in the future.
--
-- Cause: Dart's `DateTime.now().toIso8601String()` gives a *naive* string
-- with no timezone marker, e.g. "2026-08-08T15:00:00.000" (JS's
-- `new Date().toISOString()` always ends in "Z", so it doesn't have this
-- problem). Postgres reads a naive string as if it were already in the
-- session timezone (UTC on Supabase), so a booking made at 15:00 Singapore
-- time got stored as 15:00 UTC instead of 07:00 UTC -- exactly 8 hours
-- ahead of when it actually happened.
--
-- The app now sends proper UTC (see dbNow() in lib/utils/singapore_time.dart),
-- so this migration is just a one-off backfill for rows written before that
-- fix. New rows are already correct.
--
-- Only 4 columns are affected -- the ones the Flutter app writes directly.
-- Anything with `default now()` is set server-side and was always right,
-- and the website writes timestamps with the correct `toISOString()`, so it's
-- untouched:
--   consultations.created_at              (bookConsultation)
--   consultations.rescheduled_at          (rescheduleConsultation)
--   volunteer_requests.call_requested_at  (requestVideoCall)
--   notification_read_receipts.read_at    (the read-receipt upserts)
--
-- Before running the fix below, it's worth sanity-checking the damage with
-- a read-only query like this (rows created in the last 8 hours are the
-- easy proof -- a row can't have been created in the future):
--
--   select 'consultations.created_at' as col,
--          count(*) as total,
--          count(*) filter (where created_at > now()) as in_the_future,
--          max(created_at) as newest
--     from public.consultations
--   union all
--   select 'consultations.rescheduled_at',
--          count(rescheduled_at),
--          count(*) filter (where rescheduled_at > now()),
--          max(rescheduled_at)
--     from public.consultations
--   union all
--   select 'volunteer_requests.call_requested_at',
--          count(call_requested_at),
--          count(*) filter (where call_requested_at > now()),
--          max(call_requested_at)
--     from public.volunteer_requests;

begin;

-- Keeps track of which one-off fixes like this have already run, so
-- re-running this file by accident can't shift the timestamps a second time.
create table if not exists public.schema_fixups (
  name text primary key,
  applied_at timestamptz not null default now()
);

-- No policies on purpose -- this is internal bookkeeping only, nobody in the
-- app should ever read or write it. RLS with zero policies blocks everyone
-- except the table owner, which is what runs this migration anyway.
alter table public.schema_fixups enable row level security;

do $$
begin
  if exists (
    select 1 from public.schema_fixups
    where name = 'fix_naive_local_timestamp_offset'
  ) then
    raise notice
      'fix_naive_local_timestamp_offset already applied - skipping.';
    return;
  end if;

  -- Shift each affected column back by the 8-hour offset described above.
  update public.consultations
  set created_at = created_at - interval '8 hours'
  where created_at is not null;

  update public.consultations
  set rescheduled_at = rescheduled_at - interval '8 hours'
  where rescheduled_at is not null;

  update public.volunteer_requests
  set call_requested_at = call_requested_at - interval '8 hours'
  where call_requested_at is not null;

  -- This table isn't created by a migration in this folder, so it might not
  -- exist yet in every environment -- skip it rather than error out.
  if to_regclass('public.notification_read_receipts') is not null then
    execute $sql$
      update public.notification_read_receipts
      set read_at = read_at - interval '8 hours'
      where read_at is not null
    $sql$;
  end if;

  -- Mark this fix as done so it can't run twice.
  insert into public.schema_fixups (name)
  values ('fix_naive_local_timestamp_offset');
end $$;

commit;

-- created_at is the one column here the app still sends on every insert, so
-- give it a server default too -- that way a future client bug can't cause
-- the same problem again, and the app can eventually stop sending it.
alter table public.consultations
  alter column created_at set default now();

-- Rollback, in case the diagnostic query above gets misread and this needs
-- to be undone -- shifts everything forward again and clears the marker so
-- the fix can be re-applied later:
--
--   begin;
--   update public.consultations
--     set created_at = created_at + interval '8 hours'
--     where created_at is not null;
--   update public.consultations
--     set rescheduled_at = rescheduled_at + interval '8 hours'
--     where rescheduled_at is not null;
--   update public.volunteer_requests
--     set call_requested_at = call_requested_at + interval '8 hours'
--     where call_requested_at is not null;
--   update public.notification_read_receipts
--     set read_at = read_at + interval '8 hours'
--     where read_at is not null;
--   delete from public.schema_fixups
--     where name = 'fix_naive_local_timestamp_offset';
--   commit;
