1. UI / UX
Structural / navigation
Bottom nav index desync is fragile. router.dart:105-154 computes the tab index with a chain of location.startsWith(...), and app_shell.dart:16-37 keeps a parallel list of route strings per role. Two sources of truth that must stay in sync by hand. Worse, the fallbacks are wrong-by-default: any unmatched route falls through to idx = 0, so a specialist on /specialist/review/thread sees "Home" highlighted. Collapse this into one List<({String route, IconData icon, String label})> per role, derive both the index and the items from it.

Deep sub-screens lose the bottom nav. Most detail screens (/consultation/detail, /education/:id, /logs/:id) sit outside the ShellRoute, so the nav bar disappears and reappears. That's a defensible choice, but it's applied inconsistently — /volunteer/services/new is inside the shell. Pick one rule.

Next-of-kin has 6 bottom-nav tabs (app_shell.dart:52-89) with selectedFontSize: 11 as the workaround. Six is over the Material guidance of 5 and the labels will truncate on small phones. Move "Checklist" into the Home dashboard as a card.

Visual system
No dark mode. app_theme.dart:31 hardcodes ColorScheme.light, MaterialApp.router sets only theme: with no darkTheme/themeMode. For an app people open at 3am while feeding a baby, this is a real gap, not a nicety.

945 hardcoded fontSize: values across the app, and zero use of Theme.of(context).textTheme at call sites. Anyone with system font scaling turned up gets overflow. The TBCard/TBSectionTitle primitives in common_widgets.dart exist but aren't carrying type — extend the AppTheme textTheme and delete the inline sizes.

Zero Semantics() widgets anywhere in lib/. Icon-only buttons (TBIconBadgeButton, the notification bell, star ratings) have no screen-reader labels. Star rating rows in particular are unreadable to TalkBack.

Ad-hoc colors bypass the palette. e.g. Color(0xFFE8A0B4) appears literally in router.dart:466, router.dart:508, router.dart:543 — a pink that isn't in AppColors at all (rose is 0xFFC97B75). Two different brand pinks ship in the same binary.

Feedback & state
82 silent catch (_) {} blocks — 8 in supabase_service.dart, 7 in shared/dashboard_screen.dart. A dropped network call renders as an empty state indistinguishable from "you have no data." Users can't tell "no consultations yet" from "we failed to load your consultations." Every list needs a third state: loading / empty / error+retry. TBEmptyState should get a sibling TBErrorState.

No offline handling at all. No connectivity package, no cached-read fallback. Airplane mode = a screen of empty states with no explanation.

Loading is all-or-nothing spinners. shimmer: ^3.0.0 is in pubspec.yaml but I found no Shimmer usage — the dependency is dead. The dashboard fires ~10 sequential queries behind a single CircularProgressIndicator. Skeleton-load the sections independently so the week tracker paints immediately.

Aggressive polling with no lifecycle awareness. Timer.periodic at 15s on the mum dashboard (dashboard_screen.dart:1511), 15s on volunteer services and requests, and 8s on the volunteer request thread (volunteer_requests_screen.dart:431). There is no WidgetsBindingObserver in the entire codebase, so these keep hammering Supabase while the app is backgrounded. The mum dashboard's _load() runs ~10 queries — that's ~40 queries/minute per idle user. Supabase Realtime (.stream()) is unused; the chat threads and notification badges are exactly what it's for.

