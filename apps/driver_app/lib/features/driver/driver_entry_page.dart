import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/app_role.dart';
import '../../core/session/app_session.dart';

class DriverEntryPage extends StatefulWidget {
  const DriverEntryPage({super.key});

  @override
  State<DriverEntryPage> createState() => _DriverEntryPageState();
}

class _DriverEntryPageState extends State<DriverEntryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  final TextEditingController _driverIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _driverIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    final bool isMounted = mounted;
    final AppSession? session = isMounted ? context.read<AppSession>() : null;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final String driverId = _driverIdController.text.trim().toUpperCase();
      final String password = _passwordController.text.trim();

      if (driverId.isEmpty) throw Exception('Enter the Driver ID provided by your Fleet Admin.');
      if (password.length < 6) throw Exception('Password must be at least 6 characters.');

      final DatabaseEvent credentialEvent = await _database.ref('driverCredentials/$driverId').once();
      if (credentialEvent.snapshot.value is! Map) {
        throw Exception('Driver ID was not found. Contact your Fleet Admin.');
      }

      final Map<Object?, Object?> credential = Map<Object?, Object?>.from(credentialEvent.snapshot.value as Map);
      if ((credential['status'] ?? 'active').toString() != 'active') {
        throw Exception('This Driver ID is not active. Contact your Fleet Admin.');
      }

      final String email = (credential['email'] ?? '').toString().trim();
      if (!email.contains('@')) throw Exception('Driver login is incomplete. Contact your Fleet Admin.');

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (session == null) return;
      await session.completeAuthentication(AppRole.driver);
      if (!mounted) return;
      if (session.status != AppSessionStatus.ready && session.status != AppSessionStatus.driverPending) {
        final String error = session.message ?? 'This account cannot use the driver app.';
        await session.signOut();
        throw Exception(error);
      }
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      if (!mounted) return;
      _showMessage(e.message ?? 'Driver login failed.');
    } catch (e) {
      await _auth.signOut();
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFEAF7EF),
                    child: Icon(Icons.local_taxi_outlined, size: 38, color: SoltechColors.green),
                  ),
                  const SizedBox(height: 12),
                  const Text('SOLTECH DRIVER', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: SoltechColors.ink)),
                  const SizedBox(height: 6),
                  const Text('Driver accounts are created by approved Fleet Admins.', textAlign: TextAlign.center, style: TextStyle(color: SoltechColors.muted)),
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
                        const Text('Driver Login', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: SoltechColors.ink)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _driverIdController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(prefixIcon: const Icon(Icons.badge_outlined), labelText: 'Driver ID', hintText: 'Enter your Driver ID', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _busy ? null : _login,
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'),
                        ),
                        const SizedBox(height: 12),
                        const Text('No self-registration is available. Contact your Fleet Admin if you do not have credentials.', textAlign: TextAlign.center, style: TextStyle(color: SoltechColors.muted, fontSize: 12)),
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
}
