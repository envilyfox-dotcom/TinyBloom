-- The "Link" button deletes any existing link for the user then inserts the
-- new one. Same RLS gap as add_next_of_kin_link_policy.sql, but for
-- insert/delete instead of select.

-- lets a next-of-kin user create their own link row
create policy "Next of kin can create their own link"
on public.next_of_kin_profiles
for insert
to authenticated
with check (user_id = auth.uid());

-- lets a next-of-kin user delete their own link row
create policy "Next of kin can delete their own link"
on public.next_of_kin_profiles
for delete
to authenticated
using (user_id = auth.uid());
