import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_driver_app/auth/signin_page.dart';
import 'package:soltech_driver_app/global.dart';
import 'package:soltech_driver_app/model/driver_profile_model.dart';
import 'package:soltech_driver_app/pages/home_page.dart';

class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({super.key, this.initialStatus = 'pending'});

  final String initialStatus;

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  bool _isRefreshing = false;
  String _approvalStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _approvalStatus = widget.initialStatus;
  }

  Future<void> _refreshApprovalStatus() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    final DatabaseEvent event = await FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(user.uid)
        .once();

    if (!mounted) {
      return;
    }

    setState(() {
      _isRefreshing = false;
    });

    final DriverProfileModel? profile = DriverProfileModel.fromSnapshotValue(
      user.uid,
      event.snapshot.value,
    );

    if (profile == null) {
      associateMethods.showSnackBarMsg('Driver profile not found.', context);
      return;
    }

    if (profile.isBlocked) {
      await _signOut();
      if (!mounted) {
        return;
      }

      associateMethods.showSnackBarMsg('Driver account blocked.', context);
      return;
    }

    if (profile.isApproved) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (BuildContext context) => const HomePage()),
        (Route<dynamic> route) => false,
      );
      return;
    }

    setState(() {
      _approvalStatus = profile.approvalStatus;
    });
  }

  Future<void> _signOut() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(user.uid)
          .update(<String, dynamic>{
            'onlineStatus': 'offline',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
      await FirebaseDatabase.instance
          .ref()
          .child('onlineDrivers')
          .child(user.uid)
          .remove();
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (BuildContext context) => const SignInPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRejected = _approvalStatus == 'rejected';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: isRejected
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                    size: 46,
                    color: isRejected ? Colors.redAccent : Colors.orange,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  isRejected ? 'Approval Rejected' : 'Approval Pending',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isRejected
                      ? 'This driver account has not been approved. Contact the admin team for help.'
                      : 'Your driver profile is waiting for admin approval. Refresh this page after your account has been approved.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isRefreshing ? null : _refreshApprovalStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isRefreshing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Refresh Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _signOut,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
