-- Run in the Supabase SQL editor.
-- Safe to re-run: every step below is idempotent, so this can be pasted
-- again even if a previous attempt partially applied (e.g. an earlier,
-- differently-shaped `learn_tags` table already exists in your project).

-- Mood joins Symptoms/Milestones in pregnancy_log_options. Mood used to be
-- hardcoded in the Flutter app (moodOptions in logs_shared.dart) -- that
-- list stays for emoji/colour styling (moodEmoji/moodColor), but the set of
-- selectable moods now comes from this table, same as Symptoms/Milestones,
-- so it can be managed from the new Admin > Logs page instead of needing an
-- app release.
alter table public.pregnancy_log_options
  drop constraint if exists pregnancy_log_options_category_check;

alter table public.pregnancy_log_options
  add constraint pregnancy_log_options_category_check
  check (category in ('mood', 'symptom', 'milestone'));

-- The table was select-only for `authenticated` (edits were expected to
-- happen via the Supabase dashboard, which uses the postgres role and
-- bypasses RLS). The admin website now needs to write to it as a normal
-- logged-in admin, so add an admin-only "do anything" policy alongside the
-- existing read policy.
drop policy if exists "Admins can manage pregnancy log options" on public.pregnancy_log_options;
create policy "Admins can manage pregnancy log options"
  on public.pregnancy_log_options for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Seed the default mood options.
insert into public.pregnancy_log_options (category, label, sort_order) values
  ('mood', 'Happy', 0),
  ('mood', 'Excited', 1),
  ('mood', 'Calm', 2),
  ('mood', 'Tired', 3),
  ('mood', 'Sad', 4),
  ('mood', 'Worried', 5),
  ('mood', 'Stressed', 6),
  ('mood', 'Irritable', 7),
  ('mood', 'Emotional', 8),
  ('mood', 'Unwell', 9),
  ('mood', 'Neutral', 10),
  ('mood', 'Grateful', 11),
  ('mood', 'Overwhelmed', 12),
  ('mood', 'Anxious', 13),
  ('mood', 'Hopeful', 14),
  ('mood', 'Loved', 15),
  ('mood', 'Exhausted', 16),
  ('mood', 'Sick', 17),
  ('mood', 'Frustrated', 18),
  ('mood', 'Peaceful', 19),
  ('mood', 'Energetic', 20),
  ('mood', 'Dizzy', 21),
  ('mood', 'Blessed', 22),
  ('mood', 'Confident', 23),
  ('mood', 'Strong', 24)
on conflict (category, label) do nothing;

-- Learn tags become a managed table too.
--
-- Today the specialist Create/Edit Article "tags" picker just shows whatever
-- tags already happen to exist across current articles (getArticleCategories
-- in supabase_service.dart), plus the 3 fixed trimester tags. That's freeform
-- and has needed several manual cleanup migrations (cleanup_noisy_article_tags*)
-- to de-dupe/normalize. This table replaces that with a real, admin-managed
-- list, surfaced on the new Admin > Logs > Learn page.
--
-- Trimester tags ('1st/2nd/3rd Trimester') are deliberately NOT seeded here
-- -- they stay as the separate SupabaseService.trimesterTags constant, which
-- also drives the `trimester` column/derivation logic in edit_article_content
-- and getArticleCategories. Adding them here too would just duplicate them
-- in the tag picker.
--
-- Seed values below are a starting set inferred from the app's existing
-- content (seed_test_articles.sql categories + the Education tab's own
-- description text) -- worth checking against whatever tags are actually
-- live on production articles and adding any missing ones from the admin
-- page.

-- Create the table fresh, or fix up an earlier attempt that used the old
-- display_order/is_active shape (from a draft admin_logs table set) instead
-- of sort_order.
do $$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'learn_tags'
  ) then
    create table public.learn_tags (
      id uuid primary key default gen_random_uuid(),
      label text not null,
      sort_order int not null default 0,
      created_at timestamptz not null default now()
    );
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'learn_tags' and column_name = 'display_order'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'learn_tags' and column_name = 'sort_order'
  ) then
    alter table public.learn_tags rename column display_order to sort_order;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'learn_tags' and column_name = 'sort_order'
  ) then
    alter table public.learn_tags add column sort_order int not null default 0;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'learn_tags' and column_name = 'is_active'
  ) then
    alter table public.learn_tags drop column is_active;
  end if;
end $$;

-- Stop the same tag label being added twice.
create unique index if not exists learn_tags_label_key on public.learn_tags (label);

alter table public.learn_tags enable row level security;

-- Any logged-in user can see the tag list (needed for the article tag picker).
drop policy if exists "Anyone can read learn tags" on public.learn_tags;
create policy "Anyone can read learn tags"
  on public.learn_tags for select
  to authenticated
  using (true);

-- Only admins can add/edit/remove tags.
drop policy if exists "Admins can manage learn tags" on public.learn_tags;
create policy "Admins can manage learn tags"
  on public.learn_tags for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Seed a starting set of learn tags.
insert into public.learn_tags (label, sort_order) values
  ('Nutrition', 0),
  ('Pregnancy', 1),
  ('Wellness', 2),
  ('Fitness', 3),
  ('Baby Development', 4),
  ('Postpartum', 5),
  ('Mental Health', 6),
  ('General', 7)
on conflict (label) do nothing;

-- Optional cleanup: if an earlier draft also created mood_tags, symptom_tags
-- and/or baby_milestone_tags tables, they're dead now -- nothing in the app
-- or admin site reads from them (Mood/Symptoms/Baby Milestones all live in
-- pregnancy_log_options instead). Uncomment and run separately if you want
-- them gone:
--
-- drop table if exists public.mood_tags;
-- drop table if exists public.symptom_tags;
-- drop table if exists public.baby_milestone_tags;
