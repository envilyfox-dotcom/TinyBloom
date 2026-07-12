-- Run in the Supabase SQL editor.
-- Adds likes for published articles (Learn tab), mirroring the Forum's
-- existing forum_likes table/RLS pattern in add_forum_tables.sql.

create table if not exists public.article_likes (
  article_id uuid not null references public.articles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (article_id, user_id)
);

alter table public.article_likes enable row level security;

drop policy if exists "Authenticated users can view article likes" on public.article_likes;
create policy "Authenticated users can view article likes"
on public.article_likes for select to authenticated using (true);

-- Matches the "Authenticated users can comment on live articles" check on
-- public_comments — can only like an article that's actually live.
drop policy if exists "Users can like published articles" on public.article_likes;
create policy "Users can like published articles"
on public.article_likes for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (select 1 from public.articles a where a.id = article_id and a.status = 'published')
);

drop policy if exists "Users can unlike their own like" on public.article_likes;
create policy "Users can unlike their own like"
on public.article_likes for delete to authenticated
using (user_id = auth.uid());
