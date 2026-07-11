-- Run in the Supabase SQL editor.
--
-- Create Article now lets a specialist embed inline images in the article
-- body, stored in a public 'article-images' bucket at
-- <user_id>/<timestamp>.<ext>. No bucket existed for this, so this creates
-- one and adds the RLS policies on storage.objects needed for an author to
-- manage only their own folder within it — same pattern as add_avatar_storage.sql.

insert into storage.buckets (id, name, public)
values ('article-images', 'article-images', true)
on conflict (id) do nothing;

create policy "Article images are publicly readable"
on storage.objects for select
to public
using (bucket_id = 'article-images');

create policy "Authors can upload their own article images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'article-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Authors can delete their own article images"
on storage.objects for delete
to authenticated
using (bucket_id = 'article-images' and (storage.foldername(name))[1] = auth.uid()::text);
