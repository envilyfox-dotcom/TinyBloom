-- Run in the Supabase SQL editor.
--
-- Edit Profile now lets a user upload or remove their own profile picture,
-- stored in a public 'avatars' bucket at <user_id>/avatar.<ext>. No storage
-- bucket existed yet (storage.buckets was empty), so this creates one and
-- adds the RLS policies on storage.objects needed for a user to manage only
-- their own folder within it — the standard Supabase pattern of keying the
-- first path segment to auth.uid().

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Avatar images are publicly readable"
on storage.objects for select
to public
using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
on storage.objects for insert
to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update their own avatar"
on storage.objects for update
to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete their own avatar"
on storage.objects for delete
to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
