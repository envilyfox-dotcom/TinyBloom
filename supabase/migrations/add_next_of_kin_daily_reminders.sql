-- Run in the Supabase SQL editor.
--
-- Daily reminders for next-of-kin were previously just static cards the
-- Flutter app regenerated fresh every time the Notifications Centre was
-- opened (timestamped "now" on every load, so they never felt like a real
-- daily notification). This moves the reminder catalog into the database
-- and adds a per-user, per-day "send" log so:
--   1. reopening the app the same day shows the same reminders with their
--      real send time instead of resetting to "Just now" every time, and
--   2. a scheduled job can "send" (materialize) each day's reminders once,
--      for every linked next-of-kin, without the app needing to be open.
--
-- There's no push-notification delivery here (this app has no Firebase/APNs
-- integration) — "sending" means the reminder becomes visible in the
-- in-app Notifications Centre for that day. Real OS push notifications
-- would be a separate, larger addition (FCM + device tokens + a scheduled
-- Edge Function).

create table if not exists public.daily_reminder_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null unique,
  -- May contain the literal placeholder {name}, substituted client-side
  -- with the linked mum's name (kept out of SQL so a name change doesn't
  -- require touching already-sent rows).
  subtitle_template text not null,
  icon_name text not null,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_reminder_sends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  template_id uuid not null references public.daily_reminder_templates(id) on delete cascade,
  sent_date date not null default current_date,
  created_at timestamptz not null default now(),
  unique (user_id, template_id, sent_date)
);

alter table public.daily_reminder_templates enable row level security;
alter table public.daily_reminder_sends enable row level security;

create policy "Authenticated users can view active reminder templates"
on public.daily_reminder_templates for select to authenticated
using (is_active);

create policy "Users can view their own reminder sends"
on public.daily_reminder_sends for select to authenticated
using (user_id = auth.uid());

-- Idempotently "sends" today's active reminders to the CALLING next-of-kin
-- user only. The app calls this on every Notifications Centre load as a
-- safety net, so reminders still appear even if the cron job below hasn't
-- run yet (or pg_cron isn't available on this project).
create or replace function public.ensure_my_daily_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.next_of_kin_profiles where user_id = auth.uid()
  ) then
    return;
  end if;

  insert into public.daily_reminder_sends (user_id, template_id, sent_date)
  select auth.uid(), t.id, current_date
  from public.daily_reminder_templates t
  where t.is_active
  on conflict (user_id, template_id, sent_date) do nothing;
end;
$$;

revoke all on function public.ensure_my_daily_reminders() from public;
grant execute on function public.ensure_my_daily_reminders() to authenticated;

-- Cron target: sends today's reminders to EVERY linked next-of-kin at once.
-- Not granted to authenticated — only the scheduler (or an admin/service
-- role) should be able to trigger a blanket send like this.
create or replace function public.send_daily_reminders_to_next_of_kin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.daily_reminder_sends (user_id, template_id, sent_date)
  select nok.user_id, t.id, current_date
  from public.next_of_kin_profiles nok
  cross join public.daily_reminder_templates t
  where t.is_active
  on conflict (user_id, template_id, sent_date) do nothing;
end;
$$;

revoke all on function public.send_daily_reminders_to_next_of_kin() from public;

-- Schedules the daily send. Requires the pg_cron extension — on Supabase
-- this is usually enabled from Database > Extensions if the line below
-- errors with "extension pg_cron is not available".
create extension if not exists pg_cron;

select cron.schedule(
  'send-daily-reminders-to-next-of-kin',
  '0 8 * * *', -- 8:00 AM UTC daily — adjust the hour to your users' timezone
  $$select public.send_daily_reminders_to_next_of_kin();$$
);

-- Seed catalog — matches the 4 reminders previously hardcoded in the app.
insert into public.daily_reminder_templates
  (title, subtitle_template, icon_name, display_order)
values
  ('Check In Today',
   'See how {name} is feeling today — a quick message can mean a lot.',
   'favorite_border', 1),
  ('Watch for Warning Signs',
   'Stay alert to changes in {name}''s symptoms and reach out if anything feels off.',
   'visibility_outlined', 2),
  ('Appointment Support',
   'Help {name} prepare questions and notes for her next consultation.',
   'event_note_outlined', 3),
  ('Encourage Rest & Hydration',
   'A gentle reminder to check that {name} is resting and drinking enough water today.',
   'water_drop_outlined', 4)
on conflict (title) do nothing;
