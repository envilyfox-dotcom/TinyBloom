-- Run in the Supabase SQL editor.
--
-- Backs the new rating feature: a mum can leave a star-only rating (no
-- comment) for a specialist after a consultation, or a volunteer after a
-- chat is closed. One row per completed interaction (unique per
-- mum/source), read by both the specialist and volunteer dashboards'
-- "User Review" section and the "View All" reviews screen.

create table if not exists public.provider_ratings (
  id uuid primary key default gen_random_uuid(),
  mum_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  provider_type text not null check (provider_type in ('specialist','volunteer')),
  source_type text not null check (source_type in ('consultation','chat')),
  source_id uuid not null,
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  unique (mum_id, source_type, source_id)
);

alter table public.provider_ratings enable row level security;

create policy "Mums can insert their own ratings"
  on public.provider_ratings for insert
  with check (auth.uid() = mum_id);

create policy "Ratings are readable by authenticated users"
  on public.provider_ratings for select
  using (auth.role() = 'authenticated');

-- Lets a "Rate {name}" notification carry which provider/interaction it's
-- for, so tapping it can open the right rating card and so
-- ensureRatingNotification() can avoid creating a duplicate prompt for the
-- same completed interaction.
alter table public.notifications
  add column if not exists rating_provider_id uuid,
  add column if not exists rating_provider_type text,
  add column if not exists rating_source_type text,
  add column if not exists rating_source_id uuid;

-- notifications has SELECT/UPDATE policies but no general INSERT policy
-- (same gap as add_volunteer_service_broadcast_policy.sql), so
-- ensureRatingNotification()'s insert was being silently blocked by RLS.
-- Scoped narrowly: a mum may only insert a 'consultation' rating-prompt row
-- for herself, not an arbitrary notification for anyone.
create policy "Mums can insert their own rating-prompt notifications"
  on public.notifications for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and type = 'consultation'
    and rating_source_type is not null
    and rating_source_id is not null
  );

-- ensureRatingNotification() is called unawaited from both the dashboard
-- load and My Consultations load, so two concurrent calls for the same
-- consultation can both pass its "not already prompted" SELECT check before
-- either INSERT lands, producing duplicate "Rate Dr X" prompts for one
-- completed consultation. A unique partial index makes the second insert
-- fail at the DB level instead — the failure is swallowed by
-- ensureRatingNotification's try/catch, which is fine since it's
-- fire-and-forget.
create unique index if not exists notifications_rating_source_uniq
  on public.notifications (user_id, rating_source_type, rating_source_id)
  where rating_source_id is not null;

-- notifications also has no DELETE policy, so submitProviderRating()'s
-- cleanup delete (removing the "Rate Dr X" prompt once the mum rates) was
-- being silently blocked by RLS — the row survived in the DB and the card
-- kept reappearing in the Notification Centre/dashboard on the next load.
-- Scoped the same way as the insert policy above: a mum may only delete her
-- own rating-prompt notification, not an arbitrary notification.
create policy "Mums can delete their own rating-prompt notifications"
  on public.notifications for delete
  to authenticated
  using (
    user_id = auth.uid()
    and type = 'consultation'
    and rating_source_type is not null
    and rating_source_id is not null
  );
