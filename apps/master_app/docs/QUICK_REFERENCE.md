# Quick Reference Guide

## Role Comparison

| Feature | Passenger | Driver | Fleet Admin | Fleet Owner | Super Admin |
|---------|-----------|--------|-------------|-------------|------------|
| Self-Register | ✅ | ❌ | ❌ | ✅ | ❌ |
| Login Method | Email + Password | Driver ID + Password | Fleet Admin ID + Password | Email + Password | Email + Password |
| Added By | Self | Fleet Owner | Super Admin | Self | Admin |
| Can Add Users | ❌ | ❌ | ❌ | ✅ (Drivers) | ✅ (Fleet Admins) |
| Needs Approval | ❌ | ✅ | ❌ | ❌ | ❌ |
| System-Generated ID | ❌ | ✅ | ✅ | ❌ | ❌ |
| Temporary Password | ❌ | ✅ | ✅ | ❌ | ❌ |

## File Structure

```
lib/
├── core/
│   ├── models/
│   │   ├── app_role.dart (MODIFIED)
│   │   ├── app_user_profile.dart
│   │   ├── driver_credential_model.dart (NEW)
│   │   ├── fleet_admin_model.dart (NEW)
│   │   └── role_session.dart
│   ├── services/
│   │   └── driver_management_service.dart (NEW)
│   ├── session/
│   │   └── app_session.dart (MODIFIED)
│   ├── utils/
│   │   └── id_generator.dart (NEW)
│   └── design_system/
│       └── app_theme.dart (MODIFIED)
├── features/
│   ├── auth/
│   │   ├── role_auth_page.dart (MODIFIED)
│   │   └── super_admin_auth_page.dart (NEW)
│   ├── gateway/
│   │   ├── app_gateway.dart (MODIFIED)
│   │   └── welcome_role_page.dart (MODIFIED)
│   └── fleet_owner/
│       └── fleet_owner_driver_management_page.dart (NEW)
└── docs/
    ├── AUTHENTICATION_FLOW.md (NEW)
    ├── IMPLEMENTATION_SUMMARY.md (NEW)
    └── SETUP_GUIDE.md (NEW)
```

## Key Classes

### IdGenerator
```dart
class IdGenerator {
  static String generateFleetAdminId()  // FA-XXXXXXXXXX
  static String generateDriverId()      // DR-XXXXXXXXXX
}
```

### DriverManagementService
```dart
class DriverManagementService {
  Future<Map<String, String>> addDriverToFleet({...})
  Future<void> removeDriverFromFleet({...})
}
```

### FleetAdminProfile
```dart
class FleetAdminProfile {
  final String id;
  final String fleetAdminId;
  final String name;
  final String email;
  final String phone;
  final String status;
  final int createdAt;
  final int updatedAt;
}
```

### DriverCredential
```dart
class DriverCredential {
  final String driverId;
  final String fleetId;
  final String driverName;
  final String email;
  final String phone;
  final String status;
  final int createdAt;
}
```

## Firebase Collections

### New Collections
- `driverCredentials/{driverId}` - Driver login mapping
- `fleetAdminCredentials/{fleetAdminId}` - Fleet Admin login mapping
- `fleetAdmins/{uid}` - Fleet Admin profiles
- `superAdmins/{uid}` - Super Admin profiles

### Updated Collections
- `users/{uid}` - Added fleetAdmin and superAdmin roles
- `drivers/{uid}` - No structural changes

## Common Tasks

### Add a Driver
```dart
final service = DriverManagementService();
final result = await service.addDriverToFleet(
  fleetId: 'fleet123',
  driverName: 'John Doe',
  email: 'john@example.com',
  phone: '+1234567890',
  vehicleModel: 'Toyota Camry',
  vehicleColor: 'Black',
  plateNumber: 'ABC123',
);
// result['driverId'] = 'DR-ABC123XYZ'
// result['password'] = 'TempPass1234'
```

