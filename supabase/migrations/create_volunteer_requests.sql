-- Run in the Supabase SQL editor.
--
-- The volunteer_requests table never actually existed — every query against
-- it in the app has been silently failing and returning empty. This creates
-- it as an open Q&A board: a mum posts a question, and any volunteer can
-- see and reply to it (not tied to one specific volunteer).

create table if not exists public.volunteer_requests (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references auth.users(id) on delete cascade,
  question text not null,
  response text,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.volunteer_requests enable row level security;

-- A mum can post her own question.
create policy "Users can insert their own volunteer request"
on public.volunteer_requests
for insert
to authenticated
with check (patient_id = auth.uid());

-- A mum can see her own questions; any volunteer can see every question
-- (open board), so they can browse and pick one to answer.
create policy "Owner or any volunteer can view volunteer requests"
on public.volunteer_requests
for select
to authenticated
using (
  patient_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'volunteer'
  )
);

-- Only a volunteer can answer (write response/status) — the asking mum
-- can't edit her own question or fake a response.
create policy "Volunteers can respond to volunteer requests"
on public.volunteer_requests
for update
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'volunteer'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'volunteer'
  )
);
