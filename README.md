# TaxiFlutter

TaxiFlutter is a Melos-based monorepo for the Soltech transportation platform.

## Workspace Layout

- `apps/passenger_app` contains the current Flutter passenger app. Its Dart package name remains `soltech_app`.
- `apps/driver_app`, `apps/fleet_admin`, and `apps/super_admin` are reserved for future Flutter apps.
- `packages/*` is reserved for shared Dart and Flutter packages.
- `backend/` is reserved for the Node.js API and real-time services.
- `infra/` is reserved for Docker, CI/CD, and deployment support.

## Working In This Repo

- Melos 7 workspace resolution is defined in the root `pubspec.yaml`, which currently includes only `apps/passenger_app`.
- Run Melos commands from the repo root, for example `melos list`.
- Run Flutter app commands from `apps/passenger_app`, for example `flutter pub get` or `flutter run`.
- App-specific technical notes now live under `apps/passenger_app/docs/`.
