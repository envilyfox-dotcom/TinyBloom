-- Adds support for specialists submitting external article links with a title.

-- `url` is the external link a specialist submits (null for in-app articles);
-- `created_by` tracks who submitted it so they can manage their own links
alter table public.articles
  add column if not exists url text,
  add column if not exists created_by uuid references public.profiles(id);

-- lets any specialist submit a new article link — goes live right away, no moderation step yet
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

-- specialists can only delete the links they submitted themselves
create policy "Specialists can delete their own article links"
on public.articles
for delete
to authenticated
using (created_by = auth.uid());
