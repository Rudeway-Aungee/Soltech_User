import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/app_role.dart';
import '../../core/session/app_session.dart';

class PassengerEntryPage extends StatefulWidget {
  const PassengerEntryPage({super.key});

  @override
  State<PassengerEntryPage> createState() => _PassengerEntryPageState();
}

class _PassengerEntryPageState extends State<PassengerEntryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _register = false;
  bool _busy = false;
  bool _loginObscure = true;
  bool _registerObscure = true;
  bool _confirmObscure = true;

  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _loginController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      final String loginValue = _loginController.text.trim();
      final String password = _loginPasswordController.text.trim();

      if (loginValue.isEmpty) throw Exception('Enter your phone number or email.');
      if (password.length < 6) throw Exception('Password must be at least 6 characters.');

      final String email = await _resolvePassengerLoginEmail(loginValue);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _complete();
    });
  }

  Future<void> _registerPassenger() async {
    await _run(() async {
      final String name = _nameController.text.trim();
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();
      final String password = _passwordController.text.trim();
      final String confirmPassword = _confirmPasswordController.text.trim();

      if (name.length < 3) throw Exception('Full name must be at least 3 characters.');
      if (!email.contains('@')) throw Exception('Enter a valid email address.');
      if (phone.length < 7) throw Exception('Phone number must be at least 7 characters.');
      if (password.length < 6) throw Exception('Password must be at least 6 characters.');
      if (password != confirmPassword) throw Exception('Passwords do not match.');

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user == null) throw Exception('Unable to create passenger account.');

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

      await _complete();
    });
  }

  Future<void> _complete() async {
    final AppSession session = context.read<AppSession>();
    await session.completeAuthentication(AppRole.passenger);
    if (!mounted) return;
    if (session.status != AppSessionStatus.ready) {
      final String error = session.message ?? 'This account cannot use the passenger app.';
      await session.signOut();
      throw Exception(error);
    }
  }

  Future<String> _resolvePassengerLoginEmail(String loginValue) async {
    if (loginValue.contains('@')) return loginValue;

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
      if (userValue is! Map) continue;
      final Map<Object?, Object?> user = Map<Object?, Object?>.from(userValue);
      final Object? rolesValue = user['roles'];
      final bool isPassenger = rolesValue is Map &&
          Map<Object?, Object?>.from(rolesValue)['passenger'] == true;
      final String email = (user['email'] ?? '').toString().trim();
      if (isPassenger && email.contains('@')) return email;
    }

    throw Exception('No passenger account was found for that phone number.');
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
                  _header(),
                  const SizedBox(height: 24),
                  _card(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFEAF7EF),
          child: Icon(Icons.person_pin_circle_outlined, size: 38, color: SoltechColors.green),
        ),
        SizedBox(height: 12),
        Text('SOLTECH', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: SoltechColors.ink)),
        SizedBox(height: 6),
        Text('Passenger Taxi Booking', style: TextStyle(color: SoltechColors.muted)),
      ],
    );
  }

  Widget _card() {
    return Container(
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
          Text(_register ? 'Passenger Registration' : 'Passenger Login', textAlign: TextAlign.center, style: _titleStyle),
          const SizedBox(height: 16),
          if (_register) ...[
            _field(_nameController, 'Full Name', 'Enter full name', Icons.person_outline),
            const SizedBox(height: 12),
            _field(_emailController, 'Email', 'Enter email address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_phoneController, 'Phone', 'Enter phone number', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _passwordField(_passwordController, 'Password', 'Enter your password', _registerObscure, () => setState(() => _registerObscure = !_registerObscure)),
            const SizedBox(height: 12),
            _passwordField(_confirmPasswordController, 'Confirm Password', 'Re-enter password', _confirmObscure, () => setState(() => _confirmObscure = !_confirmObscure)),
            const SizedBox(height: 18),
            _primaryButton('Create Passenger Account', _registerPassenger),
            TextButton(onPressed: _busy ? null : () => setState(() => _register = false), child: const Text('Already have an account? Login')),
          ] else ...[
            _field(_loginController, 'Phone / Email', 'Enter phone number or email', Icons.person_outline, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _passwordField(_loginPasswordController, 'Password', 'Enter your password', _loginObscure, () => setState(() => _loginObscure = !_loginObscure)),
            const SizedBox(height: 18),
            _primaryButton('Login', _login),
            TextButton(onPressed: _busy ? null : () => setState(() => _register = true), child: const Text('New passenger? Create Passenger Account')),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
    );
  }

  Widget _passwordField(TextEditingController controller, String label, String hint, bool obscure, VoidCallback onToggle) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: onToggle),
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _primaryButton(String label, Future<void> Function() onPressed) {
    return ElevatedButton(
      onPressed: _busy ? null : onPressed,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
    );
  }
}

const TextStyle _titleStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: SoltechColors.ink);