Smaller wins
Article search debounce is 250ms and consistent — good. But it filters client-side over an unpaginated getArticles(); no .range() anywhere in the app.
SnackBar is used 240 times as the universal feedback channel, including for destructive-action confirmation. Consider inline error text on forms and reserving snackbars for transient success.
Log entry (create_log_screen.dart:81-84) caps backdating at 365 days and offers no "log for today" quick action from the dashboard.
ProviderReviewsScreen builds the title as 'Reviews for Dr. ${name}' (provider_reviews_screen.dart:53) — will overflow the AppBar for long names; no overflow/maxLines.
2. Missing features
Compliance blockers (ship-stopping)
Gap	Why it matters
No account deletion	Zero matches for deactivate/delete account in live code. Google Play has required in-app account deletion since 2024. The README claims this feature exists — it only lived in the now-dead screens/profile/.
No privacy policy / terms / consent	Zero matches for Privacy, Terms of, consent. This app stores pregnancy status, due dates, medical conditions, allergies, and symptom diaries — special-category health data under GDPR/PDPA. There is no consent flow and no data-export path.
Stripe checkout for digital goods	subscription_screen.dart:122-168 opens Stripe in an external browser. Play Store policy requires Google Play Billing for in-app digital subscriptions.
Functional gaps
Push notifications don't exist. notification_service.dart is a 0-byte file. No firebase_messaging, no flutter_local_notifications. So: a mum gets no alert when a specialist approves her consultation, no reminder before an appointment, and a next-of-kin gets no alert when a danger symptom is logged — the emergency-alert feature only fires if they happen to have the app open. For a pregnancy-safety app, this is the single biggest missing piece.

No vitals tracking. The live log schema is mood/symptoms/milestones/notes only — supabase_service.dart:262-266 explicitly notes "no vitals columns (weight/kicks/blood pressure)." Meanwhile the dead screens/logs/logs_screen.dart has working weight and kick-count UI. So this was built and then dropped. Missing: weight-gain curve, BP log (pre-eclampsia screening — and the danger scan already looks for its symptoms), kick counter with a 2-hours-to-10-kicks timer, contraction timer.

Chat history isn't persisted. chatbot_screen.dart:54 holds _messages in a plain in-memory List. Navigate away and the conversation is gone. Only the last 8 messages are sent as context (chatbot_screen.dart:319), so the AI also forgets mid-conversation.

Other absences: appointment reminders/calendar export (.ics), no in-app emergency-services shortcut on the danger-symptom path, no article bookmarks or offline reading (articles are network-only despite cached_network_image being available for the images), no forum moderation/report flow, no search across consultations or logs, no i18n scaffolding (intl is used only for date formatting; all strings are hardcoded English), no biometric lock on a health-data app.

3. Edge cases & under-tested areas
There is no test/ directory. Zero tests, 46k lines. Everything below is unverified by anything but manual clicking.

Confirmed defects
① Premium gating is cosmetic — free users get the AI chatbot. dashboard_screen.dart:2446-2450: _exploreCard accepts an isPremium parameter and never reads it. onTap just does context.push(item['route']). And chatbot_screen.dart contains no AuthProvider reference, no isPremium check — nothing. So the "premium" AI is reachable by any free user tapping the card. (Dart won't warn: unused parameters aren't flagged.) Verify the tinybloom-chat edge function enforces the entitlement server-side, because the client does not.

② Timezone is inconsistent and created_at is 8 hours wrong. singapore_time.dart does display conversion to GMT+8, but supabase_service.dart:945 writes 'created_at': DateTime.now().toIso8601String() — a naive local string with no offset, which Postgres reads as UTC in a timestamptz column. A booking made at 15:00 SGT is stored as 15:00 UTC = 23:00 SGT. Separately, all the slot-filtering logic in consultation_booking_screen.dart:235-265 uses raw DateTime.now() (device local), so a traveling user sees a differently-filtered slot list than the server enforces. Fix: DateTime.now().toUtc().toIso8601String() on writes, and one shared "now in SGT" helper for all comparisons.

③ Danger-symptom scan will produce false alarms and misses. pregnancy_log_danger_scan.dart:35-56 does bare combinedText.contains(keyword). So:

"no bleeding today" → fires "Bleeding reported" to the next-of-kin. Negation isn't handled.
"hay fever" → fires "Fever reported".
'swelling' matches mild ankle swelling, which is normal in the third trimester — this will fire constantly and train people to ignore the alerts.
Conversely "haemorrhage", "bled", "cramping", "spotting" match nothing.
This is the safety-critical path. It needs word-boundary matching at minimum, negation detection, severity tiers, and a structured-symptom-picker input rather than free-text keyword scraping.

④ Post-term pregnancies display wrong. supabase_service.dart:172-176: .clamp(1, 40). Weeks 41 and 42 both render as week 40. .clamp(1, …) also means a due date >280 days out shows "week 1" instead of an error. And .inDays truncates toward zero, so the week flips a day late for anyone past their due date. pregnancy_status (postpartum? trying?) is stored but never gates this — a postpartum user still sees a pregnancy week counter.

