import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/widgets/admin_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/fleet_application_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/fleet_repository.dart';
import '../../data/repositories/user_repository.dart';

class UsersManagementPage extends StatelessWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository userRepository = UserRepository();
    final FleetRepository fleetRepository = FleetRepository();

    return StreamBuilder<List<UserModel>>(
      stream: userRepository.usersStream(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<List<DriverModel>>(
          stream: userRepository.driversStream(),
          builder: (context, driversSnapshot) {
            return StreamBuilder<List<UserModel>>(
              stream: userRepository.superAdminsStream(),
              builder: (context, adminSnapshot) {
                return StreamBuilder<List<FleetApplicationModel>>(
                  stream: fleetRepository.fleetApplicationsStream(),
                  builder: (context, fleetApplicationSnapshot) {
                    final bool isLoading =
                        usersSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            driversSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            adminSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            fleetApplicationSnapshot.connectionState ==
                                ConnectionState.waiting;

                    if (isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<UserModel> users = usersSnapshot.data ?? [];
                    final List<DriverModel> drivers =
                        driversSnapshot.data ?? [];
                    final List<UserModel> superAdmins =
                        adminSnapshot.data ?? [];
                    final List<FleetApplicationModel> fleetApplications =
                        fleetApplicationSnapshot.data ?? [];

                    final List<UserModel> passengers = users.where((user) {
                      return user.isPassenger;
                    }).toList();

                    final Set<String> driverEmails = drivers
                        .map((driver) => _clean(driver.email))
                        .where((email) => email.isNotEmpty)
                        .toSet();

                    final Set<String> driverPhones = drivers
                        .map((driver) => _clean(driver.phone))
                        .where((phone) => phone.isNotEmpty)
                        .toSet();

                    final Set<String> driverNames = drivers
                        .map((driver) => _clean(driver.name))
                        .where((name) => name.isNotEmpty)
                        .toSet();

                    final List<UserModel> driverUsers = users.where((user) {
                      final String email = _clean(user.email);
                      final String phone = _clean(user.phone);
                      final String name = _clean(user.name);

                      final bool alreadyExistsInDrivers =
                          (email.isNotEmpty && driverEmails.contains(email)) ||
                              (phone.isNotEmpty &&
                                  driverPhones.contains(phone)) ||
                              (name.isNotEmpty && driverNames.contains(name));

                      return user.isDriver && !alreadyExistsInDrivers;
                    }).toList();

                    final List<FleetApplicationModel> approvedFleetAdmins =
                        fleetApplications.where((application) {
                      return application.status == 'approved' ||
                          application.status == 'active';
                    }).toList();

                    final int totalUsers = passengers.length +
                        drivers.length +
                        driverUsers.length +
                        approvedFleetAdmins.length +
                        superAdmins.length;

                    return DefaultTabController(
                      length: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 24, 24, 6),
                            child: Text(
                              'Users Management',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'View passengers, drivers, approved fleet admins, and super admin accounts by category.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TabBar(
                                isScrollable: true,
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.muted,
                                indicatorColor: AppColors.primary,
                                tabs: [
                                  Tab(text: 'All ($totalUsers)'),
                                  Tab(text: 'Passengers (${passengers.length})'),
                                  Tab(
                                    text:
                                        'Drivers (${drivers.length + driverUsers.length})',
                                  ),
                                  Tab(
                                    text:
                                        'Fleet Admins (${approvedFleetAdmins.length})',
                                  ),
                                  Tab(
                                    text:
                                        'Super Admins (${superAdmins.length})',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _AllUsersTab(
                                  passengers: passengers,
                                  drivers: drivers,
                                  driverUsers: driverUsers,
                                  approvedFleetAdmins: approvedFleetAdmins,
                                  superAdmins: superAdmins,
                                ),
                                _UserListTab(
                                  title: 'Passengers',
                                  emptyTitle: 'No passengers found',
                                  emptyMessage:
                                      'Passenger accounts will appear here.',
                                  users: passengers,
                                  icon: Icons.person_outline,
                                  forcedRoleLabel: 'Passenger',
                                ),
                                _DriversTab(
                                  drivers: drivers,
                                  driverUsers: driverUsers,
                                ),
                                _FleetAdminsTab(
                                  approvedFleetAdmins: approvedFleetAdmins,
                                ),
                                _UserListTab(
                                  title: 'Super Admins',
                                  emptyTitle: 'No super admins found',
                                  emptyMessage:
                                      'Super Admin accounts from superAdmins will appear here.',
                                  users: superAdmins,
                                  icon: Icons.admin_panel_settings_outlined,
                                  forcedRoleLabel: 'Super Admin',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AllUsersTab extends StatelessWidget {
  const _AllUsersTab({
    required this.passengers,
    required this.drivers,
    required this.driverUsers,
    required this.approvedFleetAdmins,
    required this.superAdmins,
  });

  final List<UserModel> passengers;
  final List<DriverModel> drivers;
  final List<UserModel> driverUsers;
  final List<FleetApplicationModel> approvedFleetAdmins;
  final List<UserModel> superAdmins;

  @override
  Widget build(BuildContext context) {
    final bool empty = passengers.isEmpty &&
        drivers.isEmpty &&
        driverUsers.isEmpty &&
        approvedFleetAdmins.isEmpty &&
        superAdmins.isEmpty;

    if (empty) {
      return const EmptyState(
        icon: Icons.people_alt_outlined,
        title: 'No users found',
        message:
            'Passengers, drivers, approved fleet admins, and super admins will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _CategoryHeader(
          title: 'Passengers',
          count: passengers.length,
          icon: Icons.person_outline,
        ),
        for (final UserModel user in passengers)
          _UserCard(
            user: user,
            forcedRoleLabel: 'Passenger',
          ),
        const SizedBox(height: 16),
        _CategoryHeader(
          title: 'Drivers',
          count: drivers.length + driverUsers.length,
          icon: Icons.drive_eta_outlined,
        ),
        for (final UserModel driverUser in driverUsers)
          _UserCard(
            user: driverUser,
            forcedRoleLabel: 'Driver',
          ),
        for (final DriverModel driver in drivers) _DriverCard(driver: driver),
        const SizedBox(height: 16),
        _CategoryHeader(
          title: 'Approved Fleet Admins',
          count: approvedFleetAdmins.length,
          icon: Icons.business_center_outlined,
        ),
        for (final FleetApplicationModel application in approvedFleetAdmins)
          _FleetAdminApplicationCard(application: application),
        const SizedBox(height: 16),
        _CategoryHeader(
          title: 'Super Admins',
          count: superAdmins.length,
          icon: Icons.admin_panel_settings_outlined,
        ),
        for (final UserModel user in superAdmins)
          _UserCard(
            user: user,
            forcedRoleLabel: 'Super Admin',
          ),
      ],
    );
  }
}

class _UserListTab extends StatelessWidget {
  const _UserListTab({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.users,
    required this.icon,
    required this.forcedRoleLabel,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final List<UserModel> users;
  final IconData icon;
  final String forcedRoleLabel;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return EmptyState(
        icon: icon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _CategoryHeader(
          title: title,
          count: users.length,
          icon: icon,
        ),
        const SizedBox(height: 8),
        for (final UserModel user in users)
          _UserCard(
            user: user,
            forcedRoleLabel: forcedRoleLabel,
          ),
      ],
    );
  }
}

class _DriversTab extends StatelessWidget {
  const _DriversTab({
    required this.drivers,
    required this.driverUsers,
  });

  final List<DriverModel> drivers;
  final List<UserModel> driverUsers;

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty && driverUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.drive_eta_outlined,
        title: 'No drivers found',
        message: 'Driver accounts created by fleet admins will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _CategoryHeader(
          title: 'Drivers',
          count: drivers.length + driverUsers.length,
          icon: Icons.drive_eta_outlined,
        ),
        const SizedBox(height: 8),
        for (final UserModel user in driverUsers)
          _UserCard(
            user: user,
            forcedRoleLabel: 'Driver',
          ),
        for (final DriverModel driver in drivers) _DriverCard(driver: driver),
      ],
    );
  }
}

class _FleetAdminsTab extends StatelessWidget {
  const _FleetAdminsTab({
    required this.approvedFleetAdmins,
  });

  final List<FleetApplicationModel> approvedFleetAdmins;

  @override
  Widget build(BuildContext context) {
    if (approvedFleetAdmins.isEmpty) {
      return const EmptyState(
        icon: Icons.business_center_outlined,
        title: 'No approved fleet admins found',
        message:
            'Only approved fleet admin applications appear here. Rejected fleets stay under Rejected Fleets.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _CategoryHeader(
          title: 'Approved Fleet Admins',
          count: approvedFleetAdmins.length,
          icon: Icons.business_center_outlined,
        ),
        const SizedBox(height: 8),
        for (final FleetApplicationModel application in approvedFleetAdmins)
          _FleetAdminApplicationCard(application: application),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text('$count'),
            backgroundColor: AppColors.primary.withOpacity(0.10),
            side: BorderSide.none,
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.forcedRoleLabel,
  });

  final UserModel user;
  final String forcedRoleLabel;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child: const Icon(
              Icons.person_outline,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Email: ${user.email.isEmpty ? 'Not provided' : user.email}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  'Phone: ${user.phone.isEmpty ? 'Not provided' : user.phone}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (user.fleetApprovalStatus.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Fleet approval: ${user.fleetApprovalStatus}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        forcedRoleLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.10),
                      side: BorderSide.none,
                    ),
                    StatusChip(status: user.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
  });

  final DriverModel driver;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child: const Icon(
              Icons.drive_eta_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Email: ${driver.email.isEmpty ? 'Not provided' : driver.email}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  'Phone: ${driver.phone.isEmpty ? 'Not provided' : driver.phone}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  'Fleet ID: ${driver.fleetId.isEmpty ? 'Not assigned' : driver.fleetId}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: const Text(
                        'Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.10),
                      side: BorderSide.none,
                    ),
                    StatusChip(status: driver.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetAdminApplicationCard extends StatelessWidget {
  const _FleetAdminApplicationCard({
    required this.application,
  });

  final FleetApplicationModel application;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child: const Icon(
              Icons.business_center_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.ownerName.isEmpty
                      ? application.fleetName
                      : application.ownerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fleet: ${application.fleetName}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  'Email: ${application.email.isEmpty ? 'Not provided' : application.email}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  'Phone: ${application.phone.isEmpty ? 'Not provided' : application.phone}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: const Text(
                        'Fleet Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.10),
                      side: BorderSide.none,
                    ),
                    StatusChip(status: application.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _clean(String value) {
  return value.toLowerCase().trim();
}
