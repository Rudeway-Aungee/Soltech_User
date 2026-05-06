// CODE COMMENTS -------------------------------------------------------------
// Purpose: Fleet dashboard with vehicles, drivers, trips, earnings, and cash/digital ledger.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Fleet Control main dashboard.
// Fleet Admins manage vehicles, view trips, monitor online drivers, track earnings,
// review ledger totals, and manage the fleet after Super Admin approval.
// ---------------------------------------------------------------------------

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/fleet_models.dart';
import '../../core/session/app_session.dart';
import '../../core/widgets/role_switcher_button.dart';
import 'package:soltech_master_app/core/models/driver_profile_model.dart';
import 'package:soltech_master_app/core/models/ride_request_model.dart';
import 'package:soltech_master_app/features/fleet_control/fleet_control_driver_management_page.dart';

class FleetControlHomePage extends StatefulWidget {
  const FleetControlHomePage({super.key});

  @override
  State<FleetControlHomePage> createState() => _FleetControlHomePageState();
}

// Fleet Control State controls dashboard tabs and opens vehicle/profile dialogs.
class _FleetControlHomePageState extends State<FleetControlHomePage> {
  int _selectedIndex = 0;

  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    final String? fleetId = context.watch<AppSession>().activeFleetId;
    if (fleetId == null || fleetId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No active fleet found for this account.')),
      );
    }

    final List<Widget> pages = <Widget>[
      _DashboardTab(
        fleetId: fleetId,
        onAddVehicle: () => _showVehicleDialog(fleetId),
        onCreateDriver: () => _openCreateDriver(fleetId),
        onViewLedger: () => setState(() => _selectedIndex = 4),
      ),
      _VehiclesTab(
        fleetId: fleetId,
        onAddVehicle: () => _showVehicleDialog(fleetId),
        onEditVehicle: (FleetVehicle vehicle) =>
            _showVehicleDialog(fleetId, vehicle: vehicle),
        onArchiveVehicle: _archiveVehicle,
      ),
      _DriversTab(
        fleetId: fleetId,
        onCreateDriver: () => _openCreateDriver(fleetId),
        onBlockDriver: _blockDriver,
        onActivateDriver: _activateDriver,
        onAssignVehicle: _showAssignVehicleDialog,
      ),
      _TripsTab(fleetId: fleetId),
      _LedgerTab(fleetId: fleetId),
      _FleetAccountTab(
        fleetId: fleetId,
        onEditFleet: () => _showFleetDialog(fleetId),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fleet Control',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [RoleSwitcherButton()],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: SoltechColors.green,
        unselectedItemColor: Colors.grey,
        onTap: (int index) => setState(() => _selectedIndex = index),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.local_taxi_outlined), label: 'Vehicles'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Drivers'),
          BottomNavigationBarItem(icon: Icon(Icons.route_outlined), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Ledger'),
          BottomNavigationBarItem(icon: Icon(Icons.business_outlined), label: 'Account'),
        ],
      ),
    );
  }

  Future<void> _openCreateDriver(String fleetId) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FleetControlDriverManagementPage(fleetId: fleetId),
      ),
    );
  }

  Future<void> _showVehicleDialog(String fleetId, {FleetVehicle? vehicle}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _VehicleEditorDialog(
          vehicle: vehicle,
          onSave: (_VehicleFormData data) async {
            final int now = DateTime.now().millisecondsSinceEpoch;
            final String vehicleId =
                vehicle?.id ?? _db.child('fleetVehicles/$fleetId').push().key!;

            await _db.child('fleetVehicles/$fleetId/$vehicleId').update(<String, dynamic>{
              'id': vehicleId,
              'fleetId': fleetId,
              'make': data.make,
              'model': data.model,
              'color': data.color,
              'plateNumber': data.plateNumber,
              'serviceType': 'taxi',
              'status': vehicle?.status ?? 'active',
              'createdAt': vehicle?.createdAt == 0 ? now : vehicle?.createdAt ?? now,
              'updatedAt': now,
            });
          },
        );
      },
    );
  }

  // Archives a vehicle instead of deleting it, so old trip records remain traceable.
  Future<void> _archiveVehicle(FleetVehicle vehicle) async {
    await _db.child('fleetVehicles/${vehicle.fleetId}/${vehicle.id}').update(<String, dynamic>{
      'status': 'archived',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _blockDriver(String fleetId, String driverId) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _db.child('fleetDrivers/$fleetId/$driverId').update(<String, dynamic>{
      'blockStatus': 'yes',
      'updatedAt': now,
    });
    await _db.child('drivers/$driverId').update(<String, dynamic>{
      'blockStatus': 'yes',
      'onlineStatus': 'offline',
      'updatedAt': now,
    });
    await _db.child('onlineDrivers/$driverId').remove();
  }

  Future<void> _activateDriver(String fleetId, String driverId) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _db.child('fleetDrivers/$fleetId/$driverId').update(<String, dynamic>{
      'blockStatus': 'no',
      'approvalStatus': 'approved',
      'updatedAt': now,
    });
    await _db.child('drivers/$driverId').update(<String, dynamic>{
      'blockStatus': 'no',
      'approvalStatus': 'approved',
      'updatedAt': now,
    });
  }

  Future<void> _showAssignVehicleDialog(String fleetId, String driverId, String currentVehicleId) async {
    final List<FleetVehicle> vehicles = await _loadVehicles(fleetId);
    String selectedVehicleId = currentVehicleId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Assign Driver to Vehicle'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedVehicleId.isEmpty ? null : selectedVehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: vehicles
                    .where((FleetVehicle vehicle) => vehicle.status != 'archived')
                    .map((FleetVehicle vehicle) => DropdownMenuItem<String>(
                          value: vehicle.id,
                          child: Text('${vehicle.plateNumber} - ${vehicle.displayName}'),
                        ))
                    .toList(),
                onChanged: (String? value) => setDialogState(() => selectedVehicleId = value ?? ''),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    FleetVehicle? selectedVehicle;
                    for (final FleetVehicle item in vehicles) {
                      if (item.id == selectedVehicleId) {
                        selectedVehicle = item;
                        break;
                      }
                    }
                    final int now = DateTime.now().millisecondsSinceEpoch;
                    await _db.child('fleetDrivers/$fleetId/$driverId').update(<String, dynamic>{
                      'vehicleId': selectedVehicleId,
                      'updatedAt': now,
                    });
                    await _db.child('drivers/$driverId').update(<String, dynamic>{
                      'vehicleId': selectedVehicleId,
                      if (selectedVehicle != null) 'vehicleModel': '${selectedVehicle.make} ${selectedVehicle.model}'.trim(),
                      if (selectedVehicle != null) 'vehicleColor': selectedVehicle.color,
                      if (selectedVehicle != null) 'plateNumber': selectedVehicle.plateNumber,
                      'updatedAt': now,
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showFleetDialog(String fleetId) async {
    final DatabaseEvent event = await _db.child('fleets/$fleetId').once();

    if (!mounted) {
      return;
    }

    final FleetProfile? fleet =
        FleetProfile.fromSnapshotValue(fleetId, event.snapshot.value);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _FleetProfileEditorDialog(
          fleet: fleet,
          onSave: (_FleetProfileFormData data) async {
            await _db.child('fleets/$fleetId').update(<String, dynamic>{
              'name': data.name,
              'phone': data.phone,
              'email': data.email,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });
          },
        );
      },
    );
  }

  Future<List<FleetVehicle>> _loadVehicles(String fleetId) async {
    final DatabaseEvent event = await _db.child('fleetVehicles/$fleetId').once();
    return _parseChildren<FleetVehicle>(
      event.snapshot.value,
      (String id, Object? value) => FleetVehicle.fromSnapshotValue(id, fleetId, value),
    );
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      textCapitalization: label.contains('Plate') ? TextCapitalization.characters : TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _VehicleFormData {
  const _VehicleFormData({
    required this.make,
    required this.model,
    required this.color,
    required this.plateNumber,
  });

  final String make;
  final String model;
  final String color;
  final String plateNumber;
}

class _VehicleEditorDialog extends StatefulWidget {
  const _VehicleEditorDialog({
    required this.vehicle,
    required this.onSave,
  });

  final FleetVehicle? vehicle;
  final Future<void> Function(_VehicleFormData data) onSave;

  @override
  State<_VehicleEditorDialog> createState() => _VehicleEditorDialogState();
}

class _VehicleEditorDialogState extends State<_VehicleEditorDialog> {
  late final TextEditingController makeController;
  late final TextEditingController modelController;
  late final TextEditingController colorController;
  late final TextEditingController plateController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    makeController = TextEditingController(text: widget.vehicle?.make ?? '');
    modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    colorController = TextEditingController(text: widget.vehicle?.color ?? '');
    plateController = TextEditingController(text: widget.vehicle?.plateNumber ?? '');
  }

  @override
  void dispose() {
    makeController.dispose();
    modelController.dispose();
    colorController.dispose();
    plateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final _VehicleFormData data = _VehicleFormData(
      make: makeController.text.trim(),
      model: modelController.text.trim(),
      color: colorController.text.trim(),
      plateNumber: plateController.text.trim().toUpperCase(),
    );

    if (data.plateNumber.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plate number is required.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await widget.onSave(data);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save vehicle: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(makeController, 'Make'),
            const SizedBox(height: 12),
            _dialogField(modelController, 'Model'),
            const SizedBox(height: 12),
            _dialogField(colorController, 'Color'),
            const SizedBox(height: 12),
            _dialogField(plateController, 'Plate Number'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _submit,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !isSaving,
      textCapitalization:
          label.contains('Plate') ? TextCapitalization.characters : TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FleetProfileFormData {
  const _FleetProfileFormData({
    required this.name,
    required this.phone,
    required this.email,
  });

  final String name;
  final String phone;
  final String email;
}

class _FleetProfileEditorDialog extends StatefulWidget {
  const _FleetProfileEditorDialog({
    required this.fleet,
    required this.onSave,
  });

  final FleetProfile? fleet;
  final Future<void> Function(_FleetProfileFormData data) onSave;

  @override
  State<_FleetProfileEditorDialog> createState() => _FleetProfileEditorDialogState();
}

class _FleetProfileEditorDialogState extends State<_FleetProfileEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.fleet?.name ?? '');
    phoneController = TextEditingController(text: widget.fleet?.phone ?? '');
    emailController = TextEditingController(text: widget.fleet?.email ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final _FleetProfileFormData data = _FleetProfileFormData(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
    );

    if (data.name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fleet name is required.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await widget.onSave(data);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save fleet profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fleet Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(nameController, 'Fleet Name'),
            const SizedBox(height: 12),
            _dialogField(phoneController, 'Phone'),
            const SizedBox(height: 12),
            _dialogField(emailController, 'Email'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _submit,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !isSaving,
      keyboardType: label == 'Email'
          ? TextInputType.emailAddress
          : label == 'Phone'
              ? TextInputType.phone
              : TextInputType.text,
      textCapitalization: label == 'Email' ? TextCapitalization.none : TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
    );
  }
}

// Dashboard tab summarizes fleet health: vehicles, online drivers, trips, and earnings.
class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.fleetId,
    required this.onAddVehicle,
    required this.onCreateDriver,
    required this.onViewLedger,
  });

  final String fleetId;
  final VoidCallback onAddVehicle;
  final VoidCallback onCreateDriver;
  final VoidCallback onViewLedger;

  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FleetSummary>(
      future: _loadSummary(),
      builder: (BuildContext context, AsyncSnapshot<_FleetSummary> snapshot) {
        final _FleetSummary summary = snapshot.data ?? const _FleetSummary();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async { await _loadSummary(); },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StreamBuilder<DatabaseEvent>(
                stream: _db.child('fleets/$fleetId').onValue,
                builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> fleetSnapshot) {
                  final FleetProfile? fleet = FleetProfile.fromSnapshotValue(fleetId, fleetSnapshot.data?.snapshot.value);
                  return _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: SoltechColors.green.withValues(alpha: 0.12),
                              child: const Icon(Icons.business, color: SoltechColors.green),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fleet?.name ?? 'Fleet Control Dashboard', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  const Text('Vehicles, drivers, trips, distance, earnings, and cash collection records.', style: TextStyle(color: SoltechColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.18,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _MetricCard(label: 'Active Vehicles', value: summary.vehicleCount.toString(), icon: Icons.local_taxi, color: SoltechColors.blue),
                  _MetricCard(label: 'Online Drivers', value: summary.onlineDriverCount.toString(), icon: Icons.radio_button_checked, color: SoltechColors.green),
                  _MetricCard(label: 'Trips Today', value: summary.tripCount.toString(), icon: Icons.route, color: SoltechColors.amber),
                  _MetricCard(label: 'Earnings', value: 'K${summary.completedEarnings.toStringAsFixed(2)}', icon: Icons.payments_outlined, color: SoltechColors.ink),
                ],
              ),
              const SizedBox(height: 14),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _ActionButton(icon: Icons.add_road, label: 'Add Vehicle', onTap: onAddVehicle)),
                        const SizedBox(width: 10),
                        Expanded(child: _ActionButton(icon: Icons.person_add_alt_1, label: 'Create Driver', onTap: onCreateDriver)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(icon: Icons.account_balance_wallet_outlined, label: 'View Cash / Digital Ledger', onTap: onViewLedger, fullWidth: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Live Fleet Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: SoltechColors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SoltechColors.line),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, size: 42, color: SoltechColors.green),
                            SizedBox(height: 8),
                            Text('Live taxi locations appear here when drivers are online.', textAlign: TextAlign.center, style: TextStyle(color: SoltechColors.muted)),
                          ],
                        ),
                      ),
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

  Future<_FleetSummary> _loadSummary() async {
    final DatabaseEvent vehiclesEvent = await _db.child('fleetVehicles/$fleetId').once();
    final DatabaseEvent driversEvent = await _db.child('fleetDrivers/$fleetId').once();
    final DatabaseEvent onlineDriversEvent = await _db.child('onlineDrivers').orderByChild('fleetId').equalTo(fleetId).once();
    final DatabaseEvent ridesEvent = await _db.child('rideRequests').orderByChild('fleetId').equalTo(fleetId).once();

    int tripCount = 0;
    int activeTripCount = 0;
    double completedEarnings = 0;
    double cashLedger = 0;
    double digitalLedger = 0;

    if (ridesEvent.snapshot.value is Map) {
      final Map<Object?, Object?> rides = Map<Object?, Object?>.from(ridesEvent.snapshot.value as Map);
      for (final Object? value in rides.values) {
        if (value is! Map) continue;
        final Map<Object?, Object?> ride = Map<Object?, Object?>.from(value);
        final String status = (ride['status'] ?? '').toString();
        final double fare = _doubleFrom(ride['fareEstimate']);
        tripCount++;
        if (status == 'completed') {
          completedEarnings += fare;
          final String paymentMethod = (ride['paymentMethod'] ?? 'cash').toString();
          if (paymentMethod == 'digital') digitalLedger += fare; else cashLedger += fare;
        } else if (status != 'cancelled') {
          activeTripCount++;
        }
      }
    }

    return _FleetSummary(
      vehicleCount: _mapLength(vehiclesEvent.snapshot.value),
      driverCount: _mapLength(driversEvent.snapshot.value),
      onlineDriverCount: _mapLength(onlineDriversEvent.snapshot.value),
      tripCount: tripCount,
      activeTripCount: activeTripCount,
      completedEarnings: completedEarnings,
      cashLedger: cashLedger,
      digitalLedger: digitalLedger,
    );
  }
}

// Vehicles tab lists taxis registered under the fleet.
class _VehiclesTab extends StatelessWidget {
  const _VehiclesTab({
    required this.fleetId,
    required this.onAddVehicle,
    required this.onEditVehicle,
    required this.onArchiveVehicle,
  });

  final String fleetId;
  final VoidCallback onAddVehicle;
  final ValueChanged<FleetVehicle> onEditVehicle;
  final ValueChanged<FleetVehicle> onArchiveVehicle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('fleetVehicles/$fleetId').onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          final List<FleetVehicle> vehicles = _parseChildren<FleetVehicle>(
            snapshot.data?.snapshot.value,
            (String id, Object? value) => FleetVehicle.fromSnapshotValue(id, fleetId, value),
          );

          if (vehicles.isEmpty) {
            return const _EmptyState(icon: Icons.local_taxi_outlined, title: 'No vehicles yet', body: 'Add your taxis before creating driver accounts.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final FleetVehicle vehicle = vehicles[index];
              return _Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.local_taxi_outlined)),
                  title: Text(vehicle.plateNumber.isEmpty ? vehicle.displayName : vehicle.plateNumber, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${vehicle.displayName}\nStatus: ${vehicle.status}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (String action) => action == 'edit' ? onEditVehicle(vehicle) : onArchiveVehicle(vehicle),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Drivers tab lists driver accounts created by this Fleet Admin.
class _DriversTab extends StatelessWidget {
  const _DriversTab({
    required this.fleetId,
    required this.onCreateDriver,
    required this.onBlockDriver,
    required this.onActivateDriver,
    required this.onAssignVehicle,
  });

  final String fleetId;
  final VoidCallback onCreateDriver;
  final void Function(String fleetId, String driverId) onBlockDriver;
  final void Function(String fleetId, String driverId) onActivateDriver;
  final void Function(String fleetId, String driverId, String currentVehicleId) onAssignVehicle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateDriver,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Create Driver'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('fleetDrivers/$fleetId').onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          final List<FleetDriverLink> links = _parseChildren<FleetDriverLink>(
            snapshot.data?.snapshot.value,
            (String id, Object? value) => FleetDriverLink.fromSnapshotValue(id, fleetId, value),
          );

          if (links.isEmpty) {
            return const _EmptyState(
              icon: Icons.group_outlined,
              title: 'No drivers yet',
              body: 'Create driver accounts here. Drivers cannot register themselves.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: links.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final FleetDriverLink link = links[index];
              return _DriverCard(
                link: link,
                onBlock: () => onBlockDriver(fleetId, link.driverId),
                onActivate: () => onActivateDriver(fleetId, link.driverId),
                onAssignVehicle: () => onAssignVehicle(fleetId, link.driverId, link.vehicleId),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.link, required this.onBlock, required this.onActivate, required this.onAssignVehicle});

  final FleetDriverLink link;
  final VoidCallback onBlock;
  final VoidCallback onActivate;
  final VoidCallback onAssignVehicle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('drivers/${link.driverId}').onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final DriverProfileModel? driver = DriverProfileModel.fromSnapshotValue(link.driverId, snapshot.data?.snapshot.value);
        final bool blocked = link.blockStatus == 'yes' || driver?.blockStatus == 'yes';

        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: SoltechColors.green.withValues(alpha: 0.12), child: const Icon(Icons.person, color: SoltechColors.green)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver?.name ?? link.driverId, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        Text(driver?.email ?? 'Driver profile loading...', style: const TextStyle(color: SoltechColors.muted)),
                      ],
                    ),
                  ),
                  _StatusPill(label: blocked ? 'blocked' : driver?.onlineStatus ?? link.approvalStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text('Vehicle: ${driver?.plateNumber.isEmpty == false ? driver!.plateNumber : link.vehicleId.isEmpty ? 'Unassigned' : link.vehicleId}', style: const TextStyle(color: SoltechColors.muted)),
              if (driver != null) Text('${driver.vehicleColor} ${driver.vehicleModel}', style: const TextStyle(color: SoltechColors.muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(onPressed: onAssignVehicle, icon: const Icon(Icons.local_taxi_outlined), label: const Text('Assign Vehicle')),
                  if (blocked)
                    ElevatedButton.icon(onPressed: onActivate, icon: const Icon(Icons.check_circle_outline), label: const Text('Activate'))
                  else
                    OutlinedButton.icon(
                      onPressed: onBlock,
                      icon: const Icon(Icons.block),
                      label: const Text('Block'),
                      style: OutlinedButton.styleFrom(foregroundColor: SoltechColors.red),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Trips tab shows ride history linked to this fleet.
class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.fleetId});

  final String fleetId;

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Unknown time';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('rideRequests').orderByChild('fleetId').equalTo(fleetId).onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final List<RideRequestModel> rides = _parseChildren<RideRequestModel>(
          snapshot.data?.snapshot.value,
          RideRequestModel.fromSnapshotValue,
        )..sort((RideRequestModel a, RideRequestModel b) {
            final int aTime = a.completedAt ?? a.cancelledAt ?? a.createdAt;
            final int bTime = b.completedAt ?? b.cancelledAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rides.isEmpty) {
          return const _EmptyState(
            icon: Icons.route_outlined,
            title: 'No trips yet',
            body: 'Active, completed, and cancelled trips for your fleet will appear here.',
          );
        }

        final double completedEarnings = rides
            .where((RideRequestModel ride) => ride.status == 'completed')
            .fold<double>(0, (double total, RideRequestModel ride) => total + ride.fareEstimate);
        final int completedTrips = rides.where((RideRequestModel ride) => ride.status == 'completed').length;
        final int activeTrips = rides.where((RideRequestModel ride) => !ride.isTerminal).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _MetricCard(label: 'Active', value: activeTrips.toString(), icon: Icons.route_outlined, color: SoltechColors.amber)),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(label: 'Completed', value: completedTrips.toString(), icon: Icons.check_circle_outline, color: SoltechColors.green)),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(label: 'Earnings', value: 'K${completedEarnings.toStringAsFixed(2)}', icon: Icons.payments_outlined, color: SoltechColors.ink)),
              ],
            ),
            const SizedBox(height: 16),
            ...rides.map((RideRequestModel ride) {
              final int timestamp = ride.completedAt ?? ride.cancelledAt ?? ride.createdAt;
              final String driverName = (ride.assignedDriver['name'] ?? '').toString().trim();
              final String vehicle = <String>[
                (ride.assignedDriver['vehicleColor'] ?? '').toString().trim(),
                (ride.assignedDriver['vehicleModel'] ?? '').toString().trim(),
                (ride.assignedDriver['plateNumber'] ?? '').toString().trim(),
              ].where((String value) => value.isNotEmpty).join(' • ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _formatTimestamp(timestamp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          _StatusPill(label: ride.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MiniRow(icon: Icons.my_location, label: ride.pickup.humanReadableAddress ?? ride.pickup.placeName ?? 'Pickup'),
                      _MiniRow(icon: Icons.location_on, label: ride.destination.humanReadableAddress ?? ride.destination.placeName ?? 'Destination'),
                      if (ride.stops.isNotEmpty) _MiniRow(icon: Icons.add_location_alt_outlined, label: '${ride.stops.length} stop(s)'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _SmallChip(icon: Icons.route, label: '${(ride.routeMeters / 1000).toStringAsFixed(1)} km'),
                          _SmallChip(icon: Icons.payments_outlined, label: 'K${ride.fareEstimate.toStringAsFixed(2)}'),
                          _SmallChip(icon: Icons.credit_card, label: ride.paymentMethod.toUpperCase()),
                          _SmallChip(icon: Icons.local_taxi, label: ride.serviceType),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (driverName.isNotEmpty || vehicle.isNotEmpty)
                        Text(
                          [driverName, vehicle].where((String value) => value.isNotEmpty).join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SoltechColors.muted, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SoltechColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: SoltechColors.ink),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// Ledger tab shows cash/digital totals, commissions, and balances.
class _LedgerTab extends StatelessWidget {
  const _LedgerTab({required this.fleetId});

  final String fleetId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FleetSummary>(
      future: _loadLedger(),
      builder: (BuildContext context, AsyncSnapshot<_FleetSummary> snapshot) {
        final _FleetSummary summary = snapshot.data ?? const _FleetSummary();
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash / Digital Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Tracks fares, cash collection, digital payments, and fleet income accountability.', style: TextStyle(color: SoltechColors.muted)),
                  const SizedBox(height: 18),
                  _LedgerTile(label: 'Cash Collected by Drivers', value: 'K${summary.cashLedger.toStringAsFixed(2)}', icon: Icons.money),
                  _LedgerTile(label: 'Digital Payments', value: 'K${summary.digitalLedger.toStringAsFixed(2)}', icon: Icons.credit_card),
                  _LedgerTile(label: 'Total Completed Earnings', value: 'K${summary.completedEarnings.toStringAsFixed(2)}', icon: Icons.account_balance_wallet_outlined),
                  _LedgerTile(label: 'Estimated Platform Commission', value: 'K${(summary.completedEarnings * 0.10).toStringAsFixed(2)}', icon: Icons.percent),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_FleetSummary> _loadLedger() async {
    final DatabaseEvent ridesEvent = await FirebaseDatabase.instance.ref('rideRequests').orderByChild('fleetId').equalTo(fleetId).once();
    double completed = 0;
    double cash = 0;
    double digital = 0;
    int trips = 0;
    if (ridesEvent.snapshot.value is Map) {
      final Map<Object?, Object?> rides = Map<Object?, Object?>.from(ridesEvent.snapshot.value as Map);
      for (final Object? value in rides.values) {
        if (value is! Map) continue;
        final Map<Object?, Object?> ride = Map<Object?, Object?>.from(value);
        if ((ride['status'] ?? '').toString() != 'completed') continue;
        final double fare = _doubleFrom(ride['fareEstimate']);
        completed += fare;
        trips++;
        if ((ride['paymentMethod'] ?? 'cash').toString() == 'digital') digital += fare; else cash += fare;
      }
    }
    return _FleetSummary(tripCount: trips, completedEarnings: completed, cashLedger: cash, digitalLedger: digital);
  }
}

class _FleetAccountTab extends StatelessWidget {
  const _FleetAccountTab({required this.fleetId, required this.onEditFleet});

  final String fleetId;
  final VoidCallback onEditFleet;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('fleets/$fleetId').onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final FleetProfile? fleet = FleetProfile.fromSnapshotValue(fleetId, snapshot.data?.snapshot.value);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fleet Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  _MiniRow(icon: Icons.business, label: fleet?.name ?? 'Fleet Name'),
                  _MiniRow(icon: Icons.phone, label: fleet?.phone ?? 'Phone'),
                  _MiniRow(icon: Icons.email, label: fleet?.email ?? 'Email'),
                  _MiniRow(icon: Icons.verified_user, label: 'Status: ${fleet?.status ?? 'active'}'),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(onPressed: onEditFleet, icon: const Icon(Icons.edit), label: const Text('Edit Fleet Profile')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.read<AppSession>().signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoltechColors.line),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // This card is used in both GridView cards and Row/ListView summary cards.
    // Do NOT use Spacer/Expanded inside this Column, because some parent widgets
    // such as ListView give the card an unbounded height. A Spacer needs a fixed
    // height to divide, and it caused the RenderFlex unbounded-height crash.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoltechColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SoltechColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.fullWidth = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool good = label == 'approved' || label == 'available' || label == 'active';
    final bool bad = label == 'blocked' || label == 'cancelled' || label == 'rejected';
    final Color color = good ? SoltechColors.green : bad ? SoltechColors.red : SoltechColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: SoltechColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: SoltechColors.green.withValues(alpha: 0.10), child: Icon(icon, color: SoltechColors.green)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: SoltechColors.muted),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: SoltechColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _FleetSummary {
  const _FleetSummary({
    this.vehicleCount = 0,
    this.driverCount = 0,
    this.onlineDriverCount = 0,
    this.tripCount = 0,
    this.activeTripCount = 0,
    this.completedEarnings = 0,
    this.cashLedger = 0,
    this.digitalLedger = 0,
  });

  final int vehicleCount;
  final int driverCount;
  final int onlineDriverCount;
  final int tripCount;
  final int activeTripCount;
  final double completedEarnings;
  final double cashLedger;
  final double digitalLedger;
}

List<T> _parseChildren<T>(Object? value, T? Function(String id, Object? value) builder) {
  if (value is! Map) return <T>[];
  final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
  final List<T> result = <T>[];
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    final T? item = builder(entry.key.toString(), entry.value);
    if (item != null) result.add(item);
  }
  return result;
}

int _mapLength(Object? value) {
  if (value is! Map) return 0;
  return value.length;
}

double _doubleFrom(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}
