-- Run in the Supabase SQL editor.
-- Safe to re-run.
--
-- Mood emoji were hardcoded in the Flutter app (moodOptions in
-- logs_shared.dart), matched by exact label text. Any mood added/renamed
-- from Admin > Logs that didn't match one of those ~25 fixed labels fell
-- back to a generic clipboard icon (see moodEmoji's fallback).
--
-- This adds an `icon` column so each mood option carries its own emoji,
-- editable from Admin > Logs, and backfills it for the existing default
-- moods using the emoji they already had in moodOptions so nothing visibly
-- changes for them.

-- new column so each mood option carries its own emoji
alter table public.pregnancy_log_options
  add column if not exists icon text;

-- backfill the emoji the existing default moods already had, so nothing
-- visibly changes for them
update public.pregnancy_log_options set icon = case label
  when 'Happy' then '😊'
  when 'Excited' then '🥰'
  when 'Calm' then '😌'
  when 'Tired' then '😴'
  when 'Sad' then '😔'
  when 'Worried' then '😟'
  when 'Stressed' then '😣'
  when 'Irritable' then '😤'
  when 'Emotional' then '😢'
  when 'Unwell' then '🤢'
  when 'Neutral' then '😐'
  when 'Grateful' then '😍'
  when 'Overwhelmed' then '🥺'
  when 'Anxious' then '😬'
  when 'Hopeful' then '😇'
  when 'Loved' then '🤗'
  when 'Exhausted' then '😩'
  when 'Sick' then '🤕'
  when 'Frustrated' then '😡'
  when 'Peaceful' then '🤍'
  when 'Energetic' then '🥳'
  when 'Dizzy' then '😵'
  when 'Blessed' then '🤰'
  when 'Confident' then '😎'
  when 'Strong' then '💪'
  else icon
end
where category = 'mood';
