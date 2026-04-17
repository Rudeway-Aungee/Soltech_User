# AGENTS.md

## Architecture Overview
This is a Flutter-based user app for a transportation/delivery service (e.g., taxi or ride-sharing clone). Core components:
- **Authentication**: Firebase Auth with email/password, integrated with Firebase Realtime Database for user profiles and block status checks.
- **Mapping & Location**: Google Maps integration with Geolocator for real-time location tracking.
- **Data Storage**: Firebase Realtime Database stores user data under `users/{uid}` with fields like `name`, `phone`, `email`, `blockStatus`.
- **UI Structure**: Simple navigation between auth pages (`lib/auth/`) and home map view (`lib/pages/home_page.dart`).

Key data flow: App init → Firebase init → Location permission request → Auth check → HomePage with map and destination search UI.

## Critical Workflows
- **Development Run**: Use `flutter run` (handles Android/iOS builds automatically).
- **Build Release**: `flutter build apk` or `flutter build ios` (ensure Firebase config in `lib/firebase_options.dart` matches project).
- **Location Setup**: Location permission is requested on app start in `lib/main.dart`; handle denial gracefully.
- **Auth Flow**: Login/signup validates forms, creates/updates Firebase Auth + DB; blocked users are signed out immediately (see `lib/auth/signin_page.dart`).

## Project Conventions
- **Global State**: User data stored in global variables (`lib/global.dart`: `userName`, `userPhone`); update after DB fetches.
- **Error Handling**: Use `AssociateMethods.showSnackBarMsg()` for user feedback (e.g., validation errors, auth failures).
- **Loading States**: Display `LoadingDialog` widget during async ops like auth/DB calls.
- **Map Integration**: Use `googleMapKey` from `lib/global.dart` for Maps API; default camera position set to GooglePlex coordinates.
- **Validation Rules**: Email must contain '@', password ≥6 chars, name ≥3 chars, phone ≥7 chars (see `lib/auth/` pages).

## Integration Points
- **Firebase**: Auth + DB; user data synced on login/signup; block status enforced.
- **Google Maps**: Embedded in `HomePage` with current location tracking; requires API key in `lib/global.dart`.
- **Permissions**: Location requested via `permission_handler` on startup.
- **Cross-Platform**: Firebase options configured per platform in `lib/firebase_options.dart`; build outputs to `build/` dir.

Reference: `lib/main.dart` (app entry), `lib/auth/signin_page.dart` (auth logic), `lib/pages/home_page.dart` (map UI).</content>
<parameter name="filePath">C:\Users\rudew\StudioProjects\soltech_app\AGENTS.md
