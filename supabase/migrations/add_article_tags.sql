-- Run in the Supabase SQL editor.
-- Consolidates the Create/Edit Article "Category" and "Relevant Trimester"
-- pickers into a single multi-select tags list (specialists can now attach
-- more than one category, and 1st/2nd/3rd Trimester are just ordinary tags
-- in that same list — see the Create Article screen).
--
-- category/trimester stay as columns and stay populated (derived from tags)
-- because other features still read them directly: baby_development_screen
-- and features_screens filter articles by `trimester` to recommend content
-- for the mum's current trimester, and `category` is still used for
-- lowercase keyword matching there too.

alter table public.articles
  add column if not exists tags text[] not null default '{}';

-- Backfill existing rows from their legacy single category/trimester values.
update public.articles
set tags = array_remove(array[
  category,
  case trimester
    when 1 then '1st Trimester'
    when 2 then '2nd Trimester'
    when 3 then '3rd Trimester'
    else null
  end
], null)
where tags = '{}';

alter table public.article_edit_history
  add column if not exists old_tags text[],
  add column if not exists new_tags text[];

drop function if exists public.edit_article_content(uuid, text, text, text, smallint);

create or replace function public.edit_article_content(
  p_content_id uuid,
  p_title text,
  p_content text,
  p_tags text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid;
  v_status text;
  v_old_title text;
  v_old_content text;
  v_old_tags text[];
  v_category text;
  v_trimester smallint;
  v_changed text[] := '{}';
begin
  select created_by, status, title, content, tags
    into v_author, v_status, v_old_title, v_old_content, v_old_tags
  from public.articles where id = p_content_id for update;

  if v_status is null then
    raise exception 'Content not found';
  end if;
  if v_uid <> v_author then
    raise exception 'Only the author can edit this content';
  end if;
  if v_status = 'published' then
    raise exception 'Published content cannot be edited here';
  end if;

  if v_old_title is distinct from p_title then
    v_changed := array_append(v_changed, 'title');
  end if;
  if v_old_content is distinct from p_content then
    v_changed := array_append(v_changed, 'content');
  end if;
  if v_old_tags is distinct from p_tags then
    v_changed := array_append(v_changed, 'tags');
  end if;

  if array_length(v_changed, 1) > 0 then
    insert into public.article_edit_history (
      content_id, editor_id, changed_fields,
      old_title, new_title, old_content, new_content,
      old_tags, new_tags
    ) values (
      p_content_id, v_uid, v_changed,
      v_old_title, p_title, v_old_content, p_content,
      v_old_tags, p_tags
    );
  end if;

  select t into v_category from unnest(p_tags) t
  where t not in ('1st Trimester', '2nd Trimester', '3rd Trimester')
  limit 1;

  v_trimester := case
    when '1st Trimester' = any(p_tags) then 1
    when '2nd Trimester' = any(p_tags) then 2
    when '3rd Trimester' = any(p_tags) then 3
    else null
  end;

  -- Note: unlike the previous version of this function, approvals and
  -- status are intentionally left untouched — an edit is now just logged
  -- as history, not a reset of review progress.
  update public.articles
  set title = p_title, content = p_content, tags = p_tags,
      category = coalesce(v_category, 'General'), trimester = v_trimester
  where id = p_content_id;
end;
$$;

grant execute on function public.edit_article_content(uuid, text, text, text[]) to authenticated;
