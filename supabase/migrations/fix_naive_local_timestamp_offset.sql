-- Run in the Supabase SQL editor.
--
-- Corrects timestamps the Flutter app wrote 8 hours into the future.
--
-- Dart's `DateTime.now().toIso8601String()` returns a *naive* string with
-- no zone marker -- "2026-08-08T15:00:00.000" -- unlike JavaScript's
-- `new Date().toISOString()`, which always ends in "Z". Postgres reads a
-- naive string in the session timezone (UTC on Supabase), so a booking made
-- at 15:00 Singapore time was stored as 15:00 UTC. The true instant was
-- 07:00 UTC, which means every affected value sits exactly +8h ahead of
-- reality and has to be moved back.
--
-- The app has been fixed to send UTC (see dbNow() in
-- lib/utils/singapore_time.dart), so this is a one-off backfill of the rows
-- written before that change. New rows are already correct.
--
-- ── Which rows are affected ─────────────────────────────────────────
--
-- Only the columns the Flutter app writes explicitly. Anything filled by a
-- `default now()` is server-side and was always right, and the website
-- writes its timestamps with `new Date().toISOString()`, which is correct.
--
--   consultations.created_at            written by bookConsultation
--   consultations.rescheduled_at        written by rescheduleConsultation
--   volunteer_requests.call_requested_at  written by requestVideoCall
--   notification_read_receipts.read_at  written by the two read-receipt
--                                       upserts in the dashboard and the
--                                       notifications centre
--
-- Every one of those four is written *only* by the Flutter app -- the
-- website has no consultation, reschedule, video-call or read-receipt UI,
-- and the seed scripts don't touch these tables. So each non-null value is
-- shifted and the correction below is unconditional.
--
-- ── Before you run it ───────────────────────────────────────────────
--
-- Sanity-check the damage first. This is read-only; run it on its own and
-- confirm the "future" counts look like real rows rather than zero:
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
--
-- Rows created within the last 8 hours are the provable cases: a row can't
-- have been created in the future. Older rows are shifted by the same
-- amount but can't be spotted that way, which is why the fix keys off the
-- column rather than a timestamp predicate.

begin;

-- Bookkeeping, so re-running this file can't subtract another 8 hours.
-- Nothing else in the schema depends on this table; it exists purely as a
-- guard for one-off data repairs like this one.
create table if not exists public.schema_fixups (
  name text primary key,
  applied_at timestamptz not null default now()
);

-- Deny-all for anon/authenticated: this is server-side bookkeeping and no
-- client has any business reading or writing it. Deliberately no policies —
-- RLS with none defined denies everything. The SQL editor runs as the table
-- owner, which bypasses RLS, so the insert at the end of this file still
-- works.
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

  update public.consultations
  set created_at = created_at - interval '8 hours'
  where created_at is not null;

  update public.consultations
  set rescheduled_at = rescheduled_at - interval '8 hours'
  where rescheduled_at is not null;

  update public.volunteer_requests
  set call_requested_at = call_requested_at - interval '8 hours'
  where call_requested_at is not null;

  -- This table is created outside the migrations in this folder, so it may
  -- not exist in every environment.
  if to_regclass('public.notification_read_receipts') is not null then
    execute $sql$
      update public.notification_read_receipts
      set read_at = read_at - interval '8 hours'
      where read_at is not null
    $sql$;
  end if;

  insert into public.schema_fixups (name)
  values ('fix_naive_local_timestamp_offset');
end $$;

commit;

-- ── Keeping it fixed ────────────────────────────────────────────────
--
-- `created_at` is the one column here the app still sends on every insert.
-- Giving it a server-side default means a future client bug can't reproduce
-- this, and lets the app drop the field from bookConsultation entirely.
alter table public.consultations
  alter column created_at set default now();

-- ── Rollback ────────────────────────────────────────────────────────
--
-- If the diagnostic turns out to have been misread, this undoes the shift
-- and clears the marker so the file can be run again later:
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
