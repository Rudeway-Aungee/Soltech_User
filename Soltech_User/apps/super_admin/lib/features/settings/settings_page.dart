import 'package:flutter/material.dart';

import '../../core/widgets/admin_card.dart';
import '../../data/models/platform_settings_model.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsRepository repository = SettingsRepository();

  final TextEditingController commissionController = TextEditingController();
  final TextEditingController baseFareController = TextEditingController();
  final TextEditingController minimumFareController = TextEditingController();
  final TextEditingController supportPhoneController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    commissionController.dispose();
    baseFareController.dispose();
    minimumFareController.dispose();
    supportPhoneController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    final settings = await repository.getSettings();

    commissionController.text = settings.commissionPercent.toString();
    baseFareController.text = settings.baseFare.toString();
    minimumFareController.text = settings.minimumFare.toString();
    supportPhoneController.text = settings.supportPhone;

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveSettings() async {
    final settings = PlatformSettingsModel(
      commissionPercent: double.tryParse(commissionController.text.trim()) ?? 10,
      baseFare: double.tryParse(baseFareController.text.trim()) ?? 5,
      minimumFare: double.tryParse(minimumFareController.text.trim()) ?? 10,
      supportPhone: supportPhoneController.text.trim(),
    );

    await repository.saveSettings(settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Platform Rules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: commissionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Platform Commission Percent',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: baseFareController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Base Fare',
                  prefixText: 'K ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: minimumFareController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Fare',
                  prefixText: 'K ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: supportPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Support Phone',
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: saveSettings,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}