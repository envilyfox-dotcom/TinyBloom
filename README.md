# TinyBloom Flutter App

A pregnancy support mobile application built with Flutter, connected to the same Supabase backend as the TinyBloom website.

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
Extract the tinybloom_app folder to your computer.

### 3. Install dependencies
```bash
cd tinybloom_app
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
├── main.dart                    # App entry point
├── utils/
│   └── app_theme.dart           # Colors, theme, constants
├── services/
│   ├── supabase_service.dart    # All Supabase DB calls
│   └── auth_provider.dart      # Auth state management
├── widgets/
│   └── common_widgets.dart     # Reusable UI components
└── screens/
    ├── router.dart              # GoRouter navigation
    ├── app_shell.dart           # Bottom nav wrapper
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── dashboard/
    │   └── dashboard_screen.dart
    ├── logs/
    │   └── logs_screen.dart     # Health logs CRUD
    ├── profile/
    │   └── profile_screen.dart  # View/edit/deactivate
    └── features_screens.dart    # FAQ, Education, Chatbot,
                                 # Consultation, Subscription
```

---

## Features Implemented

| Feature | Status |
|---------|--------|
| Login / Register (4 roles) | ✅ |
| Role-based plan selection | ✅ |
| Dashboard (free & premium) | ✅ |
| Pregnancy week tracker | ✅ |
| Health Logs (CRUD) | ✅ |
| View / Edit Profile | ✅ |
| Change Password | ✅ |
| Deactivate Account | ✅ |
| FAQ (with categories) | ✅ |
| Educational Articles | ✅ |
| Search & filter articles | ✅ |
| AI Chatbot (Premium) | ✅ |
| Consultations | ✅ |
| Subscription management | ✅ |
| Premium gating | ✅ |
| User ID (for NOK linking) | ✅ |

---

## Supabase Connection
Uses the same Supabase project as the website:
- URL: https://yznzzhecpbhqtgozxpfg.supabase.co
- All data is shared between the website and app
