-- Lets specialists embed inline images in an article body, stored at
-- <user_id>/<timestamp>.<ext> in a public 'article-images' bucket.
-- Same pattern as add_avatar_storage.sql.

-- create the bucket for article images (public so they load without auth)
insert into storage.buckets (id, name, public)
values ('article-images', 'article-images', true)
on conflict (id) do nothing;

-- anyone can view article images
create policy "Article images are publicly readable"
on storage.objects for select
to public
using (bucket_id = 'article-images');

-- authors can only upload into their own folder
create policy "Authors can upload their own article images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'article-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- authors can only delete images from their own folder
create policy "Authors can delete their own article images"
on storage.objects for delete
to authenticated
using (bucket_id = 'article-images' and (storage.foldername(name))[1] = auth.uid()::text);
