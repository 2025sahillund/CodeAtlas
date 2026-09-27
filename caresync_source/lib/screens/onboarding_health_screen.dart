import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OnboardingHealthScreen extends StatefulWidget {
  const OnboardingHealthScreen({super.key});

  @override
  _OnboardingHealthScreenState createState() => _OnboardingHealthScreenState();
}

class _OnboardingHealthScreenState extends State<OnboardingHealthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  int _currentStep = 0;

  // General Profile
  String name = '';
  String dob = '';
  String gender = 'Male';
  String phone = '';
  String height = '';
  String weight = '';
  String bloodGroup = 'A+';
  String emergencyName = '';
  String emergencyPhone = '';
  String allergies = '';

  // Health Conditions
  bool hasBP = false;
  bool hasTB = false;
  bool hasCancer = false;

  // BP Specifics
  String bpMedication = 'None';
  String bpFrequency = 'Daily';

  // TB Specifics
  String tbStatus = 'Ongoing';
  String tbStartDate = '';

  // Cancer Specifics
  String cancerType = '';
  String cancerStage = 'Stage 1';
  bool familyCancerHistory = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadData();
  }

  Future<void> _checkRoleAndLoadData() async {
    setState(() => isLoading = true);
    
    // Safety check: only patients should be here
    final String? role = await ApiService.getUserRole();
    
    if (role != 'patient') {
      if (mounted) {
        // Safe redirect handled by AuthWrapper via pop
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    final profile = await ApiService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        name = profile['name'] ?? '';
        phone = profile['phone'] ?? '';
        isLoading = false;
      });
    } else if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, {bool isDOB = false}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(isDOB ? const Duration(days: 365 * 20) : Duration.zero),
      firstDate: DateTime(isDOB ? 1900 : 2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        String formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        if (isDOB) {
          dob = formatted;
        } else {
          tbStartDate = formatted;
        }
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final profileData = {
        "name": name,
        "dob": dob,
        "gender": gender,
        "phone": phone,
        "height": int.tryParse(height) ?? 0,
        "weight": int.tryParse(weight) ?? 0,
        "blood_group": bloodGroup,
        "emergency_contact_name": emergencyName,
        "emergency_phone": emergencyPhone,
        "allergies": allergies,
        "has_bp": hasBP ? 1 : 0,
        "has_tb": hasTB ? 1 : 0,
        "has_cancer": hasCancer ? 1 : 0,
        "bp_medication": bpMedication,
        "bp_frequency": bpFrequency,
        "tb_status": tbStatus,
        "tb_treatment_start_date": tbStartDate,
        "cancer_type": cancerType,
        "cancer_treatment_stage": cancerStage,
        "family_cancer_history": familyCancerHistory ? 1 : 0,
      };

      bool success = await ApiService.updateProfile(profileData);

      if (success) {
        await ApiService.completePersonalOnboarding();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile save failed. Please check connection.")),
          );
        }
      }
    } catch (e) {
      debugPrint("Onboarding Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  InputDecoration inputStyle(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        title: const Text("Profile Setup", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
          ),
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  saveProfile();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              steps: [
                Step(
                  title: const Text("Personal"),
                  isActive: _currentStep >= 0,
                  content: Column(
                    children: [
                      TextFormField(
                        initialValue: name,
                        decoration: inputStyle("Full Name"),
                        onChanged: (v) => name = v,
                        validator: (v) => v!.isEmpty ? "Name is required" : null,
                      ),
                      const SizedBox(height: 15),
                      ListTile(
                        title: Text(dob == '' ? "Date of Birth" : "DOB: $dob"),
                        trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                        tileColor: Colors.white,
                        onTap: () => _selectDate(context, isDOB: true),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: inputStyle("Gender"),
                        items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => gender = v!),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        initialValue: phone,
                        decoration: inputStyle("Phone Number"),
                        keyboardType: TextInputType.phone,
                        onChanged: (v) => phone = v,
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: TextFormField(decoration: inputStyle("Height (cm)"), keyboardType: TextInputType.number, onChanged: (v) => height = v)),
                          const SizedBox(width: 10),
                          Expanded(child: TextFormField(decoration: inputStyle("Weight (kg)"), keyboardType: TextInputType.number, onChanged: (v) => weight = v)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: bloodGroup,
                        decoration: inputStyle("Blood Group"),
                        items: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"].map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                        onChanged: (v) => setState(() => bloodGroup = v!),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text("Conditions"),
                  isActive: _currentStep >= 1,
                  content: Column(
                    children: [
                      const Text("Select conditions you would like to track:", style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        title: const Text("Blood Pressure (BP)"),
                        value: hasBP,
                        onChanged: (v) => setState(() => hasBP = v!),
                        activeColor: Colors.blue,
                      ),
                      CheckboxListTile(
                        title: const Text("Tuberculosis (TB)"),
                        value: hasTB,
                        onChanged: (v) => setState(() => hasTB = v!),
                        activeColor: Colors.blue,
                      ),
                      CheckboxListTile(
                        title: const Text("Cancer"),
                        value: hasCancer,
                        onChanged: (v) => setState(() => hasCancer = v!),
                        activeColor: Colors.blue,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(decoration: inputStyle("Known Allergies"), onChanged: (v) => allergies = v),
                      const SizedBox(height: 15),
                      TextFormField(decoration: inputStyle("Emergency Contact Name"), onChanged: (v) => emergencyName = v),
                      const SizedBox(height: 15),
                      TextFormField(decoration: inputStyle("Emergency Phone"), keyboardType: TextInputType.phone, onChanged: (v) => emergencyPhone = v),
                    ],
                  ),
                ),
                Step(
                  title: const Text("Specifics"),
                  isActive: _currentStep >= 2,
                  content: Column(
                    children: [
                      if (!hasBP && !hasTB && !hasCancer)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("No specific data needed for selected conditions. You're all set!"),
                        ),
                      if (hasBP) ...[
                        const Divider(),
                        const Text("BP Specifics", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: inputStyle("Current BP Medication", hint: "e.g. Amlodipine"),
                          onChanged: (v) => bpMedication = v,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: bpFrequency,
                          decoration: inputStyle("Medication Frequency"),
                          items: ["Daily", "Twice Daily", "Weekly"].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (v) => setState(() => bpFrequency = v!),
                        ),
                      ],
                      if (hasTB) ...[
                        const Divider(),
                        const Text("TB Specifics", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: tbStatus,
                          decoration: inputStyle("Treatment Status"),
                          items: ["Ongoing", "Recovered"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => tbStatus = v!),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          title: Text(tbStartDate == '' ? "Treatment Start Date" : "Started: $tbStartDate"),
                          trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                          tileColor: Colors.white,
                          onTap: () => _selectDate(context),
                        ),
                      ],
                      if (hasCancer) ...[
                        const Divider(),
                        const Text("Cancer Specifics", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: inputStyle("Type of Cancer"),
                          onChanged: (v) => cancerType = v,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: cancerStage,
                          decoration: inputStyle("Current Stage/Treatment"),
                          items: ["Stage 1", "Stage 2", "Stage 3", "Stage 4", "Remission", "Chemotherapy"]
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => cancerStage = v!),
                        ),
                        CheckboxListTile(
                          title: const Text("Family History of Cancer"),
                          value: familyCancerHistory,
                          onChanged: (v) => setState(() => familyCancerHistory = v!),
                          activeColor: Colors.blue,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
