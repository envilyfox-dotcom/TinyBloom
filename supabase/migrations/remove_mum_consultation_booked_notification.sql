-- Run in the Supabase SQL editor.
--
-- create_consultation_notification() (a live DB trigger not previously
-- tracked in this repo's migrations) fires on every consultations insert
-- and creates two notifications: one for the mum ("Consultation Booked")
-- and one for the specialist ("New Consultation Request"). The mum-facing
-- one is redundant — the app already builds a live "Consultation Update"
-- card from the consultations table itself (see
-- notifications_screen.dart's _loadRowsFromConsultationsTable) — and mums
-- don't want it. The specialist-facing notification is untouched.

create or replace function public.create_consultation_notification()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.specialist_id is not null then
    insert into public.notifications (
      user_id,
      type,
      title,
      message
    )
    values (
      new.specialist_id,
      'appointment',
      'New Consultation Request',
      'You have received a new consultation request.'
    );
  end if;

  return new;
end;
$function$;
