import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../services/application_service.dart';
import '../../services/vehicle_service.dart';
import 'application_status_screen.dart';

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key});
  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _licensePlate = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _vehicleReg = TextEditingController();
  DateTime? _dob;
  String? _vehicleType;
  List<VehicleType> _vehicles = [];
  bool _loadingVehicles = true;
  bool _busy = false;
  final Map<String, ({Uint8List bytes, String filename})> _docs = {};
  final Map<String, String> _docNames = {};

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final api = ApiClient();
      final svc = VehicleService(api);
      final list = await svc.getActive();
      if (mounted) {
        final fallback = list.isEmpty ? _fallbackVehicles : list;
        setState(() { _vehicles = fallback; _loadingVehicles = false; _vehicleType = fallback.first.name; });
      }
    } catch (_) {
      if (mounted) setState(() { _vehicles = _fallbackVehicles; _loadingVehicles = false; _vehicleType = _fallbackVehicles.first.name; });
    }
  }

  List<VehicleType> get _fallbackVehicles => const [
        VehicleType(name: 'motorcycle', label: 'Motorcycle', capacityKg: 30),
        VehicleType(name: 'car', label: 'Car/Sedan', capacityKg: 100),
        VehicleType(name: 'van', label: 'Van', capacityKg: 300),
        VehicleType(name: 'truck', label: 'Truck', capacityKg: 500),
      ];

  int get _age {
    if (_dob == null) return 0;
    final now = DateTime.now();
    int a = now.year - _dob!.year;
    if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) a--;
    return a;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: DateTime(now.year - 20), firstDate: DateTime(1950), lastDate: now, helpText: 'Select Date of Birth');
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickDoc(String type) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _docs[type] = (bytes: bytes, filename: file.name);
      _docNames[type] = file.name;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Date of Birth.'))); return; }
    if (_age < 18) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be at least 18 years old to apply as a rider.'))); return; }
    if (!_docs.containsKey('valid_id') || !_docs.containsKey('drivers_license') || !_docs.containsKey('vehicle_registration')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload Valid ID, Driver\'s License and Vehicle Registration.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ApiClient();
      final svc = ApplicationService(api);
      await svc.submit(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        vehicleType: _vehicleType ?? '',
        licensePlate: _licensePlate.text.trim(),
        licenseNumber: _licenseNumber.text.trim(),
        vehicleRegistration: _vehicleReg.text.trim(),
        documents: _docs,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully.')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ApplicationStatusScreen(email: _email.text.trim())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose(); _address.dispose();
    _licensePlate.dispose(); _licenseNumber.dispose(); _vehicleReg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply as Rider')),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Become a Rider', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1B1F24))),
              const SizedBox(height: 8),
              const Text('Fill in your personal, license and vehicle details.', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              _field(_name, 'Full Name', Icons.person_outline, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress, validator: (v) => !v!.contains('@') ? 'Invalid email' : null),
              _field(_phone, 'Phone (+639 or 09)', Icons.phone_outlined, keyboard: TextInputType.phone, validator: (v) => v!.trim().length < 10 ? 'Required' : null),
              _dobField(),
              _field(_address, 'Address', Icons.home_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              const Text('Vehicle Information', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _vehicleDropdown(),
              _field(_licensePlate, 'License Plate', Icons.confirmation_number_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              _field(_licenseNumber, 'License Number', Icons.badge_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              _field(_vehicleReg, 'Vehicle Registration', Icons.directions_car_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              const Text('Supporting Documents', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _docPicker('valid_id', 'Valid ID *', true),
              _docPicker('drivers_license', 'Driver\'s License *', true),
              _docPicker('vehicle_registration', 'Vehicle Registration *', true),
              _docPicker('proof_of_address', 'Proof of Address', false),
              _docPicker('other', 'Other Document', false),
              const SizedBox(height: 24),
              SizedBox(height: 54, child: ElevatedButton(onPressed: _busy ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Submit Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplicationStatusScreen())), child: const Text('Check Application Status')),
            ]),
          ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(controller: c, keyboardType: keyboard, validator: validator, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    );
  }

  Widget _dobField() {
    final text = _dob == null ? 'Select date' : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}  (Age: $_age)';
    final hasError = _dob == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _pickDob,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of Birth *',
            prefixIcon: const Icon(Icons.cake_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: hasError && _dob == null ? null : null,
          ),
          child: Text(text, style: TextStyle(color: _dob == null ? const Color(0xFF9AA3AF) : const Color(0xFF1B1F24))),
        ),
      ),
    );
  }

  Widget _vehicleDropdown() {
    if (_loadingVehicles) return const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator());
    final selected = _vehicles.where((v) => v.name == _vehicleType).firstOrNull;
    final label = selected == null ? 'Select vehicle' : '${selected.label} (${selected.capacityKg.toStringAsFixed(0)}kg)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final picked = await showDialog<String>(
            context: context,
            builder: (_) => SimpleDialog(
              title: const Text('Select Vehicle Type'),
              children: _vehicles.map((v) => RadioListTile<String>(value: v.name, groupValue: _vehicleType, title: Text('${v.label} (${v.capacityKg.toStringAsFixed(0)}kg)'), onChanged: (val) => Navigator.of(context).pop(val))).toList(),
            ),
          );
          if (picked != null) setState(() => _vehicleType = picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: 'Vehicle Type *', prefixIcon: const Icon(Icons.two_wheeler_outlined, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(label, overflow: TextOverflow.ellipsis)), const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280))]),
        ),
      ),
    );
  }

  Widget _docPicker(String type, String label, bool required) {
    final picked = _docNames[type];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              picked == null ? label : '$label ✓ ${picked.length > 18 ? "${picked.substring(0, 18)}..." : picked}',
              style: TextStyle(fontSize: 13, color: picked != null ? AppTheme.primary : const Color(0xFF6B7280)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            height: 36,
            child: OutlinedButton(
              onPressed: () => _pickDoc(type),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(picked == null ? 'Upload' : 'Change', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