⑤ Post-payment state never refreshes. _startCheckout launches the browser and returns. There's no deep-link return handler, no didChangeAppLifecycleState refresh, no polling. The user pays, comes back, and the app still says "Free Member" until they force-restart.

Races and concurrency
ensureRatingNotification (supabase_service.dart:800-847) is check-then-insert with no unique constraint mentioned. Two concurrent calls (it's called from consultation load and chat close) both see nothing and both insert → duplicate rating prompts. Also both guards use .maybeSingle(), which throws if a duplicate already exists — swallowed by the outer catch (_) {}, so it silently stops working forever after the first duplicate.
submitProviderRating (supabase_service.dart:860-880) inserts with no duplicate guard. Double-tap on the submit button = two ratings, skewing the provider's average.
Consultation booking is the one place done right — supabase_service.dart:948-960 catches PG 23505 from a real DB constraint. Use that pattern for the two above.
Auth race: auth_provider.dart:44 caps profile load at 5s, then _applyMetaFallback() builds a profile from JWT metadata. If the profiles table is slow, role comes from user metadata — which is client-writable at signup (supabase_service.dart:24-35 passes role into signUp data). A user could sign up claiming role: 'specialist'. The UI would grant specialist navigation; only RLS stops the damage. Worth auditing that every specialist/admin table has RLS keyed on the profiles row, never the JWT claim.
Untyped state.extra casts → crash on deep link
Roughly 15 routes do unguarded casts: state.extra as Map<String, dynamic> (router.dart:271, 276, 284, 348, 374) and as String (336, 340, 378). Any of these reached without extra — a push notification, an app-link, or process death + restore — throws in the route builder and produces a red screen with no recovery. /consultation/detail is the only route with a fallback (_ConsultationNotFoundScreen); apply that pattern everywhere, and prefer path params over extra for anything linkable.

Uploads
uploadArticleImage (supabase_service.dart:95-107) takes raw bytes with no size limit and no MIME validation — contentType is inferred as ext == 'png' ? 'image/png' : 'image/jpeg', so a .gif or .svg gets mislabeled as JPEG. uploadProfilePicture writes to a fixed path {uid}/avatar.{ext} with upsert: true, so switching png→jpg leaves an orphaned file that removeProfilePicture's best-effort cleanup may or may not catch. The picker caps at maxWidth: 1280, quality: 85, but nothing stops a large upload from a different code path.

Dead code (~6,000 lines)
Nothing imports these — confirmed by grep, and flutter analyze flags 12 unused declarations inside them:

screens/features_screens.dart — 2,811 lines
screens/dashboard/dashboard_screen.dart — 700
screens/onboarding/mum_onboarding_screen.dart — 857
screens/logs/logs_screen.dart — 626 (contains the lost vitals UI — salvage before deleting)
screens/profile/profile_screen.dart — 534 (contains the lost account-deactivation UI)
screens/forum/forum_screen.dart — 456
These are actively harmful: they're the top grep hits for isPremium and deactivate, which makes it look like those features exist. flutter analyze also flags 7 unused private members in the live shared/dashboard_screen.dart (_openWebsite, _babySize, _babyWeight, _alertCard, …) — leftovers from the migration.

Where I'd start
Premium bypass (①) — an hour's work, currently giving away the paid feature.
created_at UTC bug (②) — one-line fix, but every existing row is 8 hours off and needs a backfill migration.
Delete the 6k lines of dead code, salvaging the vitals and account-deletion screens first.
Account deletion + privacy policy — store-review blockers.
Push notifications — the emergency-alert and consultation-approval flows don't actually work without them.
Guard the state.extra casts — prerequisite for #5, since notification taps will hit exactly those routes.
First tests: pregnancyWeekFromProfile (boundaries: week 0/1/40/41/42, null due date), dangerSymptomMatches (negation, "hay fever", word boundaries), and the booking slot filter across timezones. These are pure functions — cheap to cover and they're where the safety-critical logic lives.