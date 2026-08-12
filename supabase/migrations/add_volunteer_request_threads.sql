-- Turns the one-question/one-response board into a real back-and-forth
-- thread, locked to whichever volunteer replies first. volunteer_id tracks
-- who claimed the thread (null = still open), and volunteer_request_messages
-- holds every message after the original question, both sides included.

-- who claimed this thread, null means still up for grabs
alter table public.volunteer_requests
  add column if not exists volunteer_id uuid references auth.users(id) on delete set null;

-- the back-and-forth messages for a claimed thread
create table if not exists public.volunteer_request_messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.volunteer_requests(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

alter table public.volunteer_request_messages enable row level security;

-- only the asking mum and the volunteer who claimed the thread can read it
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

-- same two people can post into the thread, and only send as themselves
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

-- open (unclaimed, pending) questions stay visible to any authenticated
-- user so volunteers can browse and claim one, but once claimed only the
-- asking mum and the assigned volunteer can see it
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

-- any authenticated user can claim an open request for themselves; same
-- trust level as before since the old "respond" policy already let anyone
-- set status/response
drop policy if exists "Authenticated users can respond to volunteer requests" on public.volunteer_requests;
drop policy if exists "Volunteers can respond to volunteer requests" on public.volunteer_requests;
create policy "Claim an open volunteer request"
on public.volunteer_requests
for update
to authenticated
using (volunteer_id is null and status = 'pending')
with check (volunteer_id = auth.uid() and status = 'responded');
