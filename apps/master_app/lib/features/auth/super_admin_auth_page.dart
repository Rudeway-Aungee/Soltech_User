// CODE COMMENTS -------------------------------------------------------------
// Purpose: Protected login screen for Super Admin users.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Protected Super Admin login screen.
// Super Admin is separated from the public Passenger/Driver/Fleet Control entry for security.
// ---------------------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/design_system/app_theme.dart';


class SuperAdminAuthPage extends StatefulWidget {
  const SuperAdminAuthPage({super.key});

  @override
  State<SuperAdminAuthPage> createState() => _SuperAdminAuthPageState();
}

class _SuperAdminAuthPageState extends State<SuperAdminAuthPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isBusy = false;
  String? generatedAdminId;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _registerFleetAdmin() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      isBusy = true;
    });

    try {
      final String adminId = 'FA${DateTime.now().millisecondsSinceEpoch}';
      final String tempPassword = _generateTempPassword();

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: tempPassword,
          );
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Unable to create account.');
      }

      final int now = DateTime.now().millisecondsSinceEpoch;

      await FirebaseDatabase.instance.ref('users/${user.uid}').set(<String, dynamic>{
        'id': user.uid,
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'blockStatus': 'no',
        'roles/fleetAdmin': true,
        'defaultRole': 'fleetAdmin',
        'createdAt': now,
        'updatedAt': now,
      });

      await FirebaseDatabase.instance.ref('fleetAdmins/${user.uid}').set(<String, dynamic>{
        'id': user.uid,
        'fleetAdminId': adminId,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
      });

      await FirebaseDatabase.instance.ref('fleetAdminCredentials/$adminId').set(<String, dynamic>{
        'fleetAdminId': adminId,
        'email': emailController.text.trim(),
        'uid': user.uid,
        'status': 'active',
        'createdAt': now,
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      setState(() {
        generatedAdminId = adminId;
        emailController.clear();
        passwordController.clear();
        nameController.clear();
        phoneController.clear();
      });

      _showSuccessDialog(adminId, tempPassword);
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Registration failed.');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  bool _validate() {
    if (nameController.text.trim().length < 3) {
      _showMessage('Full name must be at least 3 characters.');
      return false;
    }
    if (phoneController.text.trim().length < 7) {
      _showMessage('Phone number must be at least 7 characters.');
      return false;
    }
    if (!emailController.text.contains('@')) {
      _showMessage('Enter a valid email address.');
      return false;
    }
    return true;
  }

  String _generateTempPassword() {
    return 'TempPass${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  void _showSuccessDialog(String adminId, String tempPassword) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fleet Admin Registered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fleet Admin has been successfully registered.'),
              const SizedBox(height: 16),
              const Text(
                'Fleet Admin ID:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                adminId,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: SoltechColors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Temporary Password:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                tempPassword,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: SoltechColors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share these credentials with the fleet admin. They must change the password on first login.',
                style: TextStyle(
                  fontSize: 12,
                  color: SoltechColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoltechColors.canvas,
      appBar: AppBar(
        title: const Text('Register Fleet Admin'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SoltechColors.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SoltechColors.amber.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: SoltechColors.amber,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fleet Admin Registration',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: SoltechColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Register a new fleet admin with system-generated ID.',
                          style: TextStyle(color: SoltechColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _field(nameController, 'Full Name', Icons.person_outline),
            const SizedBox(height: 14),
            _field(
              phoneController,
              'Phone Number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _field(
              emailController,
              'Email Address',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: isBusy ? null : _registerFleetAdmin,
              child: isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Register Fleet Admin'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}
