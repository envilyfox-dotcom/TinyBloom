-- Run after add_consultation_booking_fields.sql.
-- Populates demo profile data (rating, experience, "helps with",
-- available-today slots) for your existing specialist/volunteer test
-- accounts, and marks them verified so they show up in the app
-- ("Select Specialist"/"Select Volunteer" only shows is_verified = true).
--
-- These user_id values are the existing 'daryl', 'damien' (specialist) and
-- 'Carl' (volunteer) accounts found in your profiles table. Adjust if yours
-- differ.
--
-- Uses UPDATE-then-INSERT-IF-MISSING instead of ON CONFLICT, since not
-- every one of these tables has a unique constraint on user_id.

-- daryl (specialist)
update public.specialist_profiles set
  specialization = 'Obstetrician & Gynecologist',
  rating = 4.9,
  years_experience = 8,
  helps_with = array['Pregnancy complications', 'Prenatal care'],
  available_today = array['2:00 PM', '4:00 PM'],
  is_verified = true
where user_id = '6dd783d2-2c26-4f3e-a000-ec24e4e48f34';

insert into public.specialist_profiles
  (user_id, specialization, rating, years_experience, helps_with, available_today, is_verified)
select '6dd783d2-2c26-4f3e-a000-ec24e4e48f34', 'Obstetrician & Gynecologist', 4.9, 8,
       array['Pregnancy complications', 'Prenatal care'], array['2:00 PM', '4:00 PM'], true
where not exists (
  select 1 from public.specialist_profiles where user_id = '6dd783d2-2c26-4f3e-a000-ec24e4e48f34'
);

-- damien (specialist)
update public.specialist_profiles set
  specialization = 'Lactation Consultant',
  rating = 4.9,
  years_experience = 6,
  helps_with = array['Breastfeeding preparation', 'Postnatal support'],
  available_today = array['9:00 AM', '1:00 PM'],
  is_verified = true
where user_id = '2d7f1d0e-484f-4208-963f-c5983235caef';

insert into public.specialist_profiles
  (user_id, specialization, rating, years_experience, helps_with, available_today, is_verified)
select '2d7f1d0e-484f-4208-963f-c5983235caef', 'Lactation Consultant', 4.9, 6,
       array['Breastfeeding preparation', 'Postnatal support'], array['9:00 AM', '1:00 PM'], true
where not exists (
  select 1 from public.specialist_profiles where user_id = '2d7f1d0e-484f-4208-963f-c5983235caef'
);

-- Carl (volunteer)
update public.volunteer_profiles set
  expertise = 'Pregnancy Support Volunteer',
  rating = 4.9,
  years_experience = 8,
  helps_with = array['Emotional support', 'Basic pregnancy guidance'],
  available_today = array['2:00 PM', '4:00 PM'],
  is_verified = true
where user_id = 'e4621336-eff2-400a-a0af-3c1211fee442';

insert into public.volunteer_profiles
  (user_id, expertise, rating, years_experience, helps_with, available_today, is_verified)
select 'e4621336-eff2-400a-a0af-3c1211fee442', 'Pregnancy Support Volunteer', 4.9, 8,
       array['Emotional support', 'Basic pregnancy guidance'], array['2:00 PM', '4:00 PM'], true
where not exists (
  select 1 from public.volunteer_profiles where user_id = 'e4621336-eff2-400a-a0af-3c1211fee442'
);
