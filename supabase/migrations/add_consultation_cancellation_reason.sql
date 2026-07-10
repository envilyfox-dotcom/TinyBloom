-- Lets a patient record why they cancelled a consultation, so the
-- specialist still sees the reason instead of the appointment just
-- vanishing or showing a bare "Cancelled" status.
alter table public.consultations
  add column if not exists cancellation_reason text;
