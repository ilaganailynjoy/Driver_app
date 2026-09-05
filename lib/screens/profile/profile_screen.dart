import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vehicle_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import 'change_password_screen.dart';

/// Rider profile: account info, stats, edit + logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final riderProvider = context.watch<RiderProvider>();
    final auth = context.watch<AuthProvider>();
    final rider = riderProvider.rider ?? auth.rider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: rider == null
                ? null
                : () => _openEdit(context, rider),
          ),
        ],
      ),
      body: riderProvider.loading && rider == null
          ? const LoadingWidget(label: 'Loading profile...')
          : riderProvider.error != null && rider == null
              ? ErrorView(
                  message: riderProvider.error!,
                  onRetry: riderProvider.loadProfile,
                )
              : _buildContent(context, riderProvider, auth, rider),
    );
  }

  Widget _buildContent(BuildContext context, RiderProvider riderProvider,
      AuthProvider auth, dynamic rider) {
    if (rider == null) return const LoadingWidget();

    final name = rider.name as String;
    final email = rider.email as String;
    final phone = rider.phone as String;
    final vehicleType = rider.vehicleType as String?;
    final licensePlate = rider.licensePlate as String?;
    final isOnline = rider.isOnline as bool;
    final initials = name.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOnline ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: isOnline
                          ? AppTheme.success
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Available for deliveries' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isOnline
                            ? AppTheme.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone,
              ),
              const Divider(height: 1, indent: 56),
              _InfoRow(
                icon: vehicleIconFor(vehicleType),
                label: 'Vehicle',
                value: vehicleType ?? '—',
              ),
              const Divider(height: 1, indent: 56),
              _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Plate No.',
                value: licensePlate ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Account & Security',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen(),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 20, color: AppColors.textSecondary),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update your login password',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Delivery Stats',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total',
                value: '${rider.totalDeliveries ?? 0}',
                color: const Color(0xFF1D6FE0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Completed',
                value: '${rider.completedDeliveries ?? 0}',
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Failed',
                value: '${rider.failedDeliveries ?? 0}',
                color: AppTheme.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: riderProvider.statusBusy
              ? null
              : () => riderProvider.toggleOnline(),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                isOnline ? AppTheme.danger : AppTheme.success,
            side: BorderSide(
              color: isOnline ? AppTheme.danger : AppTheme.success,
              width: 1.5,
            ),
          ),
          icon: riderProvider.statusBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(isOnline
                  ? Icons.power_settings_new
                  : Icons.play_circle_outline),
          label: Text(isOnline ? 'Go Offline' : 'Go Online'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            isOnline
                ? 'You are available for new assignments. Going offline stops new deliveries from being assigned to you.'
                : 'Offline means you will not receive new assignments, but you can still complete your current deliveries.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => _confirmLogout(context, auth),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.danger,
            elevation: 0,
            side: BorderSide.none,
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openEdit(BuildContext context, dynamic rider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialPhone: rider.phone as String,
          initialVehicle: rider.vehicleType as String?,
          initialPlate: rider.licensePlate as String?,
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of Invoize Rider?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              auth.logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline form to edit rider contact / vehicle details.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.initialPhone = '',
    this.initialVehicle,
    this.initialPlate,
  });

  final String initialPhone;
  final String? initialVehicle;
  final String? initialPlate;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _plateController;
  String? _vehicle;

  static const _vehicles = [
    'Motorcycle',
    'Bicycle',
    'Van',
    'Car',
    'Tricycle',
  ];

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _plateController = TextEditingController(text: widget.initialPlate ?? '');
    _vehicle = widget.initialVehicle;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<RiderProvider>();
    final ok = await provider.updateProfile(
      phone: _phoneController.text.trim(),
      vehicleType: _vehicle,
      licensePlate: _plateController.text.trim().isEmpty
          ? null
          : _plateController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Unable to update profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _vehicle,
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              prefixIcon: Icon(vehicleIconFor(_vehicle)),
            ),
            items: _vehicles
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => _vehicle = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plateController,
            decoration: const InputDecoration(
              labelText: 'License Plate',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ElevatedButton.icon(
            onPressed: provider.statusBusy ? null : _save,
            icon: provider.statusBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(provider.statusBusy ? 'Saving...' : 'Save Changes'),
          ),
        ),
      ),
    );
  }
}