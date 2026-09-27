import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'medical_passport_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  bool isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _allergiesController;
  
  // BP
  late TextEditingController _bpMedController;
  
  // TB
  late TextEditingController _tbDateController;
  
  // Cancer
  late TextEditingController _cancerTypeController;

  String _gender = 'Male';
  String _bloodGroup = 'A+';
  bool _hasBP = false;
  bool _hasTB = false;
  bool _hasCancer = false;
  
  String _bpFreq = 'Daily';
  String _tbStatus = 'Ongoing';
  String _cancerStage = 'Stage 1';
  bool _familyCancerHistory = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoading = true);
    final data = await ApiService.getProfile();
    if (data != null) {
      profileData = data;
      _initControllers(data);
    }
    setState(() => isLoading = false);
  }

  void _initControllers(Map<String, dynamic> data) {
    _nameController = TextEditingController(text: data['name'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _dobController = TextEditingController(text: data['dob'] ?? '');
    _heightController = TextEditingController(text: data['height']?.toString() ?? '');
    _weightController = TextEditingController(text: data['weight']?.toString() ?? '');
    _emergencyNameController = TextEditingController(text: data['emergency_contact_name'] ?? '');
    _emergencyPhoneController = TextEditingController(text: data['emergency_phone'] ?? '');
    _allergiesController = TextEditingController(text: data['allergies'] ?? '');
    
    _bpMedController = TextEditingController(text: data['bp_medication'] ?? '');
    _tbDateController = TextEditingController(text: data['tb_treatment_start_date'] ?? '');
    _cancerTypeController = TextEditingController(text: data['cancer_type'] ?? '');

    _gender = data['gender'] ?? 'Male';
    _bloodGroup = data['blood_group'] ?? 'A+';
    _hasBP = data['has_bp'] == 1;
    _hasTB = data['has_tb'] == 1;
    _hasCancer = data['has_cancer'] == 1;
    
    _bpFreq = data['bp_frequency'] ?? 'Daily';
    _tbStatus = data['tb_status'] ?? 'Ongoing';
    _cancerStage = data['cancer_treatment_stage'] ?? 'Stage 1';
    _familyCancerHistory = data['family_cancer_history'] == 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _allergiesController.dispose();
    _bpMedController.dispose();
    _tbDateController.dispose();
    _cancerTypeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await ApiService.logout(context);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final heightVal = int.tryParse(_heightController.text.trim());
    final weightVal = int.tryParse(_weightController.text.trim());
    if (_heightController.text.trim().isNotEmpty && (heightVal == null || heightVal < 50 || heightVal > 250)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid height between 50 and 250 cm")),
      );
      return;
    }
    if (_weightController.text.trim().isNotEmpty && (weightVal == null || weightVal < 20 || weightVal > 300)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid weight between 20 and 300 kg")),
      );
      return;
    }

    setState(() => isLoading = true);
    final updatedData = {
      "name": _nameController.text.trim(),
      "dob": _dobController.text.trim(),
      "gender": _gender,
      "phone": _phoneController.text.trim(),
      "height": heightVal ?? 0,
      "weight": weightVal ?? 0,
      "blood_group": _bloodGroup,
      "emergency_contact_name": _emergencyNameController.text,
      "emergency_phone": _emergencyPhoneController.text,
      "allergies": _allergiesController.text,
      "has_bp": _hasBP ? 1 : 0,
      "has_tb": _hasTB ? 1 : 0,
      "has_cancer": _hasCancer ? 1 : 0,
      "bp_medication": _bpMedController.text,
      "bp_frequency": _bpFreq,
      "tb_status": _tbStatus,
      "tb_treatment_start_date": _tbDateController.text,
      "cancer_type": _cancerTypeController.text,
      "cancer_treatment_stage": _cancerStage,
      "family_cancer_history": _familyCancerHistory ? 1 : 0,
    };

    bool success = await ApiService.updateProfile(updatedData);
    if (success) {
      await _loadProfile();
      setState(() => isEditing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
    } else {
      setState(() => isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile")));
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, {bool isDOB = false}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(isDOB ? const Duration(days: 365 * 20) : Duration.zero),
      firstDate: DateTime(isDOB ? 1900 : 2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        title: Text(isEditing ? "Edit Profile" : "My Profile"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
          ),
        ),
        actions: [
          if (!isEditing)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => isEditing = true))
          else ...[
            IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => isEditing = false)),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildCareSyncIdSection(),
              if (!isEditing) ...[
                const SizedBox(height: 16),
                _buildMedicalPassportBanner(),
              ],
              const SizedBox(height: 20),
              _buildPersonalInfo(),
              const SizedBox(height: 20),
              _buildHealthConditions(),
              if (_hasBP) ...[const SizedBox(height: 20), _buildBPDetails()],
              if (_hasTB) ...[const SizedBox(height: 20), _buildTBDetails()],
              if (_hasCancer) ...[const SizedBox(height: 20), _buildCancerDetails()],
              const SizedBox(height: 20),
              _buildEmergencyContact(),
              const SizedBox(height: 30),
              if (!isEditing)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text("Logout Session", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _handleLogout,
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.blue)),
        const SizedBox(height: 10),
        Text(profileData?['email'] ?? "No Email", style: const TextStyle(color: Colors.grey)),
        if (!isEditing) Text(profileData?['name'] ?? "User", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCareSyncIdSection() {
    final uid = ApiService.currentUid ?? 'Not Available';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2563EB).withValues(alpha: 0.05),
              const Color(0xFF10B981).withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  "CareSync ID",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      uid,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Color(0xFF2563EB)),
                    tooltip: "Copy CareSync ID",
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      if (ApiService.currentUid != null) {
                        Clipboard.setData(ClipboardData(text: ApiService.currentUid!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text("CareSync ID copied to clipboard!"),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2563EB),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Share this ID with a caregiver to connect your accounts.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalPassportBanner() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicalPassportScreen()),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_ind_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Patient Medical Passport",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Doctor-ready summary with 1-tap PDF export",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return _buildSectionCard("Personal Information", Icons.person, [
      if (isEditing) ...[
        _editField("Full Name", _nameController),
        _editDate("Date of Birth", _dobController, isDOB: true),
        _editDropdown("Gender", _gender, ["Male", "Female", "Other"], (v) => setState(() => _gender = v!)),
        _editField("Phone", _phoneController, type: TextInputType.phone),
        Row(children: [
          Expanded(child: _editField("Height (cm)", _heightController, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _editField("Weight (kg)", _weightController, type: TextInputType.number)),
        ]),
        _editDropdown("Blood Group", _bloodGroup, ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"], (v) => setState(() => _bloodGroup = v!)),
      ] else ...[
        _infoRow("Name", profileData?['name'] ?? "--"),
        _infoRow("DOB", profileData?['dob'] ?? "--"),
        _infoRow(
          "Age",
          () {
            final age = ApiService.calculateAge(profileData?['dob'] ?? profileData?['age']);
            return age != null ? "$age Years" : "--";
          }(),
        ),
        _infoRow("Gender", profileData?['gender'] ?? "--"),
        _infoRow("Phone", profileData?['phone'] ?? "--"),
        _infoRow("Height", "${profileData?['height'] ?? "--"} cm"),
        _infoRow("Weight", "${profileData?['weight'] ?? "--"} kg"),
        _infoRow("Blood Group", profileData?['blood_group'] ?? "--"),
      ]
    ]);
  }

  Widget _buildHealthConditions() {
    return _buildSectionCard("Health Conditions", Icons.track_changes, [
      if (isEditing) ...[
        CheckboxListTile(title: const Text("Blood Pressure (BP)"), value: _hasBP, onChanged: (v) => setState(() => _hasBP = v!)),
        CheckboxListTile(title: const Text("Tuberculosis (TB)"), value: _hasTB, onChanged: (v) => setState(() => _hasTB = v!)),
        CheckboxListTile(title: const Text("Cancer"), value: _hasCancer, onChanged: (v) => setState(() => _hasCancer = v!)),
        _editField("Allergies", _allergiesController),
      ] else ...[
        _conditionBadge("Hypertension (BP)", _hasBP),
        _conditionBadge("Tuberculosis (TB)", _hasTB),
        _conditionBadge("Cancer", _hasCancer),
        _infoRow("Allergies", profileData?['allergies'] ?? "None"),
      ]
    ]);
  }

  Widget _buildBPDetails() {
    return _buildSectionCard("BP Details", Icons.medical_services, [
      if (isEditing) ...[
        _editField("Medication", _bpMedController),
        _editDropdown("Frequency", _bpFreq, ["Daily", "Twice Daily", "Weekly"], (v) => setState(() => _bpFreq = v!)),
      ] else ...[
        _infoRow("Medication", profileData?['bp_medication'] ?? "--"),
        _infoRow("Frequency", profileData?['bp_frequency'] ?? "--"),
      ]
    ]);
  }

  Widget _buildTBDetails() {
    return _buildSectionCard("TB Details", Icons.healing, [
      if (isEditing) ...[
        _editDropdown("Status", _tbStatus, ["Ongoing", "Recovered"], (v) => setState(() => _tbStatus = v!)),
        _editDate("Treatment Start Date", _tbDateController),
      ] else ...[
        _infoRow("Status", profileData?['tb_status'] ?? "--"),
        _infoRow("Started", profileData?['tb_treatment_start_date'] ?? "--"),
      ]
    ]);
  }

  Widget _buildCancerDetails() {
    return _buildSectionCard("Cancer Details", Icons.health_and_safety, [
      if (isEditing) ...[
        _editField("Cancer Type", _cancerTypeController),
        _editDropdown("Stage", _cancerStage, ["Stage 1", "Stage 2", "Stage 3", "Stage 4", "Remission", "Chemotherapy"], (v) => setState(() => _cancerStage = v!)),
        CheckboxListTile(title: const Text("Family History"), value: _familyCancerHistory, onChanged: (v) => setState(() => _familyCancerHistory = v!)),
      ] else ...[
        _infoRow("Type", profileData?['cancer_type'] ?? "--"),
        _infoRow("Stage", profileData?['cancer_treatment_stage'] ?? "--"),
        _infoRow("Family History", _familyCancerHistory ? "Yes" : "No"),
      ]
    ]);
  }

  Widget _buildEmergencyContact() {
    return _buildSectionCard("Emergency Contact", Icons.emergency, [
      if (isEditing) ...[
        _editField("Contact Name", _emergencyNameController),
        _editField("Contact Phone", _emergencyPhoneController, type: TextInputType.phone),
      ] else ...[
        _infoRow("Name", profileData?['emergency_contact_name'] ?? "--"),
        _infoRow("Phone", profileData?['emergency_phone'] ?? "--"),
      ]
    ]);
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.blue, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)), Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))]),
    );
  }

  Widget _conditionBadge(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [Icon(isActive ? Icons.check_circle : Icons.cancel, color: isActive ? Colors.green : Colors.grey, size: 18), const SizedBox(width: 10), Text(label, style: TextStyle(color: isActive ? Colors.black87 : Colors.grey))]),
    );
  }

  Widget _editField(String label, TextEditingController controller, {TextInputType type = TextInputType.text}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controller, keyboardType: type, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))));
  }

  Widget _editDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: onChanged));
  }

  Widget _editDate(String label, TextEditingController controller, {bool isDOB = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: const Icon(Icons.calendar_today)),
        onTap: () => _selectDate(context, controller, isDOB: isDOB),
      ),
    );
  }
}
