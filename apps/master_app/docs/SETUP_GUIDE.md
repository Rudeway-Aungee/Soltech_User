# Setup & Configuration Guide

## Prerequisites

- Flutter 3.11.3 or higher
- Firebase project configured
- Firebase Authentication enabled
- Firebase Realtime Database configured

## Initial Setup

### 1. Firebase Configuration

Ensure your Firebase project has the following enabled:
- Authentication (Email/Password)
- Realtime Database

### 2. Create Super Admin Account

To create the first Super Admin account:

1. Create a user in Firebase Authentication with email/password
2. Get the user's UID
3. Add the following to Firebase Realtime Database:

```json
{
  "superAdmins": {
    "{uid}": {
      "id": "{uid}",
      "name": "Super Admin Name",
      "email": "admin@example.com",
      "status": "active",
      "createdAt": 1234567890000
    }
  },
  "users": {
    "{uid}": {
      "id": "{uid}",
      "name": "Super Admin Name",
      "email": "admin@example.com",
      "phone": "+1234567890",
      "blockStatus": "no",
      "roles": {
        "superAdmin": true
      },
      "defaultRole": "superAdmin",
      "createdAt": 1234567890000,
      "updatedAt": 1234567890000
    }
  }
}
```

### 3. Database Security Rules

Configure your Firebase Realtime Database security rules:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth.uid === $uid || root.child('superAdmins').child(auth.uid).exists()",
        ".write": "auth.uid === $uid || root.child('superAdmins').child(auth.uid).exists()"
      }
    },
    "drivers": {
      "$uid": {
        ".read": "auth.uid === $uid || root.child('fleetOwners').child(auth.uid).exists() || root.child('superAdmins').child(auth.uid).exists()",
        ".write": "root.child('fleetOwners').child(auth.uid).exists() || root.child('superAdmins').child(auth.uid).exists()"
      }
    },
    "fleetAdmins": {
      "$uid": {
        ".read": "auth.uid === $uid || root.child('superAdmins').child(auth.uid).exists()",
        ".write": "root.child('superAdmins').child(auth.uid).exists()"
      }
    },
    "fleetAdminCredentials": {
      ".read": false,
      ".write": "root.child('superAdmins').child(auth.uid).exists()"
    },
    "driverCredentials": {
      ".read": false,
      ".write": "root.child('fleetOwners').child(auth.uid).exists() || root.child('superAdmins').child(auth.uid).exists()"
    },
    "fleetOwners": {
      "$uid": {
        ".read": "auth.uid === $uid || root.child('superAdmins').child(auth.uid).exists()",
        ".write": "auth.uid === $uid || root.child('superAdmins').child(auth.uid).exists()"
      }
    },
    "fleets": {
      "$fleetId": {
        ".read": "root.child('fleetOwners').child(auth.uid).child($fleetId).exists() || root.child('superAdmins').child(auth.uid).exists()",
        ".write": "root.child('fleetOwners').child(auth.uid).child($fleetId).exists() || root.child('superAdmins').child(auth.uid).exists()"
      }
    },
    "fleetDrivers": {
      "$fleetId": {
        ".read": "root.child('fleetOwners').child(auth.uid).child($fleetId).exists() || root.child('superAdmins').child(auth.uid).exists()",
        ".write": "root.child('fleetOwners').child(auth.uid).child($fleetId).exists() || root.child('superAdmins').child(auth.uid).exists()"
      }
    },
    "superAdmins": {
      ".read": "root.child('superAdmins').child(auth.uid).exists()",
      ".write": false
    }
  }
}
```

## Usage Workflows

### Workflow 1: Register a Fleet Admin

1. Super Admin logs in with email/password
2. Super Admin navigates to "Register Fleet Admin" (from Super Admin home page)
3. Super Admin enters: Full Name, Phone, Email
4. System generates Fleet Admin ID (e.g., `FA-ABC123XYZ`)
5. System generates temporary password
6. Super Admin receives credentials in dialog
7. Super Admin shares credentials with Fleet Admin
8. Fleet Admin logs in with Fleet Admin ID + temporary password
9. Fleet Admin changes password on first login

### Workflow 2: Add a Driver to Fleet

1. Fleet Owner logs in with email/password
2. Fleet Owner navigates to "Add Driver" (from Fleet Owner home page)
3. Fleet Owner enters: Driver Name, Email, Phone, Vehicle Model, Color, Plate
4. System generates Driver ID (e.g., `DR-ABC123XYZ`)
5. System generates temporary password
6. Fleet Owner receives credentials in dialog
7. Fleet Owner shares credentials with Driver
8. Driver logs in with Driver ID + temporary password
9. Driver changes password on first login
10. Driver waits for approval from Super Admin or Fleet Admin

### Workflow 3: Passenger Registration

1. User selects "Passenger" role
2. User clicks "Create Account"
3. User enters: Full Name, Phone, Email, Password
4. Account created
5. User can immediately book rides

### Workflow 4: Fleet Owner Registration

1. User selects "Fleet Owner" role
2. User clicks "Create Account"
3. User enters: Full Name, Phone, Email, Password, Fleet Name
4. Account created
5. Fleet created
6. User can immediately add drivers

## Troubleshooting

### Driver Cannot Login
- Verify Driver ID is correct (case-sensitive)
- Check if driver account is active in `driverCredentials`
- Verify driver approval status is "approved"
- Check if driver account is blocked

### Fleet Admin Cannot Login
- Verify Fleet Admin ID is correct (case-sensitive)
- Check if fleet admin account is active in `fleetAdminCredentials`
- Verify fleet admin status is "active"

### Super Admin Cannot Login
- Verify email and password are correct
- Check if super admin account exists in `superAdmins`
- Verify super admin status is "active"

### Driver Not Appearing in Fleet
- Verify driver was added through Fleet Owner interface
- Check `fleetDrivers/{fleetId}` collection
- Verify driver's `fleetId` matches fleet

## API Reference

### IdGenerator
```dart
// Generate Fleet Admin ID
String adminId = IdGenerator.generateFleetAdminId();
// Output: FA-ABC123XYZ

