-- Run after add_review_groups_schema.sql, seed_review_groups.sql, and
-- add_content_status_enum_values.sql (that one has to run by itself first,
-- see its own header). Part 2 of the specialist article review pipeline.
--
-- Reuses the existing `draft`/`published` values on the `content_status`
-- enum as-is (published = live, and the existing public-read policies
-- already handle that) and just adds the 5 in-between pipeline states.
--
-- Also drops two old policies ("Specialists can insert articles" and
-- "Specialists can update own articles") since they had no status check at
-- all — left in place, they'd let a specialist publish straight through and
-- skip review entirely, since Postgres OR's every matching policy together.
-- The replacements below keep their original "approved, active specialist"
-- check and add the missing status restriction.

-- which review group owns this article, and when it entered the publish buffer
alter table public.articles
  add column if not exists primary_group_id integer references public.review_groups(id),
  add column if not exists buffer_started_at timestamptz;

-- one row per stage-1/stage-2 review decision made on a piece of content
create table if not exists public.approvals (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  stage smallint not null check (stage in (1, 2)),
  reviewer_id uuid not null references public.profiles(id),
  decision text not null check (decision in ('approve', 'reject')),
  reject_category text check (reject_category in ('clinical', 'non_clinical')),
  reason text,
  superseded boolean not null default false,
  created_at timestamptz not null default now(),
  constraint approvals_reject_requires_reason check (
    decision = 'approve'
    or (reject_category is not null and reason is not null and length(trim(reason)) > 0)
  )
);

