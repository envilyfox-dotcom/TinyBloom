-- Run in the Supabase SQL editor, after add_review_groups_schema.sql,
-- seed_review_groups.sql, and add_content_status_enum_values.sql (that one
-- MUST be run by itself first — see its header comment).
-- Part 2 of the specialist article review pipeline (Article_System_specialist.md).
--
-- `articles.status` is the existing `content_status` enum. This pipeline
-- reuses its existing `draft` and `published` values as-is — `published`
-- IS the doc's "live" state, so the existing public-read policies
-- (`articles_public_read`, "Everyone can read published articles") already
-- correctly gate public visibility and are left untouched. Only the 5
-- intermediate pipeline states are new (added by
-- add_content_status_enum_values.sql).
--
-- This migration also DROPS two pre-existing policies —
-- "Specialists can insert articles" and "Specialists can update own
-- articles" — because they had no restriction on `status` at all. Since
-- Postgres OR's every permissive policy for the same command together,
-- leaving them in place would let a specialist insert/update straight to
-- `published` and completely bypass peer review, regardless of the
-- draft-only policies added here. Their replacements below fold in the same
-- "approved, active specialist" check the originals had, plus the missing
-- status restriction.

-- 1. Extend articles with review-pipeline fields.
alter table public.articles
  add column if not exists primary_group_id integer references public.review_groups(id),
  add column if not exists buffer_started_at timestamptz;

-- 2. Review pipeline tables.
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

create table if not exists public.emergency_pending_clicks (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  clicker_id uuid not null references public.profiles(id),
  reason text not null check (length(trim(reason)) > 0),
  category text not null check (category in ('clinical', 'non_clinical')),
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

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

create table if not exists public.public_comments (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.articles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.review_comments
  drop constraint if exists review_comments_flagged_from_comment_id_fkey;
alter table public.review_comments
  add constraint review_comments_flagged_from_comment_id_fkey
  foreign key (flagged_from_comment_id) references public.public_comments(id) on delete set null;

-- 3. Helper functions — derive a doctor's review-group membership and a
-- piece of content's visible groups from the formal specialty tables, never
-- from name-matching (doc §7.6).
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

-- 4. RLS.
alter table public.approvals enable row level security;
alter table public.emergency_pending_clicks enable row level security;
alter table public.review_comments enable row level security;
alter table public.public_comments enable row level security;

-- Approvals / emergency-pending clicks are written exclusively through the
-- security-definer RPC functions in add_review_pipeline_functions.sql (owned
-- by a role that bypasses RLS) — no insert policy is granted here, so a
-- client can never write these rows directly and skip the business-rule
-- checks those functions enforce.
drop policy if exists "Review-scope doctors can view approvals" on public.approvals;
create policy "Review-scope doctors can view approvals"
on public.approvals for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

drop policy if exists "Review-scope doctors can view emergency clicks" on public.emergency_pending_clicks;
create policy "Review-scope doctors can view emergency clicks"
on public.emergency_pending_clicks for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

drop policy if exists "Review-scope doctors can view review comments" on public.review_comments;
create policy "Review-scope doctors can view review comments"
on public.review_comments for select to authenticated
using (public.can_view_review_thread(content_id, auth.uid()));

drop policy if exists "Review-scope doctors can comment" on public.review_comments;
create policy "Review-scope doctors can comment"
on public.review_comments for insert to authenticated
with check (author_id = auth.uid() and public.can_view_review_thread(content_id, auth.uid()));

drop policy if exists "Authenticated users can view public comments on live articles" on public.public_comments;
create policy "Authenticated users can view public comments on live articles"
on public.public_comments for select to authenticated
using (exists (select 1 from public.articles a where a.id = content_id and a.status = 'published'));

drop policy if exists "Authenticated users can comment on live articles" on public.public_comments;
create policy "Authenticated users can comment on live articles"
on public.public_comments for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (select 1 from public.articles a where a.id = content_id and a.status = 'published')
);

drop policy if exists "Users can delete their own public comments" on public.public_comments;
create policy "Users can delete their own public comments"
on public.public_comments for delete to authenticated
using (user_id = auth.uid());

-- 5. Articles: replace the old unrestricted-status insert/update policies
-- with ones that also enforce the review pipeline's status rules, and scope
-- pre-publish visibility to the author + primary/secondary group (doc
-- §7.5, §7.6). Public visibility for `status = 'published'` is already
-- handled by the pre-existing `articles_public_read` / "Everyone can read
-- published articles" policies — nothing to add there.
drop policy if exists "Specialists can submit article links" on public.articles;
drop policy if exists "Specialists can insert articles" on public.articles;
drop policy if exists "Specialists can update own articles" on public.articles;

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
