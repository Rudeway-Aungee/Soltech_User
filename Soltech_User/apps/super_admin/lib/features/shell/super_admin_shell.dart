import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/widgets/side_menu.dart';
import '../complaints/complaints_disputes_page.dart';
import '../dashboard/dashboard_overview_page.dart';
import '../fleet_applications/approved_fleets_page.dart';
import '../fleet_applications/pending_fleet_applications_page.dart';
import '../fleet_applications/rejected_fleets_page.dart';
import '../reports/reports_ledger_page.dart';
import '../settings/settings_page.dart';
import '../trips/trips_monitoring_page.dart';
import '../users/users_management_page.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({
    super.key,
    required this.currentUser,
  });

  final User currentUser;

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int selectedIndex = 0;

  final List<SideMenuItem> menuItems = const [
    SideMenuItem(title: 'Dashboard Overview', icon: Icons.dashboard_outlined),
    SideMenuItem(title: 'Pending Fleet Applications', icon: Icons.pending_actions),
    SideMenuItem(title: 'Approved Fleets', icon: Icons.verified_outlined),
    SideMenuItem(title: 'Rejected Fleets', icon: Icons.cancel_outlined),
    SideMenuItem(title: 'Users Management', icon: Icons.people_alt_outlined),
    SideMenuItem(title: 'Trips Monitoring', icon: Icons.route_outlined),
    SideMenuItem(title: 'Reports / Ledger', icon: Icons.receipt_long_outlined),
    SideMenuItem(title: 'Complaints / Disputes', icon: Icons.report_problem_outlined),
    SideMenuItem(title: 'Settings', icon: Icons.settings_outlined),
  ];

  Widget get currentPage {
    switch (selectedIndex) {
      case 0:
        return const DashboardOverviewPage();
      case 1:
        return PendingFleetApplicationsPage(adminUid: widget.currentUser.uid);
      case 2:
        return const ApprovedFleetsPage();
      case 3:
        return const RejectedFleetsPage();
      case 4:
        return const UsersManagementPage();
      case 5:
        return const TripsMonitoringPage();
      case 6:
        return const ReportsLedgerPage();
      case 7:
        return const ComplaintsDisputesPage();
      case 8:
        return const SettingsPage();
      default:
        return const DashboardOverviewPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wideScreen = MediaQuery.of(context).size.width >= 900;
    final title = menuItems[selectedIndex].title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Center(child: Text(widget.currentUser.email ?? 'Super Admin')),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => AuthService().logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: wideScreen
          ? null
          : Drawer(
              child: SafeArea(
                child: SideMenu(
                  items: menuItems,
                  selectedIndex: selectedIndex,
                  onSelected: (index) {
                    setState(() => selectedIndex = index);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
      body: Row(
        children: [
          if (wideScreen)
            SizedBox(
              width: 290,
              child: SideMenu(
                items: menuItems,
                selectedIndex: selectedIndex,
                onSelected: (index) {
                  setState(() => selectedIndex = index);
                },
              ),
            ),
          Expanded(child: currentPage),
        ],
      ),
    );
  }
}