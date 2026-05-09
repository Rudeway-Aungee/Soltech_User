import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/app_role.dart';
import '../../core/session/app_session.dart';

class FleetAdminEntryPage extends StatefulWidget {
  const FleetAdminEntryPage({super.key});

  @override
  State<FleetAdminEntryPage> createState() => _FleetAdminEntryPageState();
}

class _FleetAdminEntryPageState extends State<FleetAdminEntryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _register = false;
  bool _busy = false;
  bool _loginObscure = true;
  bool _registerObscure = true;

  final TextEditingController _loginFleetNameController = TextEditingController();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _fleetNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginFleetNameController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _ownerNameController.dispose();
    _fleetNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await task();
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      _showMessage(e.message ?? 'Authentication failed.');
    } catch (e) {
      await _auth.signOut();
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    await _run(() async {
      final String fleetName = _loginFleetNameController.text.trim();
      final String email = _loginEmailController.text.trim();
      final String password = _loginPasswordController.text.trim();

      if (fleetName.length < 2) throw Exception('Fleet name is required.');
      if (!email.contains('@')) throw Exception('Enter a valid email address.');
      if (password.length < 6) throw Exception('Password must be at least 6 characters.');

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _verifyFleetNameMatchesCurrentUser(fleetName);
      await _complete();
    });
  }

  Future<void> _registerFleet() async {
    await _run(() async {
      final String ownerName = _ownerNameController.text.trim();
      final String fleetName = _fleetNameController.text.trim();
      final String phone = _phoneController.text.trim();
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      if (ownerName.length < 3) throw Exception("Fleet owner's name must be at least 3 characters.");
      if (fleetName.length < 2) throw Exception('Fleet name is required.');
      if (phone.length < 7) throw Exception('Phone number must be at least 7 characters.');
      if (!email.contains('@')) throw Exception('Enter a valid email address.');
      if (password.length < 6) throw Exception('Password must be at least 6 characters.');

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final User? user = credential.user;
      if (user == null) throw Exception('Unable to create fleet admin account.');

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
        'ownerName': ownerName,
        'phone': phone,
        'email': email,
        'status': 'pending',
        'approvalStatus': 'pending',
        'rejectionReason': '',
        'documents': <String, dynamic>{
          'owner_id': <String, dynamic>{'status': 'submitted', 'label': 'Owner ID'},
          'business_registration': <String, dynamic>{'status': 'submitted', 'label': 'Business Registration'},
          'vehicle_registration': <String, dynamic>{'status': 'submitted', 'label': 'Vehicle Registration'},
          'bank_details': <String, dynamic>{'status': 'submitted', 'label': 'Bank Details'},
        },
        'createdAt': now,
        'updatedAt': now,
      });

      await _database.ref('fleetApplications/$fleetId').set(<String, dynamic>{
        'fleetId': fleetId,
        'ownerId': user.uid,
        'ownerName': ownerName,
        'fleetName': fleetName,
        'phone': phone,
        'email': email,
        'status': 'pending',
        'submittedAt': now,
        'reviewedAt': null,
        'reviewedBy': '',
        'rejectionReason': '',
      });

      await _database.ref('fleetOwners/${user.uid}/$fleetId').set(<String, dynamic>{
        'fleetId': fleetId,
        'role': 'owner',
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      await _complete();
    });
  }

  Future<void> _complete() async {
    final AppSession session = context.read<AppSession>();
    await session.completeAuthentication(AppRole.fleetOwner);
    if (!mounted) return;
    if (session.status != AppSessionStatus.ready && session.status != AppSessionStatus.fleetPending) {
      final String error = session.message ?? 'This account cannot use Fleet Admin.';
      await session.signOut();
      throw Exception(error);
    }
  }

  Future<void> _verifyFleetNameMatchesCurrentUser(String typedFleetName) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Unable to verify fleet account.');

    final DatabaseEvent ownerEvent = await _database.ref('fleetOwners/${user.uid}').once();
    if (ownerEvent.snapshot.value is! Map) throw Exception('This account is not registered as a fleet admin.');

    final Map<Object?, Object?> ownerMap = Map<Object?, Object?>.from(ownerEvent.snapshot.value as Map);
    final String normalizedTypedName = typedFleetName.toLowerCase().trim();

    for (final MapEntry<Object?, Object?> entry in ownerMap.entries) {
      if (entry.value is! Map) continue;
      final Map<Object?, Object?> membership = Map<Object?, Object?>.from(entry.value as Map);
      final String fleetId = (membership['fleetId'] ?? entry.key).toString();
      final DatabaseEvent fleetEvent = await _database.ref('fleets/$fleetId').once();
      if (fleetEvent.snapshot.value is! Map) continue;
      final Map<Object?, Object?> fleet = Map<Object?, Object?>.from(fleetEvent.snapshot.value as Map);
      final String storedName = (fleet['name'] ?? '').toString().toLowerCase().trim();
      if (storedName == normalizedTypedName) return;
    }

    throw Exception('Fleet name does not match this account.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoltechColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFEAF7EF),
                    child: Icon(Icons.business_center_outlined, size: 38, color: SoltechColors.green),
                  ),
                  const SizedBox(height: 12),
                  const Text('SOLTECH FLEET', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: SoltechColors.ink)),
                  const SizedBox(height: 6),
                  const Text('Fleet Control for approved taxi operators', textAlign: TextAlign.center, style: TextStyle(color: SoltechColors.muted)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    decoration: BoxDecoration(
                      color: SoltechColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: SoltechColors.line),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 26, offset: Offset(0, 16))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_register ? 'Register Fleet' : 'Fleet Control Login', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: SoltechColors.ink)),
                        const SizedBox(height: 16),
                        if (_register) ...[
                          _field(_ownerNameController, "Fleet Owner's Name", 'Enter full name', Icons.person_outline),
                          const SizedBox(height: 12),
                          _field(_fleetNameController, 'Fleet Name', 'Enter fleet/company name', Icons.business_outlined),
                          const SizedBox(height: 12),
                          _field(_phoneController, 'Phone', 'Enter phone number', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                          _field(_emailController, 'Email', 'Enter email address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _passwordField(_passwordController, 'Password', 'Enter password', _registerObscure, () => setState(() => _registerObscure = !_registerObscure)),
                          const SizedBox(height: 18),
                          _primaryButton('Submit Fleet Application', _registerFleet),
                          TextButton(onPressed: _busy ? null : () => setState(() => _register = false), child: const Text('Already registered? Login')),
                        ] else ...[
                          _field(_loginFleetNameController, 'Fleet Name', 'Enter fleet/company name', Icons.business_outlined),
                          const SizedBox(height: 12),
                          _field(_loginEmailController, 'Email', 'Enter email address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _passwordField(_loginPasswordController, 'Password', 'Enter password', _loginObscure, () => setState(() => _loginObscure = !_loginObscure)),
                          const SizedBox(height: 18),
                          _primaryButton('Login', _login),
                          TextButton(onPressed: _busy ? null : () => setState(() => _register = true), child: const Text('New fleet operator? Register Fleet')),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, IconData icon, {TextInputType? keyboardType}) {
    return TextField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))));
  }

  Widget _passwordField(TextEditingController controller, String label, String hint, bool obscure, VoidCallback onToggle) {
    return TextField(controller: controller, obscureText: obscure, decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: onToggle), labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))));
  }

  Widget _primaryButton(String label, Future<void> Function() onPressed) {
    return ElevatedButton(onPressed: _busy ? null : onPressed, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label));
  }
}
