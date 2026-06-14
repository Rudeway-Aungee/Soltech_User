# Soltech lib folder structure

This lib folder has been reorganized into a feature-based Flutter structure.

- core/: shared models, services, widgets, session, design system, and app state
- features/gateway/: unified entry and app routing
- features/passenger/: passenger map, booking, activity, services, and account UI
- features/driver/: driver dashboard, activity, account, and approval UI
- features/fleet_control/: Fleet Control dashboard, driver management, and approval UI
- features/auth/: auth compatibility pages and super admin auth

Drivers do not self-register. Driver accounts are created from Fleet Control.
