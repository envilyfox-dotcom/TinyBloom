# TinyBloom Flutter App

TinyBloom is a pregnancy support mobile app built with Flutter. It connects to the same Supabase backend as the TinyBloom website, so data (accounts, articles, consultations, etc.) is shared between the app and the site.

The app supports four user roles, each with its own dashboard and navigation:
- **Mum** (free or premium) — tracks pregnancy progress, logs health data, books consultations, reads articles
- **Specialist** — manages consultations, publishes/reviews articles, sets availability
- **Volunteer** — offers services/sessions to mums, answers volunteer questions
- **Next of kin** — linked to a mum's account to view alerts, gift subscriptions, and a shared checklist

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0+ installed → https://docs.flutter.dev/get-started/install
- Android Studio + Android SDK
- An Android device or emulator (Android 6.0+)

### 1. Install Flutter
```bash
# Download Flutter SDK from https://flutter.dev
# Add flutter/bin to your PATH
flutter doctor  # verify setup
```

### 2. Clone / extract the project
Extract the TinyBloom folder to your computer.

### 3. Install dependencies
```bash
cd TinyBloom
flutter pub get
```

### 4. Run on Android
```bash
# Connect your Android device (enable USB debugging)
# OR start an emulator in Android Studio

flutter devices        # list available devices
flutter run            # run on connected device
flutter run --release  # run optimised release build
```

### 5. Build APK for demo
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
# Install on any Android device
```

---

## Project Structure

```
lib/
├── main.dart                       # App entry point (Supabase init + MaterialApp.router)
├── services/
│   ├── supabase_service.dart       # All Supabase queries/mutations (data access layer)
│   ├── auth_provider.dart          # Logged-in user + profile + role state (ChangeNotifier)
│   ├── notification_service.dart   # In-app notification helpers
│   └── specialist_group_cache.dart # Local cache for specialist grouping lookups
├── utils/                          # Pure helpers: theme, date/time, availability, checklist data, etc.
├── widgets/                        # Shared reusable widgets (cards, chat bubble, review UI, etc.)
└── screens/
    ├── router.dart                 # GoRouter routes + auth/onboarding redirects
    ├── app_shell.dart              # Bottom nav bar wrapper (per-role tabs)
    ├── auth/                       # Login, forgot password
    ├── onboarding/, dashboard/, logs/, forum/, premium/, profile/  # Legacy/simple top-level screens
    ├── shared/                     # Screens used by more than one role (profile, FAQ, education, notifications...)
    ├── mum/
    │   ├── onboarding/              # Pregnancy profile setup
    │   ├── consultation/            # Booking, browsing specialists/volunteers, chat
    │   ├── logs/                    # Health log CRUD
    │   ├── forum/                   # Community forum
    │   └── rating/                  # Rate a provider after a consultation
    ├── specialist/                 # Dashboard, consultations, article authoring/review, availability
    ├── volunteer/                  # Dashboard, services offered, sessions, requests
    └── next_of_kin/                # Dashboard, alerts, checklist, link-to-mum, gift subscription

supabase/
└── migrations/                     # SQL migrations for the shared Supabase project (tables, RLS policies, functions)
```

---

## Features Implemented

| Feature | Status |
|---------|--------|
| Login / role-based auth (mum, specialist, volunteer, next of kin) | ✅ |
| Onboarding (pregnancy profile / specialist availability) | ✅ |
| Dashboards per role | ✅ |
| Pregnancy week & milestone tracker | ✅ |
| Health logs (CRUD) | ✅ |
| Consultation booking, rescheduling, cancellation | ✅ |
| Volunteer requests & Q&A chat | ✅ |
| Provider ratings & reviews | ✅ |
| Community forum | ✅ |
| Educational articles + review/approval pipeline | ✅ |
| AI chatbot (premium) | ✅ |
| Subscription management + gift subscription (next of kin) | ✅ |
| Next of kin linking, alerts, shared checklist | ✅ |
| Notifications | ✅ |
| View / edit profile, change password | ✅ |

---

## Supabase Connection
Uses the same Supabase project as the website:
- URL: https://yznzzhecpbhqtgozxpfg.supabase.co
- All data is shared between the website and app
- Schema changes live in `supabase/migrations/` — each file is a standalone, plain-English-commented migration (table/column changes, RLS policies, functions)
