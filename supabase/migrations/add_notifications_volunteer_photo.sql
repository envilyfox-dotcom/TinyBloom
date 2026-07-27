-- Run in the Supabase SQL editor.
--
-- Companion to add_notifications_volunteer_name.sql — the notification card
-- avatar looks for volunteer_photo_url (see _notificationLeading in
-- notifications_screen.dart) so the volunteer's real photo shows instead of
-- a plain initial circle.

alter table public.notifications
  add column if not exists volunteer_photo_url text;
