-- Run after add_article_trimester.sql. Tags the test articles from
-- seed_test_articles.sql with a trimester so you can see week-based
-- recommendations working (e.g. a mum at week 11 is in trimester 1).

update public.articles set trimester = 1 where title = 'Eating Healthy During Pregnancy';
update public.articles set trimester = 2 where title = 'Understanding Baby Kicks';
update public.articles set trimester = 3 where title = 'Sleep Tips for Pregnant Mothers';
update public.articles set trimester = 1 where title = 'NHS: Exercise in Pregnancy';
update public.articles set trimester = 1 where title = 'Mayo Clinic: Pregnancy Nutrition Basics';
