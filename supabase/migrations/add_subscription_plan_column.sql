-- Run in the Supabase SQL editor.
-- Tracks which premium plan (monthly/yearly) a mum is on, so "Change Plan"
-- can show and switch between them. Null means not on a premium plan.

alter table public.profiles
  add column if not exists subscription_plan text;
