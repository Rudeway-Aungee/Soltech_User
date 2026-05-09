// CODE COMMENTS -------------------------------------------------------------
// Purpose: Fleet Admin screen for creating and managing driver accounts.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Fleet Control driver management screen.
// Fleet Admins create driver accounts, assign them to vehicles, and manage driver access.
// ---------------------------------------------------------------------------

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/fleet_models.dart';
import '../../core/services/driver_management_service.dart';

class FleetControlDriverManagementPage extends StatefulWidget {
  const FleetControlDriverManagementPage({
    super.key,
    required this.fleetId,
  });

  final String fleetId;

  @override
  State<FleetControlDriverManagementPage> createState() =>
      _FleetControlDriverManagementPageState();
}

class _FleetControlDriverManagementPageState
    extends State<FleetControlDriverManagementPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();

  bool isBusy = false;
  String selectedVehicleId = '';
  List<FleetVehicle> vehicles = <FleetVehicle>[];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    licenseController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final DatabaseEvent event = await FirebaseDatabase.instance
        .ref('fleetVehicles/${widget.fleetId}')
        .once();

    final List<FleetVehicle> loaded = <FleetVehicle>[];
    if (event.snapshot.value is Map) {
      final Map<Object?, Object?> raw = Map<Object?, Object?>.from(
        event.snapshot.value as Map,
      );
      for (final MapEntry<Object?, Object?> entry in raw.entries) {
        final FleetVehicle? vehicle = FleetVehicle.fromSnapshotValue(
          entry.key.toString(),
          widget.fleetId,
          entry.value,
        );
        if (vehicle != null && vehicle.status != 'archived') {
          loaded.add(vehicle);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      vehicles = loaded;
      if (selectedVehicleId.isEmpty && vehicles.isNotEmpty) {
        selectedVehicleId = vehicles.first.id;
      }
    });
  }

  Future<void> _addDriver() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      isBusy = true;
    });

    try {
      FleetVehicle? vehicle;
      for (final FleetVehicle item in vehicles) {
        if (item.id == selectedVehicleId) {
          vehicle = item;
          break;
        }
      }

      final Map<String, String> result =
          await DriverManagementService().addDriverToFleet(
        fleetId: widget.fleetId,
        driverName: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        licenseNumber: licenseController.text.trim(),
        vehicleId: vehicle?.id ?? '',
        vehicleModel: vehicle == null
            ? ''
            : '${vehicle.make} ${vehicle.model}'.trim(),
        vehicleColor: vehicle?.color ?? '',
        plateNumber: vehicle?.plateNumber ?? '',
      );

      if (!mounted) {
        return;
      }

      _showSuccessDialog(result);
      _clearForm();
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
      _showMessage('Driver name must be at least 3 characters.');
      return false;
    }
    if (!emailController.text.contains('@')) {
      _showMessage('Enter a valid email address.');
      return false;
    }
    if (phoneController.text.trim().length < 7) {
      _showMessage('Phone number must be at least 7 characters.');
      return false;
    }
    if (licenseController.text.trim().isEmpty) {
      _showMessage('Driver licence number is required.');
      return false;
    }
    if (vehicles.isEmpty) {
      _showMessage('Add at least one vehicle before creating a driver.');
      return false;
    }
    if (selectedVehicleId.isEmpty) {
      _showMessage('Select a vehicle for this driver.');
      return false;
    }
    return true;
  }

  void _clearForm() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    licenseController.clear();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  void _showSuccessDialog(Map<String, String> credentials) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Driver Account Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The driver has been registered under your fleet. Give these login details to the driver.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Driver ID',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                credentials['driverId'] ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  color: SoltechColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Temporary Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                credentials['password'] ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  color: SoltechColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Drivers cannot register themselves. They must use this Driver ID and password from Fleet Control.',
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
      appBar: AppBar(title: const Text('Create Driver Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: SoltechColors.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SoltechColors.green.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: SoltechColors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register Driver',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: SoltechColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Create a driver login and assign the driver to one of your approved vehicles.',
                          style: TextStyle(color: SoltechColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _infoCard(),
            const SizedBox(height: 22),
            _field(nameController, 'Driver Full Name', Icons.person_outline),
            const SizedBox(height: 14),
            _field(
              emailController,
              'Email Address',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _field(
              phoneController,
              'Phone Number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _field(
              licenseController,
              'Driver Licence Number',
              Icons.credit_card_outlined,
            ),
            const SizedBox(height: 14),
            _vehicleDropdown(),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: isBusy ? null : _addDriver,
              icon: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(isBusy ? 'Creating Driver...' : 'Create Driver Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoltechColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoltechColors.blue.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: SoltechColors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Drivers do not self-register. Fleet Control creates driver accounts and gives each driver a Driver ID and temporary password.',
              style: TextStyle(color: SoltechColors.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedVehicleId.isEmpty ? null : selectedVehicleId,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.local_taxi_outlined),
        labelText: 'Assign Vehicle',
      ),
      items: vehicles
          .map(
            (FleetVehicle vehicle) => DropdownMenuItem<String>(
              value: vehicle.id,
              child: Text('${vehicle.plateNumber} - ${vehicle.displayName}'),
            ),
          )
          .toList(),
      onChanged: isBusy
          ? null
          : (String? value) {
              setState(() {
                selectedVehicleId = value ?? '';
              });
            },
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
      textCapitalization: label.contains('Licence')
          ? TextCapitalization.characters
          : TextCapitalization.words,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}