### Remove a Driver
```dart
final service = DriverManagementService();
await service.removeDriverFromFleet(
  fleetId: 'fleet123',
  uid: 'driver_uid',
);
```

### Generate IDs
```dart
String adminId = IdGenerator.generateFleetAdminId();  // FA-ABC123XYZ
String driverId = IdGenerator.generateDriverId();      // DR-ABC123XYZ
```

### Check User Role
```dart
final session = context.read<AppSession>();
if (session.selectedRole == AppRole.driver) {
  // User is a driver
}
```

### Get Available Roles
```dart
final session = context.read<AppSession>();
final roles = session.availableRoles;
// Set<AppRole> containing all roles for user
```

## Navigation

### To Driver Management Page
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FleetOwnerDriverManagementPage(
      fleetId: 'fleet123',
    ),
  ),
);
```

### To Super Admin Auth Page
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SuperAdminAuthPage(),
  ),
);
```

## Error Handling

### Driver Already Exists
```dart
try {
  await service.addDriverToFleet(...);
} on FirebaseAuthException catch (e) {
  if (e.code == 'email-already-in-use') {
    // Email already registered
  }
}
```

### Invalid Credentials
```dart
try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(...);
} on FirebaseAuthException catch (e) {
  if (e.code == 'user-not-found') {
    // User not found
  } else if (e.code == 'wrong-password') {
    // Wrong password
  }
}
```

## Testing

### Test Driver Login
1. Create driver via Fleet Owner interface
2. Note Driver ID and temporary password
3. Sign out
4. Select Driver role
5. Enter Driver ID and password
6. Verify login succeeds

### Test Fleet Admin Login
1. Create fleet admin via Super Admin interface
2. Note Fleet Admin ID and temporary password
3. Sign out
4. Select Fleet Admin role
5. Enter Fleet Admin ID and password
6. Verify login succeeds

### Test Role Switching
1. Login as user with multiple roles
2. Switch between roles
3. Verify session updates correctly
4. Verify UI updates for each role

## Debugging

### Enable Firebase Logging
```dart
FirebaseDatabase.instance.setLoggingEnabled(true);
```

### Check Session State
```dart
final session = context.read<AppSession>();
print('Status: ${session.status}');
print('Role: ${session.selectedRole}');
print('Available Roles: ${session.availableRoles}');
print('User: ${session.currentUser?.email}');
```

### Verify Database Structure
Use Firebase Console to inspect:
- `users/{uid}` - User profile
- `drivers/{uid}` - Driver profile
- `driverCredentials/{driverId}` - Driver credentials
- `fleetAdmins/{uid}` - Fleet admin profile
- `fleetAdminCredentials/{fleetAdminId}` - Fleet admin credentials

## Performance Tips

1. Cache user roles in session
2. Use indexed queries for role lookups
3. Minimize database reads
4. Implement pagination for large lists
5. Use lazy loading for driver lists

## Security Tips

1. Never log credentials
2. Always use HTTPS
3. Validate input on client and server
4. Use Firebase security rules
5. Implement rate limiting
6. Monitor failed login attempts
7. Rotate temporary passwords
8. Audit admin actions

## Common Issues

### Issue: Driver cannot login
**Solution**: 
- Verify Driver ID is correct
- Check driver approval status
- Verify driver is not blocked
- Check Firebase Auth credentials

### Issue: Fleet Admin cannot login
**Solution**:
- Verify Fleet Admin ID is correct
- Check fleet admin status is "active"
- Verify credentials in fleetAdminCredentials

### Issue: Driver not appearing in fleet
**Solution**:
- Verify driver was added through proper interface
- Check fleetDrivers collection
- Verify driver's fleetId matches

### Issue: Role not available
**Solution**:
- Check user profile in users/{uid}
- Verify role is set in roles object
- Check role validation in AppSession
- Verify user is not blocked
