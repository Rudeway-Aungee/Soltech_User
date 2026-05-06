# Authentication & Registration Flow

## Overview

The Soltech Master App now supports a hierarchical authentication system with five distinct roles:

1. **Passenger** - Self-registration with email/password
2. **Driver** - Added by Fleet Owner, uses system-generated Driver ID
3. **Fleet Admin** - Registered by Super Admin, uses system-generated Fleet Admin ID
4. **Fleet Owner** - Self-registration with email/password
5. **Super Admin** - Email/password login (pre-registered in Firebase)

## Registration Flows

### 1. Passenger Registration
- **Who can register**: Anyone
- **Method**: Self-registration via email/password
- **Process**:
  1. User selects "Passenger" role
  2. Clicks "Create Account"
  3. Enters: Full Name, Phone, Email, Password
  4. Account created in Firebase Auth
  5. User profile stored in `users/{uid}`
  6. Passenger role assigned

### 2. Fleet Owner Registration
- **Who can register**: Anyone
- **Method**: Self-registration via email/password
- **Process**:
  1. User selects "Fleet Owner" role
  2. Clicks "Create Account"
  3. Enters: Full Name, Phone, Email, Password, Fleet Name
  4. Account created in Firebase Auth
  5. User profile stored in `users/{uid}`
  6. Fleet created in `fleets/{fleetId}`
  7. Fleet Owner role assigned in `fleetOwners/{uid}/{fleetId}`

### 3. Driver Registration (NEW)
- **Who can register**: Only Fleet Owners
- **Method**: Fleet Owner adds driver via management page
- **Process**:
  1. Fleet Owner navigates to "Add Driver" page
  2. Enters: Driver Name, Email, Phone, Vehicle Model, Color, Plate Number
  3. System generates unique Driver ID (e.g., `DR-ABC123XYZ`)
  4. System generates temporary password
  5. Driver account created in Firebase Auth
  6. Driver profile stored in `drivers/{uid}`
  7. Driver credentials stored in `driverCredentials/{driverId}`
  8. Fleet Owner receives Driver ID and temporary password to share
  9. Driver uses ID + temporary password to login
  10. Driver must change password on first login

### 4. Fleet Admin Registration (NEW)
- **Who can register**: Only Super Admin
- **Method**: Super Admin registers via Super Admin Auth Page
- **Process**:
  1. Super Admin navigates to "Register Fleet Admin" page
  2. Enters: Full Name, Phone, Email
  3. System generates unique Fleet Admin ID (e.g., `FA-ABC123XYZ`)
  4. System generates temporary password
  5. Fleet Admin account created in Firebase Auth
  6. Fleet Admin profile stored in `fleetAdmins/{uid}`
  7. Fleet Admin credentials stored in `fleetAdminCredentials/{adminId}`
  8. Super Admin receives Fleet Admin ID and temporary password to share
  9. Fleet Admin uses ID + temporary password to login
  10. Fleet Admin must change password on first login

### 5. Super Admin Login
- **Who can login**: Pre-registered Super Admins only
- **Method**: Email/password login
- **Process**:
  1. User selects "Super Admin" role
  2. Enters: Email, Password
  3. System validates credentials
  4. System checks `superAdmins/{uid}` for active status
  5. Access granted if active

## Firebase Database Structure

