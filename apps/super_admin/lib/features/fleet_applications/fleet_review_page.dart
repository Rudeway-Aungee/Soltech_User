import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/admin_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/fleet_application_model.dart';
import '../../data/repositories/fleet_repository.dart';

class FleetReviewPage extends StatelessWidget {
  const FleetReviewPage({
    super.key,
    required this.application,
    required this.adminUid,
  });

  final FleetApplicationModel application;
  final String adminUid;

  Future<void> approve(BuildContext context) async {
    await FleetRepository().approveFleet(
      application: application,
      adminUid: adminUid,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${application.fleetName} approved.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> reject(BuildContext context) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Application'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Example: Incomplete business documents',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final reason = controller.text.trim().isEmpty
        ? 'Rejected by Super Admin.'
        : controller.text.trim();

    await FleetRepository().rejectFleet(
      application: application,
      adminUid: adminUid,
      reason: reason,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${application.fleetName} rejected.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Review: ${application.fleetName}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.fleetName,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                StatusChip(status: application.status),
                const SizedBox(height: 24),
                _ReviewRow(label: 'Fleet ID', value: application.fleetId),
                _ReviewRow(label: 'Owner ID', value: application.ownerId),
                _ReviewRow(label: 'Owner Name', value: application.ownerName),
                _ReviewRow(label: 'Email', value: application.email),
                _ReviewRow(label: 'Phone', value: application.phone),
                _ReviewRow(
                  label: 'Submitted At',
                  value: DateFormatter.fromMilliseconds(application.submittedAt),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Documents to check',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Business Registration')),
                    Chip(label: Text('Owner ID')),
                    Chip(label: Text('Vehicle Documents')),
                    Chip(label: Text('Insurance')),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => reject(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject Application'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => approve(context),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve Fleet'),
                      ),
                    ),
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

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}