-- A plain RLS UPDATE policy can't limit a next-of-kin to only touching
-- subscription_plan/role on the mum's profile without also affecting the
-- mum's own Edit Profile screen (RLS controls which rows, not which columns).
-- So instead we drop that policy and use a narrow function that only does
-- the gifting update, checks the link itself, and runs as security definer
-- so it doesn't need a general UPDATE policy on profiles at all.

-- remove the old, too-broad update policy
drop policy if exists "Next of kin can gift subscription to linked mum" on public.profiles;

-- lets a next-of-kin gift a plan to the mum they're linked to, nothing else
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

-- lock it down so only signed-in users can call it
revoke all on function public.gift_subscription_to_linked_mum(uuid, text) from public;
grant execute on function public.gift_subscription_to_linked_mum(uuid, text) to authenticated;
