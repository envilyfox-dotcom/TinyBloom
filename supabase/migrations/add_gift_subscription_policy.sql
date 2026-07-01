-- Run in the Supabase SQL editor.
--
-- Superseded approach: the original version of this file added a plain
-- UPDATE policy letting a linked next-of-kin update the mum's profiles row.
-- That's broader than intended — RLS filters which ROWS a policy applies
-- to, not which COLUMNS get written, and column-level GRANTs are shared by
-- every caller of that table (including the mum editing her own profile),
-- so there's no way to say "self-edits can touch any column, but a linked
-- next-of-kin may only touch subscription_plan/role" using RLS + GRANT
-- alone without also breaking the mum's own Edit Profile screen.
--
-- Instead, this exposes a single narrow RPC function that performs exactly
-- the gifting operation (and nothing else), checks the link itself, and
-- runs as SECURITY DEFINER so it can write the target row without needing a
-- general-purpose UPDATE policy on profiles at all.

drop policy if exists "Next of kin can gift subscription to linked mum" on public.profiles;

create or replace function public.gift_subscription_to_linked_mum(mum_id uuid, plan text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if plan not in ('premium_monthly', 'premium_yearly') then
    raise exception 'Invalid plan';
  end if;

  if not exists (
    select 1 from public.next_of_kin_profiles
    where user_id = auth.uid() and linked_pregnant_user_id = mum_id
  ) then
    raise exception 'You are not linked to this user.';
  end if;

  update public.profiles
  set subscription_plan = plan, role = 'premium_user'
  where id = mum_id;
end;
$$;

revoke all on function public.gift_subscription_to_linked_mum(uuid, text) from public;
grant execute on function public.gift_subscription_to_linked_mum(uuid, text) to authenticated;
