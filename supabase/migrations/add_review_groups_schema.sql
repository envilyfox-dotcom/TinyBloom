-- Run in the Supabase SQL editor.
-- First part of the specialist article review pipeline: sets up the 5
-- review groups from Article_System_specialist.md §2.
-- specialist_profiles.specialization is a fixed dropdown (no free text, no
-- typos), so we can map it to a specialty_id FK via exact match and keep it
-- synced with a trigger below, instead of matching strings at query time.

-- master list of specialties (matches the registration form's dropdown)
create table if not exists public.specialties (
  id serial primary key,
  name text not null unique
);

-- the 5 groups doctors get bucketed into for review purposes
create table if not exists public.review_groups (
  id serial primary key,
  name text not null unique
);

-- Many-to-many so a specialty can map to more than one group in the future,
-- even though today every specialty has exactly one primary group.
create table if not exists public.specialty_group_map (
  specialty_id integer not null references public.specialties(id) on delete cascade,
  group_id integer not null references public.review_groups(id) on delete cascade,
  primary key (specialty_id, group_id)
);

-- Primary group -> its eligible secondary group(s) for the approval-2 pool.
create table if not exists public.group_secondary_map (
  primary_group_id integer not null references public.review_groups(id) on delete cascade,
  secondary_group_id integer not null references public.review_groups(id) on delete cascade,
  primary key (primary_group_id, secondary_group_id)
);

-- points each specialist at their derived review-group specialty
alter table public.specialist_profiles
  add column if not exists specialty_id integer references public.specialties(id);

alter table public.specialties enable row level security;
alter table public.review_groups enable row level security;
alter table public.specialty_group_map enable row level security;
alter table public.group_secondary_map enable row level security;

-- Reference data — readable by any signed-in user (needed for pickers and
-- for deriving group membership client-side for display purposes).
drop policy if exists "Authenticated users can view specialties" on public.specialties;
create policy "Authenticated users can view specialties"
on public.specialties for select to authenticated using (true);

drop policy if exists "Authenticated users can view review groups" on public.review_groups;
create policy "Authenticated users can view review groups"
on public.review_groups for select to authenticated using (true);

drop policy if exists "Authenticated users can view specialty group map" on public.specialty_group_map;
create policy "Authenticated users can view specialty group map"
on public.specialty_group_map for select to authenticated using (true);

drop policy if exists "Authenticated users can view group secondary map" on public.group_secondary_map;
create policy "Authenticated users can view group secondary map"
on public.group_secondary_map for select to authenticated using (true);

-- Keep specialty_id in sync with specialization automatically, for both the
-- website's registration flow and any app-side edits — specialization is
-- the single fixed-dropdown source of truth; specialty_id is just its FK
-- resolution, never set independently by any client.
create or replace function public.sync_specialist_specialty_id()
returns trigger
language plpgsql
as $$
begin
  -- OLD is null on INSERT, so this also covers first-time registration.
  if new.specialization is distinct from old.specialization then
    select id into new.specialty_id
    from public.specialties
    where name = new.specialization;
  end if;
  return new;
end;
$$;

drop trigger if exists specialist_profiles_sync_specialty_id on public.specialist_profiles;
create trigger specialist_profiles_sync_specialty_id
before insert or update of specialization on public.specialist_profiles
for each row execute function public.sync_specialist_specialty_id();
