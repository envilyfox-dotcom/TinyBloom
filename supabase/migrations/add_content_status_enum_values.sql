-- Run this file BY ITSELF in the Supabase SQL editor — nothing else in the
-- same script/transaction — then run add_content_review_pipeline.sql
-- afterward in a separate run. Postgres does not allow a new enum value to
-- be used (e.g. in an UPDATE or a policy) in the same transaction that adds
-- it, so this must be its own statement batch.
--
-- `articles.status` is the existing `content_status` enum, currently
-- (draft, published, archived). The review pipeline reuses `draft` and
-- `published` as-is (`published` = the doc's "live" state — the existing
-- public-read policies already gate on it, so nothing else needs to change
-- for public visibility) and only needs these 5 new intermediate states.

alter type public.content_status add value if not exists 'pending_approval_1';
alter type public.content_status add value if not exists 'pending_approval_2';
alter type public.content_status add value if not exists 'publish_buffer';
alter type public.content_status add value if not exists 'changes_requested';
alter type public.content_status add value if not exists 'emergency_pending';
