import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:soltech_master_app/core/session/app_session.dart';
import 'package:soltech_master_app/core/widgets/role_switcher_button.dart';
import 'package:soltech_master_app/global.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, BuildContext sheetContext) async {
    Navigator.pop(sheetContext); // Close the bottom sheet using its own context
    await Future.delayed(const Duration(milliseconds: 200)); // Small delay for sheet to close
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null && mounted) {
        setState(() {
          _profileImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        associateMethods.showSnackBarMsg('Could not pick image: $e', context);
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: () => _pickImage(ImageSource.camera, context),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                ),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('Use your camera'),
              ),
              const SizedBox(height: 8),
              ListTile(
                onTap: () => _pickImage(ImageSource.gallery, context),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.white, size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('Browse your photos'),
              ),
              if (_profileImage != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  onTap: () {
                    setState(() => _profileImage = null);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red[100], shape: BoxShape.circle),
                    child: const Icon(Icons.delete, color: Colors.red, size: 22),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.red)),
                  subtitle: const Text('Revert to default'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your account.')),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/${currentUser.uid}').onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final Map<Object?, Object?> userMap =
            snapshot.data?.snapshot.value is Map
                ? Map<Object?, Object?>.from(snapshot.data!.snapshot.value as Map)
                : <Object?, Object?>{};

        final String displayName = (userMap['name'] ?? userName).toString().trim();
        final String displayPhone = (userMap['phone'] ?? userPhone).toString().trim();
        final String displayEmail = (userMap['email'] ?? currentUser.email ?? 'Unknown Email').toString().trim();

        if (displayName.isNotEmpty) {
          userName = displayName;
        }
        if (displayPhone.isNotEmpty) {
          userPhone = displayPhone;
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.black12,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!) as ImageProvider
                          : const AssetImage('assets/avatar.webp'),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImagePickerSheet,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  displayName.isNotEmpty ? displayName : 'User Name',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'User Profile',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Personal Information Section
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.grey),
                  title: const Text('Mobile Number', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: Text(displayPhone.isNotEmpty ? displayPhone : 'Not Set', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                const Divider(height: 1, thickness: 1),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.grey),
                  title: const Text('Email', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: Text(displayEmail, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                const Divider(height: 1, thickness: 1),
                ListTile(
                  leading: const Icon(Icons.lock, color: Colors.grey),
                  title: const Text('Password', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: const Text('********', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Change', style: TextStyle(color: Colors.green)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Settings Section
          const Text(
            'Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info, color: Colors.black),
                  title: const Text('About', style: TextStyle(fontSize: 16, color: Colors.black87)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {},
                ),
                const Divider(height: 1, thickness: 1),
                const RoleSwitcherButton(),
                const Divider(height: 1, thickness: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(fontSize: 16, color: Colors.red)),
                  onTap: () async {
                    await context.read<AppSession>().signOut();
                  },
                ),
              ],
            ),
          ),
            ],
          ),
        );
      },
    );
  }
}
