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
  String _riderType = 'full_time';
  String _vehicleOwnership = 'own';

  List<VehicleType> _vehicles = [];
  bool _loadingVehicles = true;
  bool _busy = false;

  final Map<String, ({Uint8List bytes, String filename})> _docs = {};
  final Map<String, String> _docNames = {};

  static const _ownershipOptions = <String, String>{
    'own': 'Own',
    'borrowed': 'Borrowed',
    'second_hand': 'Second-hand',
    'financing': 'Financing',
  };

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
        setState(() {
          _vehicles = fallback;
          _loadingVehicles = false;
          _vehicleType = fallback.first.name;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vehicles = _fallbackVehicles;
          _loadingVehicles = false;
          _vehicleType = _fallbackVehicles.first.name;
        });
      }
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
    if (now.month < _dob!.month ||
        (now.month == _dob!.month && now.day < _dob!.day)) {
      a--;
    }
    return a;
  }

  bool get _ageOk => _age >= 18;

  /// Required documents owned based on the selected vehicle ownership.
  List<String> get _ownershipRequiredDocs {
    switch (_vehicleOwnership) {
      case 'borrowed':
        return const ['authorization_letter', 'owner_valid_id'];
      case 'second_hand':
        return const ['deed_of_sale', 'sales_invoice'];
      case 'financing':
        return const ['sales_invoice', 'encumbrance_certificate'];
      default:
        return const [];
    }
  }

  /// "At least one of these" requirement for second-hand vehicles.
  List<String> get _atLeastOneDocs {
    if (_vehicleOwnership == 'second_hand') {
      return const ['deed_of_sale', 'sales_invoice'];
    }
    return const [];
  }

  static const _requiredBase = ['valid_id', 'drivers_license', 'vehicle_registration'];

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickDoc(String type) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _docs[type] = (bytes: bytes, filename: file.name);
      _docNames[type] = file.name;
    });
  }

  String? _validateDocs() {
    for (final t in _requiredBase) {
      if (!_docs.containsKey(t)) {
        return 'Please upload Valid ID, Driver\'s License and Vehicle Registration.';
      }
    }
    if (_ownershipRequiredDocs.isNotEmpty) {
      final missing = _ownershipRequiredDocs.where((t) => !_docs.containsKey(t)).toList();
      if (missing.isNotEmpty) {
        final labels = missing.map(_docLabel).join(', ');
        return 'Missing required documents for this vehicle: $labels';
      }
    }
    // "At least one of" group for second-hand.
    for (final group in [_atLeastOneDocs]) {
      if (group.length >= 2 && group.every((t) => !_docs.containsKey(t))) {
        return 'At least one of: ${group.map(_docLabel).join(' or ')} is required.';
      }
    }
    return null;
  }

  String _docLabel(String type) {
    const labels = {
      'valid_id': 'Valid ID',
      'drivers_license': "Driver's License",
      'vehicle_registration': 'Vehicle Registration',
      'proof_of_address': 'Proof of Address',
      'deed_of_sale': 'Deed of Sale',
      'sales_invoice': 'Sales Invoice',
      'owner_valid_id': 'Owner Valid ID',
      'authorization_letter': 'Authorization Letter',
      'encumbrance_certificate': 'Certificate of Encumbrance',
      'other': 'Other Document',
    };
    return labels[type] ?? type;
  }

  Future<void> _goReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      _snack('Please select your Date of Birth.');
      return;
    }
    if (!_ageOk) {
      _snack('You must be at least 18 years old to apply as a rider.');
      return;
    }
    final err = _validateDocs();
    if (err != null) {
      _snack(err);
      return;
    }
    FocusScope.of(context).unfocus();
    final proceed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ReviewScreen(state: this)),
    );
    if (proceed == true && mounted) {
      await _submit();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final api = ApiClient();
      final svc = ApplicationService(api);
      final result = await svc.submit(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        vehicleType: _vehicleType ?? '',
        licensePlate: _licensePlate.text.trim(),
        licenseNumber: _licenseNumber.text.trim(),
        vehicleRegistration: _vehicleReg.text.trim(),
        riderType: _riderType,
        vehicleOwnership: _vehicleOwnership,
        documents: _docs,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _SuccessScreen(result: result, email: _email.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _licensePlate.dispose();
    _licenseNumber.dispose();
    _vehicleReg.dispose();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Become a Rider',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1B1F24)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete the form below. You will review your details before submitting.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Section A · Personal Information'),
                  _field(_name, 'Full Name', Icons.person_outline, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress, validator: (v) => !v!.contains('@') ? 'Invalid email' : null),
                  _field(_phone, 'Phone (+639 or 09)', Icons.phone_outlined, keyboard: TextInputType.phone, validator: (v) => v!.trim().length < 10 ? 'Required' : null),
                  _dobField(),
                  _field(_address, 'Address', Icons.home_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),

                  const SizedBox(height: 16),
                  _sectionHeader('Section B · Rider Type'),
                  const SizedBox(height: 12),
                  _riderTypeSelector(),
                  const SizedBox(height: 12),
                  _infoBox('Full-time riders receive regular daily schedules. Part-time riders set their own availability.'),
                  if (_riderType == 'full_time') ...[
                    const SizedBox(height: 8),
                    _infoBox('Full-time rider benefits include priority daily assignments and steady earning opportunities.'),
                  ],

                  const SizedBox(height: 20),
                  _sectionHeader('Section C · Vehicle Information'),
                  const SizedBox(height: 12),
                  _vehicleDropdown(),
                  _ownershipSelector(),
                  _field(_licensePlate, 'License Plate', Icons.confirmation_number_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  _field(_licenseNumber, 'License Number', Icons.badge_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  _field(_vehicleReg, 'Vehicle Registration', Icons.directions_car_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),

                  const SizedBox(height: 20),
                  _sectionHeader('Section D · Supporting Documents'),
                  const SizedBox(height: 8),
                  _docPicker('valid_id', 'Valid ID *', true),
                  _docPicker('drivers_license', "Driver's License *", true),
                  _docPicker('vehicle_registration', 'Vehicle Registration *', true),
                  if (_vehicleOwnership == 'borrowed') ...[
                    const SizedBox(height: 8),
                    _infoBox('Borrowed vehicle: please provide the owner authorization and the owner\'s valid ID.'),
                    _docPicker('authorization_letter', 'Authorization Letter *', true),
                    _docPicker('owner_valid_id', 'Owner Valid ID *', true),
                  ],
                  if (_vehicleOwnership == 'second_hand') ...[
                    const SizedBox(height: 8),
                    _infoBox('Second-hand vehicle: provide at least one ownership document (Deed of Sale or Sales Invoice).'),
                    _docPicker('deed_of_sale', 'Deed of Sale *', true),
                    _docPicker('sales_invoice', 'Sales Invoice * (or Deed of Sale)', false),
                  ],
                  if (_vehicleOwnership == 'financing') ...[
                    const SizedBox(height: 8),
                    _infoBox('Financed vehicle: please provide the sales invoice and the certificate of encumbrance.'),
                    _docPicker('sales_invoice', 'Sales Invoice *', true),
                    _docPicker('encumbrance_certificate', 'Certificate of Encumbrance *', true),
                  ],
                  _docPicker('proof_of_address', 'Proof of Address', false),
                  _docPicker('other', 'Other Document', false),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _goReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Review Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApplicationStatusScreen()),
                    ),
                    child: const Text('Check Application Status'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1B1F24)));
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        ],
      ),
    );
  }

  Widget _riderTypeSelector() {
    return Row(
      children: [
        _choiceChip('full_time', 'Full-time', Icons.work_outline),
        const SizedBox(width: 12),
        _choiceChip('part_time', 'Part-time', Icons.schedule_outlined),
      ],
    );
  }

  Widget _choiceChip(String value, String label, IconData icon) {
    final selected = _riderType == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _riderType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? AppTheme.primary : Colors.white,
            border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFE6E9EF), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF1B1F24))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownershipSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vehicle Ownership *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1B1F24))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ownershipOptions.entries.map((e) => _ownershipChip(e.key, e.value)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _ownershipChip(String value, String label) {
    final selected = _vehicleOwnership == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() => _vehicleOwnership = value);
        // Clear conditional docs that no longer apply when ownership changes.
        _docs.removeWhere((k, _) => _ownershipRequiredDocs.contains(k) || _atLeastOneDocs.contains(k));
        _docNames.removeWhere((k, _) => _ownershipRequiredDocs.contains(k) || _atLeastOneDocs.contains(k));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? AppTheme.primary : Colors.white,
          border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFE6E9EF), width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? Colors.white : const Color(0xFF1B1F24))),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dobField() {
    final text = _dob == null
        ? 'Select date'
        : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}  (Age: $_age${_ageOk ? '' : ' · must be 18+'})';
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
            errorText: (_dob != null && !_ageOk) ? 'You must be at least 18 years old.' : null,
          ),
          child: Text(text, style: TextStyle(color: _dob == null ? const Color(0xFF9AA3AF) : const Color(0xFF1B1F24))),
        ),
      ),
    );
  }

  Widget _vehicleDropdown() {
    if (_loadingVehicles) {
      return const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator());
    }
    final selected = _vehicles.where((v) => v.name == _vehicleType).firstOrNull;
    final label = selected == null
        ? 'Select vehicle'
        : '${selected.label} (${selected.capacityKg.toStringAsFixed(0)}kg)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final picked = await showDialog<String>(
            context: context,
            builder: (_) => SimpleDialog(
              title: const Text('Select Vehicle Type'),
              children: _vehicles
                  .map((v) => RadioListTile<String>(
                        value: v.name,
                        groupValue: _vehicleType,
                        title: Text('${v.label} (${v.capacityKg.toStringAsFixed(0)}kg)'),
                        onChanged: (val) => Navigator.of(context).pop(val),
                      ))
                  .toList(),
            ),
          );
          if (picked != null) setState(() => _vehicleType = picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Vehicle Type *',
            prefixIcon: const Icon(Icons.two_wheeler_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
            ],
          ),
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
              picked == null
                  ? label
                  : '$label ✓ ${picked.length > 18 ? "${picked.substring(0, 18)}..." : picked}',
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
          if (required && picked == null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: const Icon(Icons.error_outline, size: 16, color: Colors.orange),
            ),
        ],
      ),
    );
  }
}

