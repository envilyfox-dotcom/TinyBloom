-- Run in the Supabase SQL editor.
--
-- Backend for the next-of-kin Support Checklist (lib/screens/next_of_kin/
-- checklist_screen.dart). Two tables:
--
--   checklist_templates — the default content (same for every next-of-kin),
--     equivalent to _defaultChecklistPhases() in the Flutter code. Read-only
--     reference data, same pattern as the faqs table.
--
--   checklist_items — one row per (user, task). On a next-of-kin's first
--     visit, the app copies every checklist_templates row into
--     checklist_items for that user (template_item_id set, is_completed
--     false). From then on, all reads/writes happen against checklist_items
--     only: editing text updates item_text, deleting removes the row,
--     adding inserts a new row with template_item_id = NULL, and checking
--     a box toggles is_completed. This mirrors exactly how the mutable
--     ChecklistItem/Category/Phase classes already behave client-side, so
--     wiring the screen up to this schema later is a straight swap of the
--     in-memory seed for a Supabase fetch — no UI model changes needed.

create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  phase text not null,          -- e.g. 'First Trimester'
  phase_emoji text not null,    -- e.g. '🌱'
  category text not null,       -- e.g. 'Medical & Health'
  item_text text not null,
  display_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  template_item_id uuid references public.checklist_templates(id) on delete set null,
  phase text not null,
  phase_emoji text not null,
  category text not null,
  item_text text not null,
  is_completed boolean not null default false,
  display_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_checklist_items_user on public.checklist_items(user_id);

-- Keep updated_at current on every edit.
create or replace function public.set_checklist_item_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_checklist_items_updated_at
before update on public.checklist_items
for each row execute function public.set_checklist_item_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────
alter table public.checklist_templates enable row level security;
alter table public.checklist_items enable row level security;

-- Templates are public reference content, same as faqs/articles.
create policy "Checklist templates are publicly readable"
on public.checklist_templates
for select
to authenticated
using (true);

-- A user can only see and manage their own checklist rows.
create policy "Users can view their own checklist items"
on public.checklist_items
for select
to authenticated
using (user_id = auth.uid());

create policy "Users can insert their own checklist items"
on public.checklist_items
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can update their own checklist items"
on public.checklist_items
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Users can delete their own checklist items"
on public.checklist_items
for delete
to authenticated
using (user_id = auth.uid());

