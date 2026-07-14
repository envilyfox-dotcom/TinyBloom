-- Run in the Supabase SQL editor.
--
-- Lets a volunteer attach a Zoom (or other video) link when publishing a
-- service/session, so mums can join directly from the Notification Centre.

alter table public.volunteer_services
  add column if not exists zoom_link text;
