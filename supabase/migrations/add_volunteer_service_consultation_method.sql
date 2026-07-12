-- Run in the Supabase SQL editor.
--
-- The service listing form now lets a volunteer pick a preferred
-- consultation method ("Chat" or "Video") per service, but
-- volunteer_services has no column to store it yet.

alter table public.volunteer_services
  add column if not exists consultation_method text;