-- ── Seed default content ────────────────────────────────────────────
-- Mirrors _defaultChecklistPhases() in checklist_screen.dart exactly, so
-- switching the screen from local seed data to a Supabase fetch doesn't
-- change what anyone sees.
insert into public.checklist_templates (phase, phase_emoji, category, item_text, display_order)
values
  -- First Trimester
  ('First Trimester', '🌱', 'Medical & Health', 'Attend the first prenatal appointment together', 1),
  ('First Trimester', '🌱', 'Medical & Health', 'Learn about common first-trimester symptoms (nausea, fatigue, mood changes)', 2),
  ('First Trimester', '🌱', 'Medical & Health', 'Help manage morning sickness (bland snacks, ginger tea, rest)', 3),
  ('First Trimester', '🌱', 'Medical & Health', 'Discuss choice of OB/GP or midwife', 4),
  ('First Trimester', '🌱', 'Medical & Health', 'Understand the prenatal vitamins/supplements she needs', 5),
  ('First Trimester', '🌱', 'Practical Support', 'Take over extra household chores as fatigue sets in', 6),
  ('First Trimester', '🌱', 'Practical Support', 'Reduce exposure to strong smells/triggers at home', 7),
  ('First Trimester', '🌱', 'Practical Support', 'Start a shared pregnancy calendar', 8),
  ('First Trimester', '🌱', 'Emotional & Relational', 'Check in regularly on how she''s feeling, physically and emotionally', 9),
  ('First Trimester', '🌱', 'Emotional & Relational', 'Discuss how and when to share the pregnancy news', 10),
  ('First Trimester', '🌱', 'Emotional & Relational', 'Be patient and understanding around mood swings', 11),
  ('First Trimester', '🌱', 'Financial & Planning', 'Talk about parental leave options and timing', 12),
  ('First Trimester', '🌱', 'Financial & Planning', 'Research healthcare/insurance coverage for pregnancy and birth', 13),
  ('First Trimester', '🌱', 'Financial & Planning', 'Start a rough budget for baby-related costs', 14),

  -- Second Trimester
  ('Second Trimester', '🌼', 'Medical & Health', 'Attend prenatal appointments and scans together (e.g. anatomy scan)', 15),
  ('Second Trimester', '🌼', 'Medical & Health', 'Learn what to expect at the anatomy scan', 16),
  ('Second Trimester', '🌼', 'Medical & Health', 'Go over any screening test results together', 17),
  ('Second Trimester', '🌼', 'Medical & Health', 'Help her stay active with safe, gentle exercise', 18),
  ('Second Trimester', '🌼', 'Practical Support', 'Start setting up and shopping for the nursery', 19),
  ('Second Trimester', '🌼', 'Practical Support', 'Research and compare paediatricians', 20),
  ('Second Trimester', '🌼', 'Practical Support', 'Attend a birth preparation / antenatal class together', 21),
  ('Second Trimester', '🌼', 'Practical Support', 'Start researching baby gear (car seat, stroller, crib)', 22),
  ('Second Trimester', '🌼', 'Emotional & Relational', 'Track baby movements/kicks together', 23),
  ('Second Trimester', '🌼', 'Emotional & Relational', 'Talk about parenting values and expectations', 24),
  ('Second Trimester', '🌼', 'Emotional & Relational', 'Plan quality time together before the baby arrives', 25),
  ('Second Trimester', '🌼', 'Financial & Planning', 'Finalise parental leave arrangements with employers', 26),
  ('Second Trimester', '🌼', 'Financial & Planning', 'Set up or review a baby savings fund', 27),
  ('Second Trimester', '🌼', 'Financial & Planning', 'Look into childcare options and costs for after birth', 28),

  -- Third Trimester
  ('Third Trimester', '🌸', 'Medical & Health', 'Attend more frequent prenatal appointments together', 29),
  ('Third Trimester', '🌸', 'Medical & Health', 'Learn the signs of labour and when to head to the hospital', 30),
  ('Third Trimester', '🌸', 'Medical & Health', 'Go over the birth plan together', 31),
  ('Third Trimester', '🌸', 'Medical & Health', 'Learn basic newborn care (feeding, diapering, soothing, safe sleep)', 32),
  ('Third Trimester', '🌸', 'Practical Support', 'Pack the hospital bag together', 33),
  ('Third Trimester', '🌸', 'Practical Support', 'Install and double-check the car seat', 34),
  ('Third Trimester', '🌸', 'Practical Support', 'Finalise the nursery and baby essentials', 35),
  ('Third Trimester', '🌸', 'Practical Support', 'Prepare and freeze meals for after the birth', 36),
  ('Third Trimester', '🌸', 'Emotional & Relational', 'Reassure her as anxiety about labour may increase', 37),
  ('Third Trimester', '🌸', 'Emotional & Relational', 'Plan who will be present during labour/delivery', 38),
  ('Third Trimester', '🌸', 'Emotional & Relational', 'Discuss visitor policies and boundaries for after birth', 39),
  ('Third Trimester', '🌸', 'Financial & Planning', 'Confirm parental leave start date and paperwork', 40),
  ('Third Trimester', '🌸', 'Financial & Planning', 'Review health insurance/hospital billing details', 41),
  ('Third Trimester', '🌸', 'Financial & Planning', 'Finalise birth announcement plans', 42),

  -- Postpartum
  ('Postpartum (0–3 Months)', '🍼', 'Medical & Health', 'Attend the postpartum check-up together', 43),
  ('Postpartum (0–3 Months)', '🍼', 'Medical & Health', 'Watch for signs of postpartum depression/anxiety in her', 44),
  ('Postpartum (0–3 Months)', '🍼', 'Medical & Health', 'Help track baby''s feeding and diaper schedule', 45),
  ('Postpartum (0–3 Months)', '🍼', 'Medical & Health', 'Learn safe sleep practices for the baby', 46),
  ('Postpartum (0–3 Months)', '🍼', 'Practical Support', 'Take on nighttime duties to help her rest', 47),
  ('Postpartum (0–3 Months)', '🍼', 'Practical Support', 'Manage visitors and household tasks', 48),
  ('Postpartum (0–3 Months)', '🍼', 'Practical Support', 'Help with meal prep and errands', 49),
  ('Postpartum (0–3 Months)', '🍼', 'Emotional & Relational', 'Check in on her emotional wellbeing regularly', 50),
  ('Postpartum (0–3 Months)', '🍼', 'Emotional & Relational', 'Share nighttime/feeding duties to prevent burnout', 51),
  ('Postpartum (0–3 Months)', '🍼', 'Emotional & Relational', 'Celebrate small wins together as new parents', 52),
  ('Postpartum (0–3 Months)', '🍼', 'Financial & Planning', 'Register the birth and apply for relevant benefits', 53),
  ('Postpartum (0–3 Months)', '🍼', 'Financial & Planning', 'Update insurance to include the baby', 54),
  ('Postpartum (0–3 Months)', '🍼', 'Financial & Planning', 'Review and adjust the household budget for baby expenses', 55);