-- logs when someone flags a pending article as urgent, with why
create table if not exists public.emergency_pending_clicks (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  clicker_id uuid not null references public.profiles(id),
  reason text not null check (length(trim(reason)) > 0),
  category text not null check (category in ('clinical', 'non_clinical')),
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

-- internal discussion thread between reviewers on a piece of content (not shown to the public)
create table if not exists public.review_comments (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  parent_comment_id uuid references public.review_comments(id) on delete set null,
  -- Reserved for the future "notify specialists" escalation (doc §3.6/§9).
  -- Not wired up to any UI yet; FK added below once public_comments exists.
  flagged_from_comment_id uuid,
  created_at timestamptz not null default now()
);

-- public-facing comments readers leave on published articles
create table if not exists public.public_comments (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

-- link a review comment back to the public comment that triggered it (needs public_comments to exist first, hence added down here)
alter table public.review_comments
  drop constraint if exists review_comments_flagged_from_comment_id_fkey;
alter table public.review_comments
  add constraint review_comments_flagged_from_comment_id_fkey
  foreign key (flagged_from_comment_id) references public.public_comments(id) on delete set null;

-- which review groups a doctor belongs to, based on their specialty (not name-matching)
create or replace function public.doctor_group_ids(uid uuid)
returns setof integer
language sql
stable
security definer
set search_path = public
as $$
  select sgm.group_id
  from public.specialty_group_map sgm
  join public.specialist_profiles sp on sp.specialty_id = sgm.specialty_id
  where sp.user_id = uid;
$$;

-- which review groups can see a given piece of content (its primary group plus any secondary groups)
create or replace function public.content_visible_group_ids(cid uuid)
returns setof integer
language sql
stable
security definer
set search_path = public
as $$
  select a.primary_group_id from public.articles a where a.id = cid and a.primary_group_id is not null
  union
  select gsm.secondary_group_id
  from public.articles a
  join public.group_secondary_map gsm on gsm.primary_group_id = a.primary_group_id
  where a.id = cid;
$$;

-- true if this user is the article's author, or a reviewer whose group can see it
create or replace function public.can_view_review_thread(cid uuid, uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (select 1 from public.articles a where a.id = cid and a.created_by = uid)
    or exists (
      select 1 from public.doctor_group_ids(uid) dg
      where dg in (select * from public.content_visible_group_ids(cid))
    );
$$;

-- turn on RLS for all the new tables
alter table public.approvals enable row level security;
alter table public.emergency_pending_clicks enable row level security;
alter table public.review_comments enable row level security;
alter table public.public_comments enable row level security;

-- Approvals and emergency-pending clicks only get written through the
-- security-definer RPC functions in add_review_pipeline_functions.sql, so
-- there's no insert policy here on purpose — clients can't write these rows
-- directly and skip the checks those functions do.

-- reviewers who can see a piece of content's thread can see its approval decisions
drop policy if exists "Review-scope doctors can view approvals" on public.approvals;
create policy "Review-scope doctors can view approvals"
on public.approvals for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

-- same, for the emergency-flag records
drop policy if exists "Review-scope doctors can view emergency clicks" on public.emergency_pending_clicks;
create policy "Review-scope doctors can view emergency clicks"
on public.emergency_pending_clicks for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

-- same, for the internal review discussion
drop policy if exists "Review-scope doctors can view review comments" on public.review_comments;
create policy "Review-scope doctors can view review comments"
on public.review_comments for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

-- a reviewer can post in the thread for content their group can see
drop policy if exists "Review-scope doctors can comment" on public.review_comments;
create policy "Review-scope doctors can comment"
on public.review_comments for insert to authenticated
with check (author_id = auth.uid() and public.can_view_review_thread(content_id, auth.uid()));

-- anyone signed in can read public comments, but only on published articles
drop policy if exists "Authenticated users can view public comments on live articles" on public.public_comments;
create policy "Authenticated users can view public comments on live articles"
on public.public_comments for select to authenticated
using (exists (select 1 from public.articles a where a.id = content_id and a.status = 'published'));

-- anyone signed in can comment, but only on published articles
drop policy if exists "Authenticated users can comment on live articles" on public.public_comments;
create policy "Authenticated users can comment on live articles"
on public.public_comments for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (select 1 from public.articles a where a.id = content_id and a.status = 'published')
);

-- can only delete your own comment
drop policy if exists "Users can delete their own public comments" on public.public_comments;
create policy "Users can delete their own public comments"
on public.public_comments for delete to authenticated
using (user_id = auth.uid());

-- Replace the old insert/update policies on articles — they had no status
-- check at all, which meant a specialist could publish straight through and
-- skip review entirely. Public read access for published articles is
-- already handled elsewhere, so nothing to add for that here.
drop policy if exists "Specialists can submit article links" on public.articles;
drop policy if exists "Specialists can insert articles" on public.articles;
drop policy if exists "Specialists can update own articles" on public.articles;

-- an approved, active specialist can create a new article as a draft or straight into stage-1 review
drop policy if exists "Specialists can create draft submissions" on public.articles;
create policy "Specialists can create draft submissions"
on public.articles for insert to authenticated
with check (
  created_by = auth.uid()
  and status in ('draft', 'pending_approval_1')
  and exists (
    select 1 from public.profiles p
    join public.specialist_profiles sp on sp.user_id = p.id
    where p.id = auth.uid()
      and p.role = 'specialist'
      and p.is_active = true
      and sp.approval_status = 'approved'
  )
);

-- an author can edit their own article while it's still a draft or was kicked back for changes
drop policy if exists "Authors can edit and resubmit their own draft or rejected content" on public.articles;
create policy "Authors can edit and resubmit their own draft or rejected content"
on public.articles for update to authenticated
using (
  created_by = auth.uid()
  and status in ('draft', 'changes_requested')
  and exists (
    select 1 from public.profiles p
    join public.specialist_profiles sp on sp.user_id = p.id
    where p.id = auth.uid()
      and p.role = 'specialist'
      and p.is_active = true
      and sp.approval_status = 'approved'
  )
)
with check (created_by = auth.uid());

-- the author, or reviewers whose group covers it, can see an article before it's published
drop policy if exists "Review-scope doctors can view pre-live content" on public.articles;
create policy "Review-scope doctors can view pre-live content"
on public.articles for select to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1 from public.doctor_group_ids(auth.uid()) dg
    where dg in (select * from public.content_visible_group_ids(id))
  )
);
