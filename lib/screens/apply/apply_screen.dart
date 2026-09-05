import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vehicle_icons.dart';
import '../../services/application_service.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/primary_button.dart';
import 'application_status_screen.dart';
import 'apply_widgets.dart';

/// Guided multi-step "Apply as a Rider" flow.
///
/// Steps: Personal → Rider Type → Vehicle → Requirements → Documents → Review.
/// Uses the existing `POST /api/rider/apply` contract (single `name` field,
/// backend document keys) — no backend changes. First/last name are combined
/// into `name`; sex and date of birth are validated client-side (the
/// application record has no columns for them) and are not submitted.
/// A single file chosen through the native picker, surfaced as plain data
/// so the upload flow never touches `dart:io` (web-safe).
class PickedDoc {
  const PickedDoc({required this.name, required this.readBytes});
  final String name;
  final Future<Uint8List> Function() readBytes;
}

/// Thin indirection around the native file picker.
///
/// `file_picker` resolves to native code at build time, so widget tests
/// (and any build missing the plugin registration) cannot drive the real
/// picker. Tests inject a fake; production uses the default.
class DocFilePicker {
  const DocFilePicker();

  Future<PickedDoc?> pickSingle(List<String> allowedExtensions) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (file == null) return null;
    return PickedDoc(name: file.name, readBytes: file.readAsBytes);
  }
}

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key, this.picker = const DocFilePicker()});

  /// File extensions applicants may attach. A subset of the mimes the
  /// existing `POST /api/rider/apply` endpoint accepts
  /// (jpg, jpeg, png, webp, pdf, doc, docx), covering the formats
  /// applicants actually need. The picker filter below must stay in sync
  /// with this list.
  static const supportedDocExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  /// Maximum staged file size per document. Mirrors the backend
  /// `max:5120` (5 MB) upload rule so oversized files are rejected
  /// instantly instead of failing the whole submission.
  static const maxDocBytes = 5 * 1024 * 1024;

  /// Picker boundary (fakeable in tests).
  final DocFilePicker picker;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

