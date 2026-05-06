import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/app_role.dart';
import '../../core/session/app_session.dart';

class WelcomeRolePage extends StatefulWidget {
  const WelcomeRolePage({super.key});

  @override
  State<WelcomeRolePage> createState() => _WelcomeRolePageState();
}

class _WelcomeRolePageState extends State<WelcomeRolePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  int _selected = 0; // 0: Passenger, 1: Driver, 2: Fleet Control

  bool _passengerRegister = false;
  bool _fleetRegister = false;
  bool _isBusy = false;

  bool _passengerLoginObscure = true;
  bool _passengerRegisterObscure = true;
  bool _passengerConfirmObscure = true;
  bool _driverObscure = true;
  bool _fleetLoginObscure = true;
  bool _fleetRegisterObscure = true;

  final TextEditingController _passengerLoginController = TextEditingController();
  final TextEditingController _passengerLoginPasswordController = TextEditingController();
  final TextEditingController _passengerNameController = TextEditingController();
  final TextEditingController _passengerEmailController = TextEditingController();
  final TextEditingController _passengerPhoneController = TextEditingController();
  final TextEditingController _passengerPasswordController = TextEditingController();
  final TextEditingController _passengerConfirmPasswordController = TextEditingController();

  final TextEditingController _driverIdController = TextEditingController();
  final TextEditingController _driverPasswordController = TextEditingController();

  final TextEditingController _fleetLoginNameController = TextEditingController();
  final TextEditingController _fleetLoginEmailController = TextEditingController();
  final TextEditingController _fleetLoginPasswordController = TextEditingController();
  final TextEditingController _fleetOwnerNameController = TextEditingController();
  final TextEditingController _fleetNameController = TextEditingController();
  final TextEditingController _fleetPhoneController = TextEditingController();
  final TextEditingController _fleetEmailController = TextEditingController();
  final TextEditingController _fleetPasswordController = TextEditingController();

  @override
  void dispose() {
    _passengerLoginController.dispose();
    _passengerLoginPasswordController.dispose();
    _passengerNameController.dispose();
    _passengerEmailController.dispose();
    _passengerPhoneController.dispose();
    _passengerPasswordController.dispose();
    _passengerConfirmPasswordController.dispose();
    _driverIdController.dispose();
    _driverPasswordController.dispose();
    _fleetLoginNameController.dispose();
    _fleetLoginEmailController.dispose();
    _fleetLoginPasswordController.dispose();
    _fleetOwnerNameController.dispose();
    _fleetNameController.dispose();
    _fleetPhoneController.dispose();
    _fleetEmailController.dispose();
    _fleetPasswordController.dispose();
    super.dispose();
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    FocusScope.of(context).unfocus();

    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await task();
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      _showMessage(e.message ?? 'Authentication failed.');
    } catch (e) {
      await _auth.signOut();
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _loginPassenger() async {
    await _runBusy(() async {
      final String loginValue = _passengerLoginController.text.trim();
      final String password = _passengerLoginPasswordController.text.trim();

      if (loginValue.isEmpty) {
        throw Exception('Enter your phone number or email.');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      final String email = await _resolvePassengerLoginEmail(loginValue);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _completeRoleAuthentication(AppRole.passenger);
    });
  }

  Future<void> _registerPassenger() async {
    await _runBusy(() async {
      final String name = _passengerNameController.text.trim();
      final String email = _passengerEmailController.text.trim();
      final String phone = _passengerPhoneController.text.trim();
      final String password = _passengerPasswordController.text.trim();
      final String confirmPassword = _passengerConfirmPasswordController.text.trim();

      if (name.length < 3) {
        throw Exception('Full name must be at least 3 characters.');
      }
      if (!email.contains('@')) {
        throw Exception('Enter a valid email address.');
      }
      if (phone.length < 7) {
        throw Exception('Phone number must be at least 7 characters.');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }
      if (password != confirmPassword) {
        throw Exception('Passwords do not match.');
      }

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        throw Exception('Unable to create passenger account.');
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      await _database.ref('users/${user.uid}').set(<String, dynamic>{
        'id': user.uid,
        'name': name,
        'phone': phone,
        'email': email,
        'blockStatus': 'no',
        'roles': <String, bool>{'passenger': true},
        'defaultRole': AppRole.passenger.key,
        'createdAt': now,
        'updatedAt': now,
      });

      await _completeRoleAuthentication(AppRole.passenger);
    });
  }

  Future<void> _loginDriver() async {
    await _runBusy(() async {
      final String driverId = _driverIdController.text.trim().toUpperCase();
      final String password = _driverPasswordController.text.trim();

      if (driverId.isEmpty) {
        throw Exception('Enter the Driver ID provided by your Fleet Owner.');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      final DatabaseEvent credentialEvent = await _database
          .ref('driverCredentials/$driverId')
          .once();
      if (credentialEvent.snapshot.value is! Map) {
        throw Exception('Driver ID was not found. Contact your Fleet Owner.');
      }

      final Map<Object?, Object?> credential = Map<Object?, Object?>.from(
        credentialEvent.snapshot.value as Map,
      );
      if ((credential['status'] ?? 'active').toString() != 'active') {
        throw Exception('This Driver ID is not active. Contact your Fleet Owner.');
      }

      final String email = (credential['email'] ?? '').toString().trim();
      if (!email.contains('@')) {
        throw Exception('Driver login is incomplete. Contact your Fleet Owner.');
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _completeRoleAuthentication(AppRole.driver);
    });
  }

  Future<void> _loginFleetOwner() async {
    await _runBusy(() async {
      final String fleetName = _fleetLoginNameController.text.trim();
      final String email = _fleetLoginEmailController.text.trim();
      final String password = _fleetLoginPasswordController.text.trim();

      if (fleetName.length < 2) {
        throw Exception('Fleet name is required.');
      }
      if (!email.contains('@')) {
        throw Exception('Enter a valid email address.');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _verifyFleetNameMatchesCurrentUser(fleetName);
      await _completeRoleAuthentication(AppRole.fleetOwner);
    });
  }

  Future<void> _registerFleetOwner() async {
    await _runBusy(() async {
      final String ownerName = _fleetOwnerNameController.text.trim();
      final String fleetName = _fleetNameController.text.trim();
      final String phone = _fleetPhoneController.text.trim();
      final String email = _fleetEmailController.text.trim();
      final String password = _fleetPasswordController.text.trim();

      if (ownerName.length < 3) {
        throw Exception("Fleet owner's name must be at least 3 characters.");
      }
      if (fleetName.length < 2) {
        throw Exception('Fleet name is required.');
      }
      if (phone.length < 7) {
        throw Exception('Phone number must be at least 7 characters.');
      }
      if (!email.contains('@')) {
        throw Exception('Enter a valid email address.');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        throw Exception('Unable to create fleet owner account.');
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      final DatabaseReference fleetRef = _database.ref('fleets').push();
      final String fleetId = fleetRef.key!;

      await _database.ref('users/${user.uid}').set(<String, dynamic>{
        'id': user.uid,
        'name': ownerName,
        'phone': phone,
        'email': email,
        'blockStatus': 'no',
        'roles': <String, bool>{'fleetOwner': true},
        'defaultRole': AppRole.fleetOwner.key,
        'createdAt': now,
        'updatedAt': now,
      });

      await fleetRef.set(<String, dynamic>{
        'id': fleetId,
        'name': fleetName,
        'ownerId': user.uid,
        'phone': phone,
        'email': email,
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
      });

      await _database.ref('fleetOwners/${user.uid}/$fleetId').set(<String, dynamic>{
        'fleetId': fleetId,
        'role': 'owner',
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
      });

      await _completeRoleAuthentication(AppRole.fleetOwner);
    });
  }

  Future<void> _completeRoleAuthentication(AppRole role) async {
    if (!mounted) {
      return;
    }

    final AppSession session = context.read<AppSession>();
    await session.completeAuthentication(role);

    if (!mounted) {
      return;
    }

    if (session.status != AppSessionStatus.ready &&
        session.status != AppSessionStatus.driverPending) {
      final String error = session.message ?? 'This account cannot use this mode.';
      await _auth.signOut();
      await session.signOut();
      throw Exception(error);
    }
  }

  Future<String> _resolvePassengerLoginEmail(String loginValue) async {
    if (loginValue.contains('@')) {
      return loginValue;
    }

    final DatabaseEvent event = await _database
        .ref('users')
        .orderByChild('phone')
        .equalTo(loginValue)
        .once();

    if (event.snapshot.value is! Map) {
      throw Exception('No passenger account was found for that phone number.');
    }

    final Map<Object?, Object?> users = Map<Object?, Object?>.from(
      event.snapshot.value as Map,
    );
    for (final Object? userValue in users.values) {
      if (userValue is! Map) {
        continue;
      }
      final Map<Object?, Object?> user = Map<Object?, Object?>.from(userValue);
      final Object? rolesValue = user['roles'];
      final bool isPassenger = rolesValue is Map &&
          Map<Object?, Object?>.from(rolesValue)['passenger'] == true;
      final String email = (user['email'] ?? '').toString().trim();
      if (isPassenger && email.contains('@')) {
        return email;
      }
    }

    throw Exception('No passenger account was found for that phone number.');
  }

  Future<void> _verifyFleetNameMatchesCurrentUser(String typedFleetName) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Unable to verify fleet account.');
    }

    final DatabaseEvent ownerEvent = await _database
        .ref('fleetOwners/${user.uid}')
        .once();
    if (ownerEvent.snapshot.value is! Map) {
      throw Exception('This account is not registered as a fleet owner.');
    }

    final Map<Object?, Object?> ownerMap = Map<Object?, Object?>.from(
      ownerEvent.snapshot.value as Map,
    );
    final String normalizedTypedName = typedFleetName.toLowerCase().trim();

    for (final MapEntry<Object?, Object?> entry in ownerMap.entries) {
      if (entry.value is! Map) {
        continue;
      }
      final Map<Object?, Object?> membership = Map<Object?, Object?>.from(
        entry.value as Map,
      );
      if ((membership['status'] ?? 'active').toString() != 'active') {
        continue;
      }

      final DatabaseEvent fleetEvent = await _database
          .ref('fleets/${entry.key}')
          .once();
      if (fleetEvent.snapshot.value is! Map) {
        continue;
      }

      final Map<Object?, Object?> fleet = Map<Object?, Object?>.from(
        fleetEvent.snapshot.value as Map,
      );
      final String storedFleetName = (fleet['name'] ?? '').toString().toLowerCase().trim();
      if (storedFleetName == normalizedTypedName) {
        return;
      }
    }

    throw Exception('Fleet name does not match this account.');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoltechColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSegmentedControl(),
            const SizedBox(height: 22),
            if (_selected == 0) _buildPassengerCard(),
            if (_selected == 1) _buildDriverCard(),
            if (_selected == 2) _buildFleetCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFE5E7EB),
          child: Icon(
            Icons.local_taxi_outlined,
            size: 36,
            color: SoltechColors.ink,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'SOLTECH',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: SoltechColors.ink,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Taxi Booking & Fleet Management',
          style: TextStyle(color: SoltechColors.muted),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SoltechColors.line),
        color: Colors.white,
      ),
      child: Row(
        children: List<Widget>.generate(3, (int idx) {
          final bool active = _selected == idx;
          final BorderRadius radius = idx == 0
              ? const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                )
              : idx == 2
                  ? const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    )
                  : BorderRadius.zero;

          final String label = <String>['Passenger', 'Driver', 'Fleet Control'][idx];

          return Expanded(
            child: InkWell(
              borderRadius: radius,
              onTap: _isBusy
                  ? null
                  : () => setState(() {
                        _selected = idx;
                      }),
              child: Container(
                decoration: BoxDecoration(
                  color: active ? SoltechColors.ink : Colors.white,
                  borderRadius: radius,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : SoltechColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPassengerCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _passengerRegister ? 'Passenger Registration' : 'Passenger Login',
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 16),
        if (_passengerRegister) ...[
          _field(_passengerNameController, 'Full Name', 'Enter full name', Icons.person_outline),
          const SizedBox(height: 12),
          _field(
            _passengerEmailController,
            'Email',
            'Enter email address',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _field(
            _passengerPhoneController,
            'Phone',
            'Enter phone number',
            Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _passwordField(
            _passengerPasswordController,
            'Password',
            'Enter your password',
            _passengerRegisterObscure,
            () => setState(() => _passengerRegisterObscure = !_passengerRegisterObscure),
          ),
          const SizedBox(height: 12),
          _passwordField(
            _passengerConfirmPasswordController,
            'Confirm Password',
            'Re-enter password',
            _passengerConfirmObscure,
            () => setState(() => _passengerConfirmObscure = !_passengerConfirmObscure),
          ),
          const SizedBox(height: 18),
          _primaryButton('Create Account', _registerPassenger),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isBusy ? null : () => setState(() => _passengerRegister = false),
            child: const Text('Already have an account? Login'),
          ),
        ] else ...[
          _field(
            _passengerLoginController,
            'Phone / Email',
            'Enter phone number or email',
            Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _passwordField(
            _passengerLoginPasswordController,
            'Password',
            'Enter your password',
            _passengerLoginObscure,
            () => setState(() => _passengerLoginObscure = !_passengerLoginObscure),
          ),
          const SizedBox(height: 18),
          _primaryButton('Login', _loginPassenger),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isBusy ? null : () => setState(() => _passengerRegister = true),
            child: const Text('New passenger? Create Passenger Account'),
          ),
          TextButton(
            onPressed: _isBusy ? null : () => _showMessage('Password reset can be added later.'),
            child: const Text('Forgot password?'),
          ),
        ],
      ],
    );
  }

  Widget _buildDriverCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Driver Login', textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 16),
        _field(
          _driverIdController,
          'Driver ID',
          'Enter your driver ID',
          Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        _passwordField(
          _driverPasswordController,
          'Password',
          'Enter your password',
          _driverObscure,
          () => setState(() => _driverObscure = !_driverObscure),
        ),
        const SizedBox(height: 18),
        _primaryButton('Login', _loginDriver),
        const SizedBox(height: 14),
        const Text(
          'Use the Driver ID and password provided by your Fleet Owner.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SoltechColors.muted),
        ),
        TextButton(
          onPressed: _isBusy ? null : () => _showMessage('Please contact your Fleet Owner for login help.'),
          child: const Text('Need help? Contact your Fleet Owner'),
        ),
      ],
    );
  }

  Widget _buildFleetCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _fleetRegister ? 'Fleet Control Register' : 'Fleet Owner Login',
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 16),
        if (_fleetRegister) ...[
          _field(
            _fleetOwnerNameController,
            "Full Fleet Owner's Name",
            'Enter full name',
            Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _field(
            _fleetNameController,
            'Fleet Name',
            'Enter fleet name',
            Icons.apartment_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            _fleetPhoneController,
            'Phone Number',
            'Enter phone number',
            Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _field(
            _fleetEmailController,
            'Email',
            'Enter email address',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _passwordField(
            _fleetPasswordController,
            'Password',
            'Create password',
            _fleetRegisterObscure,
            () => setState(() => _fleetRegisterObscure = !_fleetRegisterObscure),
          ),
          const SizedBox(height: 18),
          _primaryButton('Register', _registerFleetOwner),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isBusy ? null : () => setState(() => _fleetRegister = false),
            child: const Text('Already have a fleet account? Login'),
          ),
        ] else ...[
          _field(
            _fleetLoginNameController,
            'Fleet Name',
            'Enter fleet name',
            Icons.apartment_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            _fleetLoginEmailController,
            'Email',
            'Enter email address',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _passwordField(
            _fleetLoginPasswordController,
            'Password',
            'Enter your password',
            _fleetLoginObscure,
            () => setState(() => _fleetLoginObscure = !_fleetLoginObscure),
          ),
          const SizedBox(height: 18),
          _primaryButton('Login', _loginFleetOwner),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isBusy ? null : () => setState(() => _fleetRegister = true),
            child: const Text('New fleet owner? Register'),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton(String label, Future<void> Function() onPressed) {
    return ElevatedButton(
      onPressed: _isBusy ? null : onPressed,
      child: _isBusy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      enabled: !_isBusy,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    String hint,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !_isBusy,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: _isBusy ? null : onToggle,
        ),
      ),
    );
  }

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: SoltechColors.ink,
  );
}
