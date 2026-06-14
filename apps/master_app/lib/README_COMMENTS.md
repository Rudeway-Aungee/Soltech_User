# Soltech `lib` Folder Guide

This version includes beginner-friendly comments in the Dart source files.

## Main areas

- `features/gateway/` — unified entry screen and role routing.
- `features/passenger/` — passenger booking, map, destination, trip history, and account screens.
- `features/driver/` — driver dashboard, ride requests, active trip flow, history, and earnings.
- `features/fleet_control/` — fleet dashboard, vehicles, driver management, trips, and ledger.
- `features/auth/` — legacy/auth support screens and Super Admin login.
- `core/models/` — Dart data models for Firebase records.
- `core/services/` — reusable services for maps, helpers, and driver creation.
- `core/session/` — app session and role detection.
- `core/widgets/` — reusable UI widgets.

## Important flows

1. Passenger books ride → ride request is saved under `rideRequests`.
2. Driver goes online → driver appears under `onlineDrivers`.
3. Driver accepts ride → ride status changes in Firebase.
4. Passenger listens to ride status → UI updates in real time.
5. Driver completes trip → history, earnings, and ledger records are updated.
6. Fleet Control views trips/ledger for their fleet.
