-- next_of_kin_profiles had RLS on but no SELECT policy, so the app always
-- showed "not linked" even though the row existed — it just came back empty
-- instead of erroring. (Studio bypasses RLS, so the row looked fine there.)

-- lets a next-of-kin user read their own link row
create policy "Next of kin can view their own link"
on public.next_of_kin_profiles
for select
to authenticated
using (user_id = auth.uid());
