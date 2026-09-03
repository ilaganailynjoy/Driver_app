import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../services/application_service.dart';

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key, this.email});
  final String? email;
  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  final _email = TextEditingController();
  RiderApplicationStatus? _app;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _email.text = widget.email!;
      _check();
    }
  }

  Future<void> _check() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email to check status.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final api = ApiClient();
      final svc = ApplicationService(api);
      final app = await svc.getStatus(_email.text.trim());
      if (!mounted) return;
      setState(() { _app = app; if (app == null) _error = 'No application found.'; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Widget _badge(String status) {
    final map = {'pending': Colors.orange, 'approved': Colors.green, 'rejected': Colors.red};
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (map[status] ?? Colors.grey).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: map[status] ?? Colors.grey)), child: Text(status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: map[status])) );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Status')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: _email, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            SizedBox(height: 48, child: ElevatedButton(onPressed: _busy ? null : _check, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Check Status', style: TextStyle(color: Colors.white)))),
            const SizedBox(height: 24),
            if (_error != null) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            if (_app != null) ...[
              const SizedBox(height: 16),
              Center(child: _badge(_app!.status)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'Reference: ${_app!.referenceNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _card() {
    final a = _app!;
    String title = 'Application Under Review';
    String desc = 'Your rider application is currently being reviewed by Logistics.';
    IconData icon = Icons.hourglass_top_outlined;
    Color color = Colors.orange;
    if (a.status == 'approved') { title = 'Congratulations!'; desc = 'Your rider application has been approved. You can now log in as a rider.'; icon = Icons.check_circle_outline; color = Colors.green; }
    if (a.status == 'rejected') { title = 'Application Not Approved'; desc = a.notes ?? 'Your application was not approved.'; icon = Icons.cancel_outlined; color = Colors.red; }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6E9EF)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
      child: Column(children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        if (a.riderType != null || a.vehicleOwnership != null)
          Text(
            '${a.riderType != null ? a.riderType!.replaceAll('_', ' ').toUpperCase() : ''}${a.riderType != null && a.vehicleOwnership != null ? ' · ' : ''}${a.vehicleOwnership != null ? a.vehicleOwnership!.replaceAll('_', ' ').toUpperCase() : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
        const SizedBox(height: 12),
        Text('Applied: ${a.createdAt ?? "-"}', style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3AF))),
        if (a.reviewedAt != null) Text('Reviewed: ${a.reviewedAt}', style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3AF))),
      ]),
    );
  }
}
