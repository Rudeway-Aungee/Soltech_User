import 'package:flutter/material.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/services/driver_management_service.dart';

class FleetOwnerDriverManagementPage extends StatefulWidget {
  const FleetOwnerDriverManagementPage({
    super.key,
    required this.fleetId,
  });

  final String fleetId;

  @override
  State<FleetOwnerDriverManagementPage> createState() =>
      _FleetOwnerDriverManagementPageState();
}

class _FleetOwnerDriverManagementPageState
    extends State<FleetOwnerDriverManagementPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController vehicleModelController = TextEditingController();
  final TextEditingController vehicleColorController = TextEditingController();
  final TextEditingController plateController = TextEditingController();

  bool isBusy = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    vehicleModelController.dispose();
    vehicleColorController.dispose();
    plateController.dispose();
    super.dispose();
  }

  Future<void> _addDriver() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      isBusy = true;
    });

    try {
      final Map<String, String> result =
          await DriverManagementService().addDriverToFleet(
        fleetId: widget.fleetId,
        driverName: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        vehicleModel: vehicleModelController.text.trim(),
        vehicleColor: vehicleColorController.text.trim(),
        plateNumber: plateController.text.trim(),
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
    if (vehicleModelController.text.trim().isEmpty) {
      _showMessage('Vehicle model is required.');
      return false;
    }
    if (vehicleColorController.text.trim().isEmpty) {
      _showMessage('Vehicle color is required.');
      return false;
    }
    if (plateController.text.trim().length < 4) {
      _showMessage('Plate number is required.');
      return false;
    }
    return true;
  }

  void _clearForm() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    vehicleModelController.clear();
    vehicleColorController.clear();
    plateController.clear();
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
          title: const Text('Driver Added Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Driver has been added to your fleet.'),
              const SizedBox(height: 16),
              const Text(
                'Driver ID:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                credentials['driverId'] ?? '',
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
                credentials['password'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: SoltechColors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share these credentials with the driver. They must change the password on first login.',
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
        title: const Text('Add Driver'),
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
                    backgroundColor: SoltechColors.green.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.local_taxi_outlined,
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
                          'Add Driver',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: SoltechColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add a new driver to your fleet.',
                          style: TextStyle(color: SoltechColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _field(nameController, 'Driver Name', Icons.person_outline),
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
              vehicleModelController,
              'Vehicle Model',
              Icons.directions_car_outlined,
            ),
            const SizedBox(height: 14),
            _field(
              vehicleColorController,
              'Vehicle Color',
              Icons.palette_outlined,
            ),
            const SizedBox(height: 14),
            _field(
              plateController,
              'Plate Number',
              Icons.badge_outlined,
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: isBusy ? null : _addDriver,
              child: isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Driver'),
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
      textCapitalization: label.contains('Plate')
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}
