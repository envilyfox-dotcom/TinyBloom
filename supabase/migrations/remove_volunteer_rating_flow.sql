-- Volunteer chats no longer create or accept provider ratings. Keep existing
-- specialist ratings and any historical volunteer rows, but prevent new
-- volunteer ratings and rating prompts at the database boundary.

drop policy if exists "Mums can insert their own ratings"
  on public.provider_ratings;

create policy "Mums can insert their own ratings"
  on public.provider_ratings for insert
  to authenticated
  with check (
    auth.uid() = mum_id
    and provider_type = 'specialist'
  );

drop policy if exists "Mums can insert their own rating-prompt notifications"
  on public.notifications;

create policy "Mums can insert their own rating-prompt notifications"
  on public.notifications for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and type = 'consultation'
    and rating_provider_type = 'specialist'
    and rating_source_type is not null
    and rating_source_id is not null
  );
