import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/session/app_session.dart';

class FleetOwnerPendingApprovalPage extends StatelessWidget {
  const FleetOwnerPendingApprovalPage({super.key, required this.initialStatus});

  final String initialStatus;

  @override
  Widget build(BuildContext context) {
    final String? fleetId = context.watch<AppSession>().activeFleetId;
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: SoltechColors.canvas,
      appBar: AppBar(
        title: const Text('Fleet Control Approval'),
        actions: [
          TextButton(
            onPressed: () => context.read<AppSession>().signOut(),
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: fleetId == null || fleetId.isEmpty
              ? null
              : FirebaseDatabase.instance.ref('fleets/$fleetId').onValue,
          builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
            final Map<Object?, Object?> data = snapshot.data?.snapshot.value is Map
                ? Map<Object?, Object?>.from(snapshot.data!.snapshot.value as Map)
                : <Object?, Object?>{};
            final String status = (data['status'] ?? initialStatus).toString();
            final String fleetName = (data['name'] ?? 'Fleet Control').toString();
            final String reason = (data['rejectionReason'] ?? '').toString();

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _statusCard(status, fleetName, reason),
                const SizedBox(height: 18),
                _documentsCard(data),
                const SizedBox(height: 18),
                _stepsCard(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.read<AppSession>().validateSelectedRole(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Approval Status'),
                ),
                if (status == 'rejected' && fleetId != null && uid.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final int now = DateTime.now().millisecondsSinceEpoch;
                      await FirebaseDatabase.instance.ref('fleets/$fleetId').update(<String, dynamic>{
                        'status': 'pending',
                        'rejectionReason': '',
                        'updatedAt': now,
                      });
                      await FirebaseDatabase.instance.ref('fleetOwners/$uid/$fleetId').update(<String, dynamic>{
                        'status': 'pending',
                        'updatedAt': now,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Application resubmitted for review.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Resubmit Application'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusCard(String status, String fleetName, String reason) {
    final bool rejected = status == 'rejected';
    final bool approved = status == 'active';
    final Color color = approved ? SoltechColors.green : rejected ? SoltechColors.red : SoltechColors.amber;
    final IconData icon = approved ? Icons.verified : rejected ? Icons.cancel_outlined : Icons.hourglass_top;
    final String title = approved ? 'Approved' : rejected ? 'Application Rejected' : 'Pending Super Admin Review';
    final String body = approved
        ? 'Your fleet has been approved. You can now manage vehicles and create driver accounts.'
        : rejected
            ? (reason.isEmpty ? 'Please correct your application and resubmit for review.' : reason)
            : 'Your Fleet Control account has been created, but it must be approved by the Super Admin before you can add vehicles or drivers.';

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fleetName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(body, style: const TextStyle(color: SoltechColors.muted, height: 1.35)),
        ],
      ),
    );
  }

  Widget _documentsCard(Map<Object?, Object?> data) {
    final Map<Object?, Object?> documents = data['documents'] is Map
        ? Map<Object?, Object?>.from(data['documents'] as Map)
        : <Object?, Object?>{};
    final List<String> requiredDocs = <String>[
      'Owner ID',
      'Business Registration',
      'Vehicle Registration',
      'Bank Details',
    ];

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Submitted Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...requiredDocs.map((String doc) {
            final String key = doc.toLowerCase().replaceAll(' ', '_');
            final bool submitted = documents.containsKey(key) || documents.isEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(submitted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: submitted ? SoltechColors.green : SoltechColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(doc, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(submitted ? 'Submitted' : 'Missing', style: const TextStyle(color: SoltechColors.muted)),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          const Text(
            'Note: Document upload can later be connected to Firebase Storage. This screen already supports the approval workflow.',
            style: TextStyle(color: SoltechColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _stepsCard() {
    return _panel(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approval Process', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          _StepRow(number: '1', text: 'Fleet owner registers and submits required details.'),
          _StepRow(number: '2', text: 'Super Admin reviews fleet and document information.'),
          _StepRow(number: '3', text: 'If approved, Fleet Control dashboard is activated.'),
          _StepRow(number: '4', text: 'Approved Fleet Owner creates driver accounts and assigns vehicles.'),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoltechColors.line),
      ),
      child: child,
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, backgroundColor: SoltechColors.ink, child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
        ],
      ),
    );
  }
}
