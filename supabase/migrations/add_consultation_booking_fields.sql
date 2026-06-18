-- Run in the Supabase SQL editor (after the earlier migrations).
-- Adds richer specialist/volunteer profile info for the "Select
-- Specialist/Volunteer" cards, and real booking details on consultations.

alter table public.specialist_profiles
  add column if not exists rating numeric(2, 1) default 4.9,
  add column if not exists years_experience int,
  add column if not exists helps_with text[],
  add column if not exists available_today text[];

alter table public.volunteer_profiles
  add column if not exists rating numeric(2, 1) default 4.9,
  add column if not exists years_experience int,
  add column if not exists helps_with text[],
  add column if not exists available_today text[];

alter table public.consultations
  add column if not exists scheduled_date date,
  add column if not exists scheduled_time text,
  add column if not exists purpose text,
  add column if not exists platform text default 'Zoom Meeting';
