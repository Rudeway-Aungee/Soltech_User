import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/fleet_models.dart';
import '../../core/session/app_session.dart';
import '../../core/widgets/role_switcher_button.dart';
import '../../model/driver_profile_model.dart';

class FleetOwnerHomePage extends StatefulWidget {
  const FleetOwnerHomePage({super.key});

  @override
  State<FleetOwnerHomePage> createState() => _FleetOwnerHomePageState();
}

class _FleetOwnerHomePageState extends State<FleetOwnerHomePage> {
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
      _DashboardTab(fleetId: fleetId),
      _VehiclesTab(
        fleetId: fleetId,
        onAddVehicle: () => _showVehicleDialog(fleetId),
        onEditVehicle: (FleetVehicle vehicle) =>
            _showVehicleDialog(fleetId, vehicle: vehicle),
        onArchiveVehicle: _archiveVehicle,
      ),
      _InvitesTab(
        fleetId: fleetId,
        onCreateInvite: () => _showInviteDialog(fleetId),
        onRevokeInvite: _revokeInvite,
      ),
      _DriversTab(
        fleetId: fleetId,
        onApproveDriver: _approveDriver,
        onBlockDriver: _blockDriver,
        onAssignVehicle: _showAssignVehicleDialog,
      ),
      _FleetAccountTab(
        fleetId: fleetId,
        onEditFleet: () => _showFleetDialog(fleetId),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fleet Owner',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: SoltechColors.green,
        unselectedItemColor: Colors.grey,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Invites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            label: 'Drivers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            label: 'Fleet',
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleDialog(
    String fleetId, {
    FleetVehicle? vehicle,
  }) async {
    final TextEditingController makeController = TextEditingController(
      text: vehicle?.make ?? '',
    );
    final TextEditingController modelController = TextEditingController(
      text: vehicle?.model ?? '',
    );
    final TextEditingController colorController = TextEditingController(
      text: vehicle?.color ?? '',
    );
    final TextEditingController plateController = TextEditingController(
      text: vehicle?.plateNumber ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final int now = DateTime.now().millisecondsSinceEpoch;
                final String vehicleId =
                    vehicle?.id ?? _db.child('fleetVehicles/$fleetId').push().key!;
                await _db.child('fleetVehicles/$fleetId/$vehicleId').update(
                  <String, dynamic>{
                    'id': vehicleId,
                    'fleetId': fleetId,
                    'make': makeController.text.trim(),
                    'model': modelController.text.trim(),
                    'color': colorController.text.trim(),
                    'plateNumber': plateController.text.trim().toUpperCase(),
                    'serviceType': 'taxi',
                    'status': vehicle?.status ?? 'active',
                    'createdAt': vehicle?.createdAt == 0
                        ? now
                        : vehicle?.createdAt ?? now,
                    'updatedAt': now,
                  },
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    makeController.dispose();
    modelController.dispose();
    colorController.dispose();
    plateController.dispose();
  }

  Future<void> _archiveVehicle(FleetVehicle vehicle) async {
    await _db.child('fleetVehicles/${vehicle.fleetId}/${vehicle.id}').update(
      <String, dynamic>{
        'status': 'archived',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> _showInviteDialog(String fleetId) async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    String selectedVehicleId = '';
    final List<FleetVehicle> vehicles = await _loadVehicles(fleetId);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Create Driver Invite'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(emailController, 'Driver Email'),
                    const SizedBox(height: 12),
                    _dialogField(phoneController, 'Driver Phone'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedVehicleId.isEmpty
                          ? null
                          : selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Assign Vehicle (optional)',
                      ),
                      items: vehicles
                          .where((FleetVehicle vehicle) {
                            return vehicle.status != 'archived';
                          })
                          .map(
                            (FleetVehicle vehicle) =>
                                DropdownMenuItem<String>(
                                  value: vehicle.id,
                                  child: Text(
                                    '${vehicle.plateNumber} - ${vehicle.displayName}',
                                  ),
                                ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        setDialogState(() {
                          selectedVehicleId = value ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String code = _generateInviteCode();
                    final int now = DateTime.now().millisecondsSinceEpoch;
                    await _db.child('fleetInvites/$code').set(<String, dynamic>{
                      'code': code,
                      'fleetId': fleetId,
                      'vehicleId': selectedVehicleId,
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'status': 'pending',
                      'claimedBy': '',
                      'createdAt': now,
                      'updatedAt': now,
                    });
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      _showMessage('Invite created: $code');
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _revokeInvite(FleetInvite invite) async {
    await _db.child('fleetInvites/${invite.code}').update(<String, dynamic>{
      'status': 'revoked',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _approveDriver(String fleetId, String driverId) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _db.child('fleetDrivers/$fleetId/$driverId').update(
      <String, dynamic>{
        'approvalStatus': 'approved',
        'blockStatus': 'no',
        'updatedAt': now,
      },
    );
    await _db.child('drivers/$driverId').update(<String, dynamic>{
      'approvalStatus': 'approved',
      'blockStatus': 'no',
      'updatedAt': now,
    });
  }

  Future<void> _blockDriver(String fleetId, String driverId) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _db.child('fleetDrivers/$fleetId/$driverId').update(
      <String, dynamic>{'blockStatus': 'yes', 'updatedAt': now},
    );
    await _db.child('drivers/$driverId').update(<String, dynamic>{
      'blockStatus': 'yes',
      'onlineStatus': 'offline',
      'updatedAt': now,
    });
    await _db.child('onlineDrivers/$driverId').remove();
  }

  Future<void> _showAssignVehicleDialog(
    String fleetId,
    String driverId,
    String currentVehicleId,
  ) async {
    final List<FleetVehicle> vehicles = await _loadVehicles(fleetId);
    String selectedVehicleId = currentVehicleId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Assign Vehicle'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedVehicleId.isEmpty ? null : selectedVehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: vehicles
                    .where((FleetVehicle vehicle) {
                      return vehicle.status != 'archived';
                    })
                    .map(
                      (FleetVehicle vehicle) => DropdownMenuItem<String>(
                        value: vehicle.id,
                        child: Text(
                          '${vehicle.plateNumber} - ${vehicle.displayName}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setDialogState(() {
                    selectedVehicleId = value ?? '';
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final int now = DateTime.now().millisecondsSinceEpoch;
                    await _db.child('fleetDrivers/$fleetId/$driverId').update(
                      <String, dynamic>{
                        'vehicleId': selectedVehicleId,
                        'updatedAt': now,
                      },
                    );
                    await _db.child('drivers/$driverId').update(
                      <String, dynamic>{
                        'vehicleId': selectedVehicleId,
                        'updatedAt': now,
                      },
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
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
    final FleetProfile? fleet = FleetProfile.fromSnapshotValue(
      fleetId,
      event.snapshot.value,
    );
    final TextEditingController nameController = TextEditingController(
      text: fleet?.name ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: fleet?.phone ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: fleet?.email ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Fleet'),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _db.child('fleets/$fleetId').update(<String, dynamic>{
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  Future<List<FleetVehicle>> _loadVehicles(String fleetId) async {
    final DatabaseEvent event = await _db.child('fleetVehicles/$fleetId').once();
    return _parseChildren<FleetVehicle>(
      event.snapshot.value,
      (String id, Object? value) =>
          FleetVehicle.fromSnapshotValue(id, fleetId, value),
    );
  }

  String _generateInviteCode() {
    final String time = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final String suffix = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'FLT-$time-$suffix';
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      textCapitalization: label.contains('Plate')
          ? TextCapitalization.characters
          : TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.fleetId});

  final String fleetId;

  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FleetSummary>(
      future: _loadSummary(),
      builder: (BuildContext context, AsyncSnapshot<_FleetSummary> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final _FleetSummary summary = snapshot.data ?? const _FleetSummary();
        return RefreshIndicator(
          onRefresh: () async {
            await _loadSummary();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StreamBuilder<DatabaseEvent>(
                stream: _db.child('fleets/$fleetId').onValue,
                builder: (BuildContext context,
                    AsyncSnapshot<DatabaseEvent> fleetSnapshot) {
                  final FleetProfile? fleet = FleetProfile.fromSnapshotValue(
                    fleetId,
                    fleetSnapshot.data?.snapshot.value,
                  );
                  return _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fleet?.name ?? 'Fleet Dashboard',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Live status, trips, and earnings for your taxi fleet.',
                          style: TextStyle(color: SoltechColors.muted),
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
                childAspectRatio: 1.25,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _MetricCard(
                    label: 'Vehicles',
                    value: summary.vehicleCount.toString(),
                    icon: Icons.directions_car,
                    color: SoltechColors.blue,
                  ),
                  _MetricCard(
                    label: 'Drivers',
                    value: summary.driverCount.toString(),
                    icon: Icons.group,
                    color: SoltechColors.green,
                  ),
                  _MetricCard(
                    label: 'Online',
                    value: summary.onlineDriverCount.toString(),
                    icon: Icons.radio_button_checked,
                    color: SoltechColors.amber,
                  ),
                  _MetricCard(
                    label: 'Earnings',
                    value: '\$${summary.completedEarnings.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                    color: SoltechColors.ink,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Trips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${summary.activeTripCount} active trip${summary.activeTripCount == 1 ? '' : 's'} right now.',
                      style: const TextStyle(color: SoltechColors.muted),
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
    final DatabaseEvent vehiclesEvent = await _db
        .child('fleetVehicles/$fleetId')
        .once();
    final DatabaseEvent driversEvent = await _db
        .child('fleetDrivers/$fleetId')
        .once();
    final DatabaseEvent onlineDriversEvent = await _db
        .child('onlineDrivers')
        .orderByChild('fleetId')
        .equalTo(fleetId)
        .once();
    final DatabaseEvent ridesEvent = await _db
        .child('rideRequests')
        .orderByChild('fleetId')
        .equalTo(fleetId)
        .once();

    final int vehicleCount = _mapLength(vehiclesEvent.snapshot.value);
    final int driverCount = _mapLength(driversEvent.snapshot.value);
    final int onlineDriverCount = _mapLength(onlineDriversEvent.snapshot.value);
    int activeTripCount = 0;
    double completedEarnings = 0;

    if (ridesEvent.snapshot.value is Map) {
      final Map<Object?, Object?> rides = Map<Object?, Object?>.from(
        ridesEvent.snapshot.value as Map,
      );
      for (final Object? value in rides.values) {
        if (value is! Map) {
          continue;
        }

        final Map<Object?, Object?> ride = Map<Object?, Object?>.from(value);
        final String status = (ride['status'] ?? '').toString();
        if (status == 'completed') {
          completedEarnings += _doubleFrom(ride['fareEstimate']);
        } else if (status != 'cancelled') {
          activeTripCount++;
        }
      }
    }

    return _FleetSummary(
      vehicleCount: vehicleCount,
      driverCount: driverCount,
      onlineDriverCount: onlineDriverCount,
      activeTripCount: activeTripCount,
      completedEarnings: completedEarnings,
    );
  }
}

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
        label: const Text('Vehicle'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref('fleetVehicles/$fleetId')
            .onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          final List<FleetVehicle> vehicles = _parseChildren<FleetVehicle>(
            snapshot.data?.snapshot.value,
            (String id, Object? value) =>
                FleetVehicle.fromSnapshotValue(id, fleetId, value),
          );

          if (vehicles.isEmpty) {
            return const _EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles yet',
              body: 'Add taxi vehicles so invites and drivers can be assigned.',
            );
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
                  leading: const CircleAvatar(
                    child: Icon(Icons.local_taxi_outlined),
                  ),
                  title: Text(
                    vehicle.plateNumber.isEmpty
                        ? vehicle.displayName
                        : vehicle.plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${vehicle.displayName}\nStatus: ${vehicle.status}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (String action) {
                      if (action == 'edit') {
                        onEditVehicle(vehicle);
                      } else {
                        onArchiveVehicle(vehicle);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive'),
                        ),
                      ];
                    },
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

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({
    required this.fleetId,
    required this.onCreateInvite,
    required this.onRevokeInvite,
  });

  final String fleetId;
  final VoidCallback onCreateInvite;
  final ValueChanged<FleetInvite> onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateInvite,
        icon: const Icon(Icons.add),
        label: const Text('Invite'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref('fleetInvites')
            .orderByChild('fleetId')
            .equalTo(fleetId)
            .onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          final List<FleetInvite> invites = _parseChildren<FleetInvite>(
            snapshot.data?.snapshot.value,
            FleetInvite.fromSnapshotValue,
          );
          invites.sort(
            (FleetInvite a, FleetInvite b) => b.createdAt.compareTo(a.createdAt),
          );

          if (invites.isEmpty) {
            return const _EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'No invites yet',
              body: 'Create invite codes for drivers to claim during signup.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final FleetInvite invite = invites[index];
              return _Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: invite.isPending
                        ? SoltechColors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.15),
                    child: Icon(
                      invite.isPending
                          ? Icons.confirmation_number
                          : Icons.lock_clock,
                      color: invite.isPending ? SoltechColors.green : Colors.grey,
                    ),
                  ),
                  title: SelectableText(
                    invite.code,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${invite.email.isEmpty ? invite.phone : invite.email}\nStatus: ${invite.status}',
                  ),
                  isThreeLine: true,
                  trailing: invite.isPending
                      ? TextButton(
                          onPressed: () => onRevokeInvite(invite),
                          child: const Text('Revoke'),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriversTab extends StatelessWidget {
  const _DriversTab({
    required this.fleetId,
    required this.onApproveDriver,
    required this.onBlockDriver,
    required this.onAssignVehicle,
  });

  final String fleetId;
  final void Function(String fleetId, String driverId) onApproveDriver;
  final void Function(String fleetId, String driverId) onBlockDriver;
  final void Function(String fleetId, String driverId, String currentVehicleId)
      onAssignVehicle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('fleetDrivers/$fleetId').onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final List<FleetDriverLink> links = _parseChildren<FleetDriverLink>(
          snapshot.data?.snapshot.value,
          (String id, Object? value) =>
              FleetDriverLink.fromSnapshotValue(id, fleetId, value),
        );

        if (links.isEmpty) {
          return const _EmptyState(
            icon: Icons.group_outlined,
            title: 'No fleet drivers yet',
            body: 'Drivers appear here after they claim an invite code.',
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
              onApprove: () => onApproveDriver(fleetId, link.driverId),
              onBlock: () => onBlockDriver(fleetId, link.driverId),
              onAssignVehicle: () =>
                  onAssignVehicle(fleetId, link.driverId, link.vehicleId),
            );
          },
        );
      },
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.link,
    required this.onApprove,
    required this.onBlock,
    required this.onAssignVehicle,
  });

  final FleetDriverLink link;
  final VoidCallback onApprove;
  final VoidCallback onBlock;
  final VoidCallback onAssignVehicle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('drivers/${link.driverId}').onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final DriverProfileModel? driver = DriverProfileModel.fromSnapshotValue(
          link.driverId,
          snapshot.data?.snapshot.value,
        );

        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver?.name ?? link.driverId,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          driver?.email ?? 'Driver profile pending',
                          style: const TextStyle(color: SoltechColors.muted),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: link.blockStatus == 'yes'
                        ? 'blocked'
                        : link.approvalStatus,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Vehicle: ${link.vehicleId.isEmpty ? 'Unassigned' : link.vehicleId}',
                style: const TextStyle(color: SoltechColors.muted),
              ),
              if (driver != null)
                Text(
                  '${driver.vehicleColor} ${driver.vehicleModel} - ${driver.plateNumber}',
                  style: const TextStyle(color: SoltechColors.muted),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onAssignVehicle,
                    icon: const Icon(Icons.directions_car_outlined),
                    label: const Text('Assign'),
                  ),
                  if (link.approvalStatus != 'approved')
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  OutlinedButton.icon(
                    onPressed: onBlock,
                    icon: const Icon(Icons.block),
                    label: const Text('Block'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoltechColors.red,
                    ),
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

class _FleetAccountTab extends StatelessWidget {
  const _FleetAccountTab({required this.fleetId, required this.onEditFleet});

  final String fleetId;
  final VoidCallback onEditFleet;

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('fleets/$fleetId').onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        final FleetProfile? fleet = FleetProfile.fromSnapshotValue(
          fleetId,
          snapshot.data?.snapshot.value,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fleet?.name ?? 'Fleet',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentUser?.email ?? fleet?.email ?? '',
                    style: const TextStyle(color: SoltechColors.muted),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: onEditFleet,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Fleet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _Panel(child: RoleSwitcherButton()),
            const SizedBox(height: 14),
            _Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: SoltechColors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: SoltechColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => context.read<AppSession>().signOut(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: SoltechColors.muted)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool approved = label == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: approved
            ? SoltechColors.green.withValues(alpha: 0.12)
            : SoltechColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: approved ? SoltechColors.green : SoltechColors.amber,
          fontWeight: FontWeight.w800,
        ),
      ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoltechColors.line),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

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
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SoltechColors.muted),
            ),
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
    this.activeTripCount = 0,
    this.completedEarnings = 0,
  });

  final int vehicleCount;
  final int driverCount;
  final int onlineDriverCount;
  final int activeTripCount;
  final double completedEarnings;
}

List<T> _parseChildren<T>(
  Object? value,
  T? Function(String id, Object? value) builder,
) {
  if (value is! Map) {
    return <T>[];
  }

  final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
  final List<T> items = <T>[];
  raw.forEach((Object? key, Object? childValue) {
    final T? item = builder(key.toString(), childValue);
    if (item != null) {
      items.add(item);
    }
  });

  return items;
}

int _mapLength(Object? value) {
  if (value is! Map) {
    return 0;
  }

  return value.length;
}

double _doubleFrom(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse((value ?? '').toString()) ?? 0;
}
