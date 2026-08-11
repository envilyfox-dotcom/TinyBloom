-- Lets "service updated/cancelled" notifications carry a snapshot of the
-- listing's availability slot, so the app can hide them once that slot has
-- expired even after the underlying volunteer_services row is gone (e.g.
-- cancellations delete the row before the notification is written).
alter table public.notifications
  add column if not exists service_availability text;
