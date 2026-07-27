-- Run in the Supabase SQL editor.
--
-- next_of_kin_profiles has no updated_at column, so editing the
-- relationship (add_next_of_kin_relationship_update_policy.sql) leaves no
-- trace of when that last happened. Same pattern as checklist_items'
-- updated_at (add_checklist_tables.sql): a trigger keeps it current on
-- every update instead of relying on the app to remember to set it.

alter table public.next_of_kin_profiles
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.set_next_of_kin_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_next_of_kin_profiles_updated_at
  on public.next_of_kin_profiles;
create trigger trg_next_of_kin_profiles_updated_at
before update on public.next_of_kin_profiles
for each row execute function public.set_next_of_kin_profiles_updated_at();