### User Profiles
```
users/{uid}
├── id: string
├── name: string
├── email: string
├── phone: string
├── blockStatus: string (no/yes)
├── roles: object
│   ├── passenger: boolean
│   ├── driver: boolean
│   ├── fleetAdmin: boolean
│   ├── fleetOwner: boolean
│   └── superAdmin: boolean
├── defaultRole: string
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Driver Credentials (NEW)
```
driverCredentials/{driverId}
├── driverId: string (e.g., DR-ABC123XYZ)
├── email: string
├── uid: string
├── fleetId: string
├── status: string (active/inactive)
└── createdAt: timestamp
```

### Fleet Admin Credentials (NEW)
```
fleetAdminCredentials/{fleetAdminId}
├── fleetAdminId: string (e.g., FA-ABC123XYZ)
├── email: string
├── uid: string
├── status: string (active/inactive)
└── createdAt: timestamp
```

### Driver Profiles
```
drivers/{uid}
├── id: string
├── name: string
├── email: string
├── phone: string
├── vehicleModel: string
├── vehicleColor: string
├── plateNumber: string
├── serviceType: string (taxi)
├── blockStatus: string (no/yes)
├── approvalStatus: string (pending/approved/rejected)
├── onlineStatus: string (online/offline)
├── fleetId: string
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Fleet Admin Profiles (NEW)
```
fleetAdmins/{uid}
├── id: string
├── fleetAdminId: string (e.g., FA-ABC123XYZ)
├── name: string
├── email: string
├── phone: string
├── status: string (active/inactive)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Super Admin Profiles (NEW)
```
superAdmins/{uid}
├── id: string
├── name: string
├── email: string
├── status: string (active/inactive)
├── createdAt: timestamp
└── updatedAt: timestamp
```

## Login Methods

### Passenger Login
- Email + Password

### Driver Login (NEW)
- Driver ID (e.g., `DR-ABC123XYZ`) + Password
- System looks up email from `driverCredentials/{driverId}`
- Uses email + password for Firebase Auth

### Fleet Admin Login (NEW)
- Fleet Admin ID (e.g., `FA-ABC123XYZ`) + Password
- System looks up email from `fleetAdminCredentials/{fleetAdminId}`
- Uses email + password for Firebase Auth

### Fleet Owner Login
- Email + Password

### Super Admin Login
- Email + Password

## Key Changes from Previous Implementation

1. **Driver Self-Registration Removed**
   - Drivers can no longer self-register
   - Only Fleet Owners can add drivers
   - Drivers receive system-generated IDs

2. **Fleet Admin Role Added**
   - New role for managing fleet operations
   - Only Super Admin can register fleet admins
   - Fleet Admins receive system-generated IDs

3. **Super Admin Role Added**
   - New role for system management
   - Can register fleet admins
   - Pre-registered in Firebase

4. **ID-Based Authentication**
   - Drivers and Fleet Admins use system-generated IDs for login
   - IDs are unique and non-sequential
   - Credentials stored separately from user profiles

5. **Temporary Passwords**
   - Drivers and Fleet Admins receive temporary passwords
   - Must change password on first login
   - Temporary passwords are not stored in database

## Implementation Files

### New Files Created
- `lib/core/models/fleet_admin_model.dart` - Fleet Admin profile model
- `lib/core/models/driver_credential_model.dart` - Driver credential model
- `lib/core/utils/id_generator.dart` - ID generation utility
- `lib/core/services/driver_management_service.dart` - Driver management service
- `lib/features/auth/super_admin_auth_page.dart` - Super Admin registration page
- `lib/features/fleet_owner/fleet_owner_driver_management_page.dart` - Driver management page

### Modified Files
- `lib/core/models/app_role.dart` - Added fleetAdmin and superAdmin roles
- `lib/core/session/app_session.dart` - Added role validation for new roles
- `lib/features/auth/role_auth_page.dart` - Updated for ID-based login
- `lib/features/gateway/welcome_role_page.dart` - Added new role cards
- `lib/features/gateway/app_gateway.dart` - Added routing for new roles
- `lib/core/design_system/app_theme.dart` - Added purple color

## Usage Examples

### Adding a Driver (Fleet Owner)
```dart
final service = DriverManagementService();
final credentials = await service.addDriverToFleet(
  fleetId: 'fleet123',
  driverName: 'John Doe',
  email: 'john@example.com',
  phone: '+1234567890',
  vehicleModel: 'Toyota Camry',
  vehicleColor: 'Black',
  plateNumber: 'ABC123',
);

// credentials contains:
// - driverId: 'DR-ABC123XYZ'
// - password: 'TempPass1234'
// - uid: 'firebase_uid'
```

### Registering a Fleet Admin (Super Admin)
```dart
// Use SuperAdminAuthPage to register
// System generates Fleet Admin ID and temporary password
// Super Admin shares credentials with Fleet Admin
```

### Driver Login
```dart
// Driver enters:
// - Driver ID: DR-ABC123XYZ
// - Password: (temporary or changed password)
// System authenticates and grants access
```