// Generate Driver ID
String driverId = IdGenerator.generateDriverId();
// Output: DR-ABC123XYZ
```

### DriverManagementService
```dart
final service = DriverManagementService();

// Add driver to fleet
final credentials = await service.addDriverToFleet(
  fleetId: 'fleet123',
  driverName: 'John Doe',
  email: 'john@example.com',
  phone: '+1234567890',
  vehicleModel: 'Toyota Camry',
  vehicleColor: 'Black',
  plateNumber: 'ABC123',
);

// Returns: {
//   'driverId': 'DR-ABC123XYZ',
//   'password': 'TempPass1234',
//   'uid': 'firebase_uid'
// }

// Remove driver from fleet
await service.removeDriverFromFleet(
  fleetId: 'fleet123',
  uid: 'driver_uid',
);
```

## Database Backup

Before deploying to production, backup your Firebase Realtime Database:

1. Go to Firebase Console
2. Select your project
3. Go to Realtime Database
4. Click "Backups" tab
5. Click "Create Backup"

## Monitoring

Monitor the following metrics:
- Number of active drivers per fleet
- Number of active fleet admins
- Failed login attempts
- Account creation rate
- Driver approval rate

## Security Considerations

1. **Temporary Passwords**
   - Are not stored in database
   - Should be shared securely (not via email)
   - User must change on first login

2. **ID Generation**
   - Uses cryptographically random characters
   - 10-character alphanumeric format
   - Collision probability is negligible

3. **Role Validation**
   - Validated at session level
   - Checked on every role switch
   - Prevents unauthorized access

4. **Account Blocking**
   - Super Admin can block any account
   - Blocked accounts cannot login
   - Blocking is immediate

## Performance Optimization

1. **Database Queries**
   - Use indexed queries for role lookups
   - Cache user roles in session
   - Minimize database reads

2. **Authentication**
   - Use Firebase Auth caching
   - Implement token refresh
   - Handle offline scenarios

3. **UI Responsiveness**
   - Show loading indicators
   - Disable buttons during operations
   - Handle errors gracefully

## Future Enhancements

1. Two-factor authentication
2. OAuth integration
3. SAML support
4. Audit logging
5. Email notifications
6. SMS notifications
7. Biometric authentication
8. Session management
9. Rate limiting
10. IP whitelisting
