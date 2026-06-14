# AGENTS.md

## Architecture Overview
This is a Flutter-based passenger app for a transportation and delivery service. Core components:
- **Authentication**: Firebase Auth with email/password, integrated with Firebase Realtime Database for user profiles and block status checks.
- **Mapping & Location**: Google Maps integration with Geolocator for real-time location tracking.
- **Data Storage**: Firebase Realtime Database stores user data under `users/{uid}` with fields like `name`, `phone`, `email`, `blockStatus`.
- **UI Structure**: Simple navigation between auth pages (`lib/auth/`) and the home map view (`lib/pages/home_page.dart`).

Key data flow: App init -> Firebase init -> Location permission request -> Auth check -> `HomePage` with map and destination search UI.

## Critical Workflows
- **Development Run**: Use `flutter run` from `apps/passenger_app/`.
- **Build Release**: Use `flutter build apk` or `flutter build ios` and ensure Firebase config in `lib/firebase_options.dart` matches the target project.
- **Location Setup**: Location permission is requested on app start in `lib/main.dart`; handle denial gracefully.
- **Auth Flow**: Login/signup validates forms, creates or updates Firebase Auth + Realtime Database data, and signs blocked users out immediately.

## Project Conventions
- **Global State**: User data is stored in `lib/global.dart` globals such as `userName` and `userPhone`; update them after DB fetches.
- **Error Handling**: Use `AssociateMethods.showSnackBarMsg()` for user feedback.
- **Loading States**: Display `LoadingDialog` during async auth and database operations.
- **Map Integration**: Use `googleMapKey` from `lib/global.dart`; default camera position is set to GooglePlex coordinates.
- **Validation Rules**: Email must contain `@`, password >= 6 chars, name >= 3 chars, and phone >= 7 chars.

## Integration Points
- **Firebase**: Auth + Realtime Database; user data syncs on login/signup and `blockStatus` is enforced.
- **Google Maps**: Embedded in `HomePage` with current location tracking.
- **Permissions**: Location permission is requested via `permission_handler` on startup.
- **Cross-Platform**: Firebase options are configured per platform in `lib/firebase_options.dart`.

## Monorepo Context
- This app now lives at `apps/passenger_app/` inside the TaxiFlutter workspace.
- The Dart package name stays `soltech_app`, so existing `package:soltech_app/...` imports remain unchanged.
- App-specific supporting docs are stored in `docs/`.

Reference: `lib/main.dart`, `lib/auth/signin_page.dart`, `lib/pages/home_page.dart`.
