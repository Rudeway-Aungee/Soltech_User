# AGENTS.md

## Monorepo Overview
- This repository is a Melos monorepo rooted at `TaxiFlutter/`.
- `apps/passenger_app` is the only implemented app today and remains the source of truth for current user-facing Flutter behavior.
- `apps/driver_app`, `apps/fleet_admin`, `apps/super_admin`, `packages/*`, `backend/`, and `infra/` are intentionally scaffolded placeholders unless files inside them say otherwise.

## Critical Workflows
- Keep the root `pubspec.yaml` valid for Melos 7 workspace resolution.
- Run workspace-level commands such as `melos list` from the repo root.
- Run Flutter commands from the specific app directory, currently `apps/passenger_app/`.
- Keep the passenger app package identity as `soltech_app` unless an explicit rename migration is requested.

## Project Conventions
- Put shared Dart logic in `packages/` rather than importing across app folders directly.
- Keep app-specific docs and operational notes near the app, under `apps/passenger_app/docs/`.
- Treat root `.vscode/` as workspace-level editor config; app-specific IDE state should stay local or ignored.
