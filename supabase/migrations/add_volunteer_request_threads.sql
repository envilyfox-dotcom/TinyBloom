-- Run in the Supabase SQL editor (after the earlier volunteer_requests
-- migrations already applied).
--
-- Turns the one-question/one-response board into a real back-and-forth
-- thread, locked to whichever volunteer replies first:
--   * volunteer_id records who claimed the thread (null = still open).
--   * volunteer_request_messages holds every message after the original
--     question — both the volunteer's replies and the mum's follow-ups.
--
-- Claiming happens via an UPDATE that only succeeds when volunteer_id is
-- still null (see claimAndReplyToRequest in supabase_service.dart), so two
-- volunteers racing to answer the same question can't both win.

alter table public.volunteer_requests
  add column if not exists volunteer_id uuid references auth.users(id) on delete set null;

create table if not exists public.volunteer_request_messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.volunteer_requests(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

alter table public.volunteer_request_messages enable row level security;

drop policy if exists "Participants can view thread messages" on public.volunteer_request_messages;
create policy "Participants can view thread messages"
on public.volunteer_request_messages
for select
to authenticated
using (
  exists (
    select 1 from public.volunteer_requests r
    where r.id = request_id
      and (r.patient_id = auth.uid() or r.volunteer_id = auth.uid())
  )
);

drop policy if exists "Participants can send thread messages" on public.volunteer_request_messages;
create policy "Participants can send thread messages"
on public.volunteer_request_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.volunteer_requests r
    where r.id = request_id
      and (r.patient_id = auth.uid() or r.volunteer_id = auth.uid())
  )
);

-- Tighten volunteer_requests visibility now that threads can be claimed:
-- open (unclaimed, pending) questions stay visible to any authenticated
-- user so volunteers can browse and claim one, but once claimed only the
-- asking mum and the assigned volunteer can see it.
drop policy if exists "Any authenticated user can view volunteer requests" on public.volunteer_requests;
drop policy if exists "Owner or any volunteer can view volunteer requests" on public.volunteer_requests;
create policy "View own, assigned, or open volunteer requests"
on public.volunteer_requests
for select
to authenticated
using (
  patient_id = auth.uid()
  or volunteer_id = auth.uid()
  or (volunteer_id is null and status = 'pending')
);

-- Claiming: any authenticated user may flip an open (unclaimed, pending)
-- request to themselves. (Same trust level as before — the old "respond"
-- policy already let any authenticated user set status/response.)
drop policy if exists "Authenticated users can respond to volunteer requests" on public.volunteer_requests;
drop policy if exists "Volunteers can respond to volunteer requests" on public.volunteer_requests;
create policy "Claim an open volunteer request"
on public.volunteer_requests
for update
to authenticated
using (volunteer_id is null and status = 'pending')
with check (volunteer_id = auth.uid() and status = 'responded');
