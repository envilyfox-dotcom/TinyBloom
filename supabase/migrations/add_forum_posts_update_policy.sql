-- Run in the Supabase SQL editor.
--
-- forum_posts has SELECT/INSERT/DELETE policies but was missing UPDATE,
-- needed for the new "edit my post" feature (SupabaseService.updateForumPost).
-- Without this, an edit would fail the same way pregnancy_logs inserts used
-- to: RLS silently rejects rows with no policy covering the command.

-- lets a user edit their own forum posts, nobody else's
create policy "Users can update their own posts"
on public.forum_posts
for update
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());
