import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soltech_master_app/core/session/app_session.dart';
import 'package:soltech_master_app/core/widgets/role_switcher_button.dart';
import 'package:soltech_master_app/model/driver_profile_model.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  Future<void> _logout(BuildContext context) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(currentUser.uid)
          .update(<String, dynamic>{
            'onlineStatus': 'offline',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
      await FirebaseDatabase.instance
          .ref()
          .child('onlineDrivers')
          .child(currentUser.uid)
          .remove();
    }

    if (!context.mounted) {
      return;
    }

    await context.read<AppSession>().signOut();
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view account details.')),
      );
    }

    final DatabaseReference driverRef = FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(currentUser.uid);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Driver Account',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: driverRef.onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final DriverProfileModel? profile =
              DriverProfileModel.fromSnapshotValue(
                currentUser.uid,
                snapshot.data?.snapshot.value,
              );

          if (profile == null) {
            return const Center(
              child: Text(
                'Driver profile unavailable.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.black12,
                      backgroundImage: AssetImage('assets/avatar.webp'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: profile.isApproved
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Approval: ${profile.approvalStatus}',
                        style: TextStyle(
                          color: profile.isApproved
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${profile.onlineStatus}',
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const RoleSwitcherButton(),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _detailTile(
                      icon: Icons.phone,
                      label: 'Phone Number',
                      value: profile.phone,
                    ),
                    const Divider(height: 1),
                    _detailTile(
                      icon: Icons.email,
                      label: 'Email',
                      value: profile.email,
                    ),
                    const Divider(height: 1),
                    _detailTile(
                      icon: Icons.local_taxi,
                      label: 'Service Type',
                      value: profile.serviceType,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _detailTile(
                      icon: Icons.directions_car,
                      label: 'Vehicle Model',
                      value: profile.vehicleModel,
                    ),
                    const Divider(height: 1),
                    _detailTile(
                      icon: Icons.palette_outlined,
                      label: 'Vehicle Color',
                      value: profile.vehicleColor,
                    ),
                    const Divider(height: 1),
                    _detailTile(
                      icon: Icons.badge_outlined,
                      label: 'Plate Number',
                      value: profile.plateNumber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
