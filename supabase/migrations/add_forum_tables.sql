-- Run in the Supabase SQL editor.
-- Adds a basic community forum: posts, comments, and likes, with RLS so
-- any signed-in user can read everything but only manage their own content.

create table if not exists public.forum_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.forum_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.forum_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.forum_likes (
  post_id uuid not null references public.forum_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.forum_posts enable row level security;
alter table public.forum_comments enable row level security;
alter table public.forum_likes enable row level security;

-- Posts: everyone signed in can read; only the author can write/delete.
create policy "Authenticated users can view posts"
on public.forum_posts for select to authenticated using (true);

create policy "Users can create their own posts"
on public.forum_posts for insert to authenticated
with check (author_id = auth.uid());

create policy "Users can delete their own posts"
on public.forum_posts for delete to authenticated
using (author_id = auth.uid());

-- Comments: same pattern.
create policy "Authenticated users can view comments"
on public.forum_comments for select to authenticated using (true);

create policy "Users can create their own comments"
on public.forum_comments for insert to authenticated
with check (author_id = auth.uid());

create policy "Users can delete their own comments"
on public.forum_comments for delete to authenticated
using (author_id = auth.uid());

-- Likes: same pattern (a "like" is just a row the liker owns).
create policy "Authenticated users can view likes"
on public.forum_likes for select to authenticated using (true);

create policy "Users can like as themselves"
on public.forum_likes for insert to authenticated
with check (user_id = auth.uid());

create policy "Users can unlike their own like"
on public.forum_likes for delete to authenticated
using (user_id = auth.uid());
