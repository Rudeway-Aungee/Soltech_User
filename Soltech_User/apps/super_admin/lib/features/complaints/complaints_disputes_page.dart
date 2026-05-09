import 'package:flutter/material.dart';

import '../../core/widgets/admin_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/complaint_repository.dart';

class ComplaintsDisputesPage extends StatelessWidget {
  const ComplaintsDisputesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ComplaintRepository();

    return StreamBuilder(
      stream: repository.complaintsStream(),
      builder: (context, snapshot) {
        final complaints = snapshot.data ?? [];

        if (complaints.isEmpty) {
          return const EmptyState(
            icon: Icons.report_problem_outlined,
            title: 'No complaints or disputes',
            message: 'Passenger, driver, and fleet complaints will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Complaints / Disputes',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            for (final complaint in complaints)
              AdminCard(
                child: ListTile(
                  leading: const Icon(Icons.report_problem_outlined),
                  title: Text(
                    complaint.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(complaint.message),
                  trailing: complaint.status == 'resolved'
                      ? const StatusChip(status: 'resolved')
                      : ElevatedButton(
                          onPressed: () => repository.markResolved(complaint.id),
                          child: const Text('Resolve'),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}