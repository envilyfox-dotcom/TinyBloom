-- Run in the Supabase SQL editor.
--
-- The volunteer-service broadcast notifications (see
-- add_volunteer_service_broadcast_policy.sql) show a "Hosted by" line in the
-- Notifications Centre detail sheet, but notifications has no column to
-- carry who triggered a global (user_id-null) broadcast — the sheet fell
-- back to the generic "A volunteer" placeholder. This lets the insert
-- record the volunteer's display name so it renders correctly.

alter table public.notifications
  add column if not exists volunteer_name text;
