-- Run in the Supabase SQL editor.
--
-- Adds a "Next of Kin" category to the existing faqs table (previously only
-- General/Features/Subscriptions/Privacy), matching what the next-of-kin
-- flows in the app actually do today — not a generic template, since a few
-- of these (linking, gifting) work differently than a typical mock-up
-- assumes (e.g. linking is immediate via a user code, no email approval
-- step).
--
-- display_order is a single sequence shared across every category (not
-- reset per category — the existing 5 rows run 1 through 5), so these
-- continue on from 6 rather than restarting at 1. If more faqs have been
-- added since, bump these numbers up so they don't collide.

insert into public.faqs (category, question, answer, display_order, is_published)
values
  ('Next of Kin',
   'How do I link to a pregnant user?',
   'Go to your Profile, tap "Link to Pregnant User", enter her user code, tap Verify to confirm it belongs to a registered mum, choose your relationship to her, then tap Link. You''re connected immediately — there''s no approval step on her side.',
   6, true),
  ('Next of Kin',
   'What can a Next of Kin see?',
   'Your dashboard shows your linked mum''s current trimester progress, baby''s development for her current week, and her upcoming consultations and milestones.',
   7, true),
  ('Next of Kin',
   'Can I edit my linked mum''s information?',
   'No — you can view her pregnancy journey and act on her behalf for things like booking consultations or gifting Premium, but her profile and health logs remain hers to manage.',
   8, true),
  ('Next of Kin',
   'Can I join consultations?',
   'Yes — tap "Join consult" on your dashboard, or use the Consultation tab, to book a session with a specialist or volunteer for your linked mum.',
   9, true),
  ('Next of Kin',
   'How do I gift a subscription?',
   'From your dashboard, tap "Gift premium", choose a plan, and tap Proceed to Payment. Your linked mum is upgraded to Premium right away.',
   10, true),
  ('Next of Kin',
   'Can I link to a different pregnant user later?',
   'Yes — linking to a new user code from the Link to Pregnant User screen replaces your current link.',
   11, true);
