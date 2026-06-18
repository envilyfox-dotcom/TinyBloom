-- Run this in the Supabase SQL editor (Project → SQL Editor → New query).
-- Adds support for specialists submitting external article links with a title.

-- 1. New columns on the existing `articles` table.
--    `url`        — the external link a specialist submits (null for in-app articles).
--    `created_by` — who submitted it, so specialists can see/manage their own links.
alter table public.articles
  add column if not exists url text,
  add column if not exists created_by uuid references public.profiles(id);

-- 2. Allow authenticated specialists to insert new article links.
--    (Published immediately — there's no admin moderation screen yet.)
create policy "Specialists can submit article links"
on public.articles
for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.role = 'specialist'
  )
);

-- 3. Allow specialists to delete only the links they submitted.
create policy "Specialists can delete their own article links"
on public.articles
for delete
to authenticated
using (created_by = auth.uid());