/// Full-page review of the entered application before final submission.
class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen({required this.state});
  final _ApplyScreenState state;

  @override
  Widget build(BuildContext context) {
    final ownershipLabel = _ApplyScreenState._ownershipOptions[state._vehicleOwnership] ?? state._vehicleOwnership;
    final docsLabels =
        state._docNames.entries.map((e) => '• ${state._docLabel(e.key)}: ${e.value}').join('\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Review Application')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E9EF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _row('Name', state._name.text.trim()),
                    _row('Email', state._email.text.trim()),
                    _row('Phone', state._phone.text.trim()),
                    if (state._dob != null) _row('Date of Birth', '${state._dob!.year}-${state._dob!.month.toString().padLeft(2, '0')}-${state._dob!.day.toString().padLeft(2, '0')}'),
                    _row('Address', state._address.text.trim()),
                    const Divider(height: 24),
                    const Text('Rider Type', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _row('Type', state._riderType.replaceAll('_', ' ').toUpperCase()),
                    const Divider(height: 24),
                    const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _row('Vehicle type', state._vehicleType ?? '-'),
                    _row('Ownership', ownershipLabel),
                    _row('License plate', state._licensePlate.text.trim()),
                    _row('License number', state._licenseNumber.text.trim()),
                    _row('Vehicle registration', state._vehicleReg.text.trim()),
                    const Divider(height: 24),
                    const Text('Documents', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(docsLabels.isEmpty ? 'None' : docsLabels, style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Color(0xFFE6E9EF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Submit Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B1F24)))),
        ],
      ),
    );
  }
}

/// Full-screen success page shown after a successful submission, with the
/// application reference number.
class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({required this.result, required this.email});
  final RiderApplicationSubmitResult result;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Submitted')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Application Submitted!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6E9EF)),
                ),
                child: Column(
                  children: [
                    const Text('Application Reference Number', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Text(result.referenceNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary, letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Keep this reference number to track your application status.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ApplicationStatusScreen(email: email)),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Check Application Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