/// A document slot the backend actually accepts (`documents.<key>`).
class _DocSlot {
  const _DocSlot(this.key, this.title, this.subtitle, this.icon);
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ApplyScreenState extends State<ApplyScreen> {
  int _step = 0;

  // Step 1 — personal.
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String? _sex; // client-side only (no backend column).
  DateTime? _dob; // client-side only (no backend column).

  // Step 2 — rider type (backend values).
  String _riderType = 'full_time';

  // Step 3 — vehicle (backend values).
  List<VehicleType> _vehicles = [];
  bool _loadingVehicles = true;
  String? _vehicleType;
  String _ownership = 'own';
  final _plate = TextEditingController();
  final _licenseNo = TextEditingController();
  final _vehicleReg = TextEditingController();

  // Steps 4–5 — staged document files (uploaded on submit).
  final Map<String, ({Uint8List bytes, String filename})> _docs = {};

  // Step 6 — review.
  bool _confirm = false;
  bool _submitting = false;

  static const _ownershipOptions = <String, String>{
    'own': 'Own',
    'borrowed': 'Borrowed',
    'second_hand': 'Second-hand',
    'financing': 'Installment',
  };

  static const _baseDocs = [
    _DocSlot('drivers_license', "Driver's License",
        'Front and back, clear and readable', Icons.badge_outlined),
    _DocSlot('vehicle_registration', 'OR/CR',
        'Official Receipt / Certificate of Registration',
        Icons.directions_car_outlined),
    _DocSlot('valid_id', 'Valid ID',
        'Government-issued ID with photo', Icons.credit_card_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final list = await VehicleService(ApiClient()).getActive();
      if (!mounted) return;
      final usable = list.isEmpty ? _fallbackVehicles : list;
      setState(() {
        _vehicles = usable;
        _vehicleType = usable.first.name;
        _loadingVehicles = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vehicles = _fallbackVehicles;
        _vehicleType = _fallbackVehicles.first.name;
        _loadingVehicles = false;
      });
    }
  }

  List<VehicleType> get _fallbackVehicles => const [
        VehicleType(name: 'motorcycle', label: 'Motorcycle', capacityKg: 30),
        VehicleType(name: 'car', label: 'Car / Sedan', capacityKg: 100),
        VehicleType(name: 'van', label: 'Van', capacityKg: 300),
        VehicleType(name: 'truck', label: 'Truck', capacityKg: 500),
      ];

  int get _age {
    if (_dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month ||
        (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }
    return age;
  }

  bool get _isFullTime => _riderType == 'full_time';

  /// Documents required for the current rider type + ownership, using only
  /// keys the backend accepts (`documents.<key>`).
  List<_DocSlot> get _requiredDocs {
    final docs = [..._baseDocs];
    docs.add(
      _isFullTime
          ? const _DocSlot('other', 'Police or Barangay Clearance',
              'Valid clearance issued within the last 6 months',
              Icons.verified_outlined)
          : const _DocSlot('other', 'Barangay Clearance',
              'Valid clearance from your barangay', Icons.verified_outlined),
    );
    switch (_ownership) {
      case 'borrowed':
        docs.add(const _DocSlot('authorization_letter',
            'Authorization Letter', 'Signed letter from the vehicle owner',
            Icons.edit_note_outlined));
        docs.add(const _DocSlot('owner_valid_id', "Owner's Valid ID",
            'Government-issued ID of the vehicle owner',
            Icons.person_outline));
      case 'second_hand':
        docs.add(const _DocSlot('deed_of_sale', 'Deed of Sale',
            'Notarized proof of vehicle purchase', Icons.receipt_outlined));
      case 'financing':
        docs.add(const _DocSlot('sales_invoice', 'Sales Invoice',
            'Invoice from the dealer or financing company',
            Icons.request_quote_outlined));
        docs.add(const _DocSlot('encumbrance_certificate',
            'Encumbrance Certificate', 'Certification from the financing company',
            Icons.account_balance_outlined));
      case 'own':
        break;
    }
    return docs;
  }

  String get _riderTypeLabel =>
      _isFullTime ? 'Full-time Rider' : 'Part-time Rider';

  String get _ownershipLabel =>
      _ownershipOptions[_ownership] ?? _ownership;

  String get _vehicleLabel {
    for (final v in _vehicles) {
      if (v.name == _vehicleType) {
        return '${v.label} (${v.capacityKg.toStringAsFixed(0)} kg capacity)';
      }
    }
    return _vehicleType ?? '-';
  }

  String get _dobLabel {
    if (_dob == null) return 'Select date';
    final d = _dob!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ── Navigation + per-step validation ────────────────────────────────

  void _next() {
    final error = _validateStep();
    if (error != null) {
      _snack(error);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_step < 5) setState(() => _step++);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step > 0) setState(() => _step--);
  }

  void _jumpTo(int step) => setState(() => _step = step);

  String? _validateStep() {
    switch (_step) {
      case 0:
        return _validatePersonal();
      case 2:
        return _validateVehicle();
      case 4:
        return _validateDocs();
      default:
        return null;
    }
  }

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  String? _validatePersonal() {
    if (_firstName.text.trim().isEmpty) return 'Please enter your first name.';
    if (_lastName.text.trim().isEmpty) return 'Please enter your last name.';
    if (!_emailRegex.hasMatch(_email.text.trim())) {
      return 'Please enter a valid email address.';
    }
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Please enter a valid phone number.';
    if (_sex == null) return 'Please select your sex.';
    if (_dob == null) return 'Please select your date of birth.';
    if (_age < 18) return 'You must be at least 18 years old to apply.';
    if (_address.text.trim().isEmpty) return 'Please enter your address.';
    return null;
  }

  String? _validateVehicle() {
    if (_loadingVehicles || _vehicleType == null) {
      return 'Please wait while vehicle types load.';
    }
    if (_plate.text.trim().isEmpty) return 'Please enter the license plate.';
    if (_licenseNo.text.trim().isEmpty) {
      return 'Please enter the license number.';
    }
    if (_vehicleReg.text.trim().isEmpty) {
      return 'Please enter the vehicle registration.';
    }
    return null;
  }

  String? _validateDocs() {
    final missing =
        _requiredDocs.where((d) => !_docs.containsKey(d.key)).toList();
    if (missing.isNotEmpty) {
      return 'Please upload: ${missing.map((d) => d.title).join(', ')}.';
    }
    return null;
  }

  // ── Document picking (staged locally, uploaded on submit) ───────────

  Future<void> _pickDoc(String key) async {
    PickedDoc? picked;
    try {
      // Single-file picker limited to the supported document formats.
      // The original filename + extension are preserved as-is for the
      // multipart upload on submit.
      picked = await widget.picker
          .pickSingle(ApplyScreen.supportedDocExtensions);
    } catch (e, stack) {
      // Never hide the underlying failure during development.
      debugPrint('Document picker failed to open: $e\n$stack');
      if (!mounted) return;
      _snack(e is MissingPluginException
          ? 'File picking is not available in this app build. Please reinstall the latest version of the app.'
          : 'Unable to open the file picker. Please try again.');
      return;
    }
    // User cancelled the picker — normal behavior, stay silent.
    if (picked == null) return;
    try {
      final bytes = await picked.readBytes();
      if (bytes.length > ApplyScreen.maxDocBytes) {
        if (mounted) {
          _snack(
              'That file is over 5 MB. Please choose a smaller file or take a new photo.');
        }
        return;
      }
      if (!mounted) return;
      setState(() => _docs[key] = (bytes: bytes, filename: picked!.name));
    } catch (e, stack) {
      debugPrint('Document read failed: $e\n$stack');
      if (mounted) _snack('Document upload failed. Please try again.');
    }
  }

  void _removeDoc(String key) => setState(() => _docs.remove(key));

  /// Drop staged ownership docs that no longer apply after a change.
  void _pruneStaleDocs() {
    final keep = _requiredDocs.map((d) => d.key).toSet();
    _docs.removeWhere((key, _) => !keep.contains(key));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  // ── Submission (existing POST /api/rider/apply) ─────────────────────

  Future<void> _submit() async {
    if (_submitting) return; // prevent duplicate submissions
    for (final error in [_validatePersonal(), _validateVehicle(), _validateDocs()]) {
      if (error != null) {
        _snack(error);
        return;
      }
    }
    if (!_confirm) {
      _snack('Please confirm that your information is accurate.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApplicationService(ApiClient()).submit(
        name: '${_firstName.text.trim()} ${_lastName.text.trim()}',
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        vehicleType: _vehicleType ?? '',
        licensePlate: _plate.text.trim(),
        licenseNumber: _licenseNo.text.trim(),
        vehicleRegistration: _vehicleReg.text.trim(),
        riderType: _riderType,
        vehicleOwnership: _ownership,
        documents: _docs,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              _ApplySuccessScreen(result: result, email: _email.text.trim()),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.type) {
        case ApiErrorType.validation:
          _snack(e.message.isNotEmpty
              ? e.message
              : 'Please complete the required fields.');
        case ApiErrorType.network:
        case ApiErrorType.timeout:
          _snack('Unable to connect. Please try again.');
        default:
          _snack(e.message.isNotEmpty
              ? e.message
              : 'Submission failed. Please try again.');
      }
    } catch (_) {
      if (mounted) _snack('Submission failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _plate.dispose();
    _licenseNo.dispose();
    _vehicleReg.dispose();
    super.dispose();
  }

  // ── Shell ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply as Rider')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: ApplyProgressIndicator(step: _step),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildStep(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _buildNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _personalStep(key: const ValueKey(0));
      case 1:
        return _riderTypeStep(key: const ValueKey(1));
      case 2:
        return _vehicleStep(key: const ValueKey(2));
      case 3:
        return _requirementsStep(key: const ValueKey(3));
      case 4:
        return _documentsStep(key: const ValueKey(4));
      default:
        return _reviewStep(key: const ValueKey(5));
    }
  }

  Widget _buildNavBar() {
    if (_step == 5) {
      return ApplyNavBar(
        nextLabel: 'Submit Application',
        onBack: _submitting ? null : _back,
        onNext: _submit,
        nextLoading: _submitting,
      );
    }
    return ApplyNavBar(
      nextLabel: 'Continue',
      onBack: _step == 0 ? null : _back,
      onNext: _next,
    );
  }

  // ── Step 1: Personal ────────────────────────────────────────────────

  Widget _personalStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplyStepHeader(
          title: 'Apply as a Rider',
          subtitle: 'Tell us about yourself',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _field(_firstName, 'First Name *', Icons.person_outline)),
            const SizedBox(width: 12),
            Expanded(child: _field(_lastName, 'Last Name *', null)),
          ],
        ),
        _field(_email, 'Email *', Icons.email_outlined,
            keyboard: TextInputType.emailAddress),
        _field(_phone, 'Phone Number *  (+639 / 09)', Icons.phone_outlined,
            keyboard: TextInputType.phone),
        const Text('Sex *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _sexChip('male', 'Male'),
            const SizedBox(width: 8),
            _sexChip('female', 'Female'),
          ],
        ),
        const SizedBox(height: 16),
        _dobField(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Applicants must be at least 18 years old.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _field(_address, 'Address *', Icons.home_outlined, maxLines: 2),
      ],
    );
  }

  Widget _sexChip(String value, String label) {
    final selected = _sex == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _sex = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.white,
            border: Border.all(
              color:
                  selected ? AppTheme.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppTheme.primary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dobField() {
    final hasError = _dob != null && _age < 18;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _pickDob,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of Birth *',
            prefixIcon: const Icon(Icons.cake_outlined, size: 20),
            errorText:
                hasError ? 'You must be at least 18 years old.' : null,
          ),
          child: Text(
            _dob == null ? 'Select date' : '$_dobLabel  (Age: $_age)',
            style: TextStyle(
              color: _dob == null
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 2: Rider type ──────────────────────────────────────────────

  Widget _riderTypeStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplyStepHeader(
          title: 'Choose your Rider Type',
          subtitle: 'Pick the schedule that fits you best',
        ),
        const SizedBox(height: 20),
        SelectableCard(
          selected: _riderType == 'full_time',
          onTap: () {
            setState(() => _riderType = 'full_time');
            _pruneStaleDocs();
          },
          child: const Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 36, color: AppTheme.primary),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Full-time Rider',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Work regularly as a delivery rider',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SelectableCard(
          selected: _riderType == 'part_time',
          onTap: () {
            setState(() => _riderType = 'part_time');
            _pruneStaleDocs();
          },
          child: const Row(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 36, color: AppTheme.primary),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Part-time Rider',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Deliver during your available time',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            _isFullTime
                ? 'Full-time riders receive regular daily schedules and priority assignments.'
                : 'Part-time riders deliver during their available time with flexible scheduling.',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // ── Step 3: Vehicle ─────────────────────────────────────────────────

  Widget _vehicleStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplyStepHeader(
          title: 'Vehicle Information',
          subtitle: 'Tell us about the vehicle you will use',
        ),
        const SizedBox(height: 20),
        const Text('Vehicle Type *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        if (_loadingVehicles)
          const LinearProgressIndicator()
        else
          ..._vehicles.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableCard(
                  selected: _vehicleType == v.name,
                  onTap: () => setState(() => _vehicleType = v.name),
                  child: Row(
                    children: [
                      Icon(vehicleIconFor(v.name),
                          size: 28, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.label,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Text(
                                '${v.capacityKg.toStringAsFixed(0)} kg capacity',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 12),
        const Text('Vehicle Ownership *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ownershipOptions.entries
              .map((e) => _ownershipChip(e.key, e.value))
              .toList(),
        ),
        const SizedBox(height: 16),
        _field(_plate, 'License Plate *', Icons.confirmation_number_outlined),
        _field(_licenseNo, 'License Number *', Icons.badge_outlined),
        _field(_vehicleReg, 'Vehicle Registration *',
            Icons.directions_car_outlined),
      ],
    );
  }

  Widget _ownershipChip(String value, String label) {
    final selected = _ownership == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() => _ownership = value);
        _pruneStaleDocs();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppTheme.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ── Step 4: Requirements ────────────────────────────────────────────

  Widget _requirementsStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplyStepHeader(
          title: 'Application Requirements',
          subtitle:
              'Please prepare the required documents before submitting your application.',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isFullTime
                      ? 'Requirements for Full-time Riders'
                      : 'Requirements for Part-time Riders',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final doc in _requiredDocs) ...[
          RequirementTile(
            icon: doc.icon,
            title: doc.title,
            subtitle: doc.subtitle,
            staged: _docs.containsKey(doc.key),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: having your resume/biodata and GCash account details ready speeds up the review.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 5: Documents ───────────────────────────────────────────────

  Widget _documentsStep({required Key key}) {
    final missing =
        _requiredDocs.where((d) => !_docs.containsKey(d.key)).length;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplyStepHeader(
          title: 'Upload Documents',
          subtitle: 'Take a clear photo or choose a file for each requirement.',
        ),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: missing == 0
                ? AppColors.accent
                : AppColors.accent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                missing == 0
                    ? Icons.check_circle_outline
                    : Icons.pending_outlined,
                size: 18,
                color: missing == 0
                    ? AppColors.success
                    : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                missing == 0
                    ? 'All required documents selected.'
                    : '$missing required document${missing == 1 ? '' : 's'} remaining.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: missing == 0
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final doc in _requiredDocs) ...[
          DocumentUploadCard(
            title: doc.title,
            subtitle: doc.subtitle,
            required: true,
            filename: _docs[doc.key]?.filename,
            fileSize: _docs[doc.key] != null
                ? formatBytes(_docs[doc.key]!.bytes.length)
                : null,
            onPick: () => _pickDoc(doc.key),
            onRemove: _docs.containsKey(doc.key)
                ? () => _removeDoc(doc.key)
                : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ── Step 6: Review ──────────────────────────────────────────────────

  Widget _reviewStep({required Key key}) {
    final docs = _requiredDocs
        .where((d) => _docs.containsKey(d.key))
        .map((d) => MapEntry(d.title, _docs[d.key]!.filename))
        .toList();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplyStepHeader(
          title: 'Review Your Application',
          subtitle: 'Make sure everything is correct before submitting.',
        ),
        const SizedBox(height: 20),
        ReviewSection(
          title: 'PERSONAL INFORMATION',
          onEdit: () => _jumpTo(0),
          rows: [
            MapEntry(
                'Name', '${_firstName.text.trim()} ${_lastName.text.trim()}'),
            MapEntry('Email', _email.text.trim()),
            MapEntry('Phone', _phone.text.trim()),
            MapEntry('Sex',
                _sex == 'male' ? 'Male' : (_sex == 'female' ? 'Female' : '-')),
            MapEntry('Date of Birth', '$_dobLabel  (Age: $_age)'),
            MapEntry('Address', _address.text.trim()),
          ],
        ),
        const SizedBox(height: 12),
        ReviewSection(
          title: 'RIDER TYPE',
          onEdit: () => _jumpTo(1),
          rows: [MapEntry('Type', _riderTypeLabel)],
        ),
        const SizedBox(height: 12),
        ReviewSection(
          title: 'VEHICLE',
          onEdit: () => _jumpTo(2),
          rows: [
            MapEntry('Vehicle type', _vehicleLabel),
            MapEntry('Ownership', _ownershipLabel),
            MapEntry('License plate', _plate.text.trim()),
            MapEntry('License number', _licenseNo.text.trim()),
            MapEntry(
                'Vehicle registration', _vehicleReg.text.trim()),
          ],
        ),
        const SizedBox(height: 12),
        ReviewSection(
          title: 'DOCUMENTS',
          onEdit: () => _jumpTo(4),
          rows: docs.isEmpty
              ? [const MapEntry('Documents', 'None selected')]
              : docs,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _confirm = !_confirm),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _confirm,
                  activeColor: AppTheme.primary,
                  onChanged: (v) =>
                      setState(() => _confirm = v ?? false),
                ),
                const Expanded(
                  child: Text(
                    'I confirm that the information I provided is accurate.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_submitting) ...[
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 10),
              Text('Submitting application...',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ],
    );
  }

  // ── Shared field ────────────────────────────────────────────────────

  Widget _field(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        // Border, fill and focus outline come from the Invoiz input theme.
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        ),
      ),
    );
  }
}

/// Confirmation screen after a successful submission. The reference number is
/// derived from the application id returned by Laravel
/// (`ApplicationReference.forId`), matching the status screen.
class _ApplySuccessScreen extends StatelessWidget {
  const _ApplySuccessScreen({required this.result, required this.email});

  final RiderApplicationSubmitResult result;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Submitted')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 48, color: AppColors.success),
              ),
              const SizedBox(height: 20),
              const Text(
                'Application Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your rider application has been successfully submitted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'APPLICATION REFERENCE NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.referenceNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please save this reference number. You can use it to check your application status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Check Application Status',
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ApplicationStatusScreen(email: email),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
