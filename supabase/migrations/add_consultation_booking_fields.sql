-- Run after the earlier migrations.
-- Adds richer specialist/volunteer profile info for the "Select
-- Specialist/Volunteer" cards, plus real booking details on consultations.

-- rating, experience, what they help with, and today's availability for the specialist cards
alter table public.specialist_profiles
  add column if not exists rating numeric(2, 1) default 4.9,
  add column if not exists years_experience int,
  add column if not exists helps_with text[],
  add column if not exists available_today text[];

-- same fields, but for volunteers
alter table public.volunteer_profiles
  add column if not exists rating numeric(2, 1) default 4.9,
  add column if not exists years_experience int,
  add column if not exists helps_with text[],
  add column if not exists available_today text[];

-- actual booking details once a mum schedules a consultation
alter table public.consultations
  add column if not exists scheduled_date date,
  add column if not exists scheduled_time text,
  add column if not exists purpose text,
  add column if not exists platform text default 'Zoom Meeting';
