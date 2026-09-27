import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../data/medicine_knowledge_data.dart';
import '../models/medicine_knowledge_model.dart';
import 'medicine_info_screen.dart';
import 'patient/nearby_pharmacies_screen.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? existingMedicine;
  final String? initialName;
  final String? initialDosage;
  final int? initialTimesPerDay;
  final List<String>? initialTiming;
  final int? initialStock;
  final String? targetUid;

  const AddMedicineScreen({
    super.key,
    this.existingMedicine,
    this.initialName,
    this.initialDosage,
    this.initialTimesPerDay,
    this.initialTiming,
    this.initialStock,
    this.targetUid,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();

  String name = '';
  String dosage = '';
  int timesPerDay = 1;
  List<String> timing = ["08:00"];
  int stock = 20;
  bool isLoading = false;

  String _originalName = '';
  List<String> _originalTimings = [];
  bool get isEditMode => widget.existingMedicine != null;

  List<MedicineKnowledge> _suggestions = [];
  MedicineKnowledge? _selectedMedicineKnowledge;

  @override
  void initState() {
    super.initState();
    if (widget.existingMedicine != null) {
      final med = widget.existingMedicine!;
      _originalName = med.name;
      _originalTimings = List<String>.from(med.timings ?? (med.time.isNotEmpty ? [med.time] : ["08:00"]));
      name = med.name;
      dosage = med.dosage;
      timesPerDay = _originalTimings.isNotEmpty ? _originalTimings.length : 1;
      timing = List<String>.from(_originalTimings.isNotEmpty ? _originalTimings : ["08:00"]);
      stock = med.totalStock;
      _nameController.text = med.name;
      _dosageController.text = med.dosage;
    } else {
      if (widget.initialName != null) {
        name = widget.initialName!;
        _nameController.text = widget.initialName!;
      }
      if (widget.initialDosage != null) {
        dosage = widget.initialDosage!;
        _dosageController.text = widget.initialDosage!;
      }
      if (widget.initialTiming != null && widget.initialTiming!.isNotEmpty) {
        timing = List<String>.from(widget.initialTiming!);
        timesPerDay = widget.initialTiming!.length;
      } else if (widget.initialTimesPerDay != null) {
        timesPerDay = widget.initialTimesPerDay!;
        _updateTimings(timesPerDay);
      }
      if (widget.initialStock != null) {
        stock = widget.initialStock!;
      }
    }

    if (name.isNotEmpty) {
      _selectedMedicineKnowledge = MedicineKnowledgeData.findByName(name);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    setState(() {
      name = val;
      if (val.trim().isNotEmpty) {
        _suggestions = MedicineKnowledgeData.search(val);
        _selectedMedicineKnowledge = MedicineKnowledgeData.findByName(val);
      } else {
        _suggestions = [];
        _selectedMedicineKnowledge = null;
      }
    });
  }

  void _selectSuggestion(MedicineKnowledge med) {
    setState(() {
      name = med.genericName;
      _nameController.text = med.genericName;
      _selectedMedicineKnowledge = med;
      _suggestions = [];

      // If dosage is currently empty, suggest default dosage
      if (_dosageController.text.trim().isEmpty) {
        dosage = med.defaultDosage;
        _dosageController.text = med.defaultDosage;
      }
    });
  }

  void _updateTimings(int count) {
    setState(() {
      timesPerDay = count;
      if (count == 1) {
        timing = ["08:00"];
      } else if (count == 2) {
        timing = ["08:00", "20:00"];
      } else if (count == 3) {
        timing = ["08:00", "14:00", "20:00"];
      } else if (count == 4) {
        timing = ["08:00", "12:00", "16:00", "20:00"];
      }
    });
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(timing[index].split(":")[0]),
        minute: int.parse(timing[index].split(":")[1]),
      ),
    );
    if (picked != null) {
      setState(() {
        timing[index] = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    
    bool success;
    if (isEditMode) {
      success = await MedicineService.updateMedicine(
        medicineId: widget.existingMedicine!.id,
        oldName: _originalName,
        newName: name.trim(),
        dosage: dosage.trim().isNotEmpty ? dosage.trim() : "1 pill",
        newTimes: timing,
        oldTimes: _originalTimings,
        stock: stock,
        targetUid: widget.targetUid,
      );
    } else {
      success = await MedicineService.addMedicine(
        name: name.trim(),
        dosage: dosage.trim().isNotEmpty ? dosage.trim() : "1 pill",
        times: timing,
        stock: stock,
        targetUid: widget.targetUid,
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save schedule. Check connection.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditMode ? "Edit Medicine" : "Add Medicine",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_pharmacy_outlined),
            tooltip: "Nearby Pharmacies",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NearbyPharmaciesScreen(),
                ),
              );
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
          ),
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Medicine Name Input with Autocomplete
                  Text(
                    "Medicine Name",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Type medicine name (e.g. Lisinopril, Metformin)",
                      prefixIcon: const Icon(Icons.medication, color: Color(0xFF2563EB)),
                      suffixIcon: _nameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _nameController.clear();
                                _onNameChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? "Please enter or select medicine name" : null,
                    onChanged: _onNameChanged,
                  ),

                  // 2. Real-Time Autocomplete Suggestions Dropdown
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, idx) {
                          final med = _suggestions[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(med.icon, style: const TextStyle(fontSize: 20)),
                            ),
                            title: Text(
                              med.genericName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            subtitle: Text(
                              "${med.category.en} • ${med.brandNames.take(2).join(', ')}",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            trailing: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF2563EB)),
                            onTap: () => _selectSuggestion(med),
                          );
                        },
                      ),
                    ),
                  ],

                  // 3. "Know More About This Medicine" Button (if recognized)
                  if (_selectedMedicineKnowledge != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MedicineInfoScreen(
                              medicineKnowledge: _selectedMedicineKnowledge!,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Know More About ${_selectedMedicineKnowledge!.genericName} ℹ️",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: const Color(0xFF1E40AF),
                                    ),
                                  ),
                                  Text(
                                    "${_selectedMedicineKnowledge!.category.en} • Tap for uses, precautions & side effects",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Nearby Pharmacies Option
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NearbyPharmaciesScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("📍", style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Find Nearby Pharmacies 💊",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                                const Text(
                                  "Locate open pharmacies near you to get this medicine",
                                  style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF166534)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Dosage Input
                  Text(
                    "Dosage",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _dosageController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "e.g. 1 pill (500mg), 5ml syrup",
                      prefixIcon: const Icon(Icons.straighten, color: Color(0xFF2563EB)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? "Please enter dosage" : null,
                    onChanged: (val) => dosage = val,
                  ),

                  const SizedBox(height: 20),

                  // 5. Frequency Selection
                  Text(
                    "How many times a day?",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 3, 4].map((n) {
                      final isSelected = timesPerDay == n;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                "$n time${n > 1 ? 's' : ''}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (selected) {
                              if (selected) _updateTimings(n);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 6. Timing Schedule
                  Text(
                    "Set Dose Timings",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(timing.length, (index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(Icons.access_time_filled, color: Color(0xFF2563EB), size: 20),
                        ),
                        title: Text(
                          "Dose ${index + 1}: ${timing[index]}",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        trailing: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB)),
                        onTap: () => _selectTime(context, index),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // 7. Stock Quantity
                  Text(
                    isEditMode ? "Current Stock Quantity" : "Stock Quantity (Initial Pills/Units)",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: stock.toString(),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => stock = int.tryParse(val) ?? 20,
                  ),

                  const SizedBox(height: 30),

                  // 8. Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        isEditMode ? "Save Changes" : "Save Medicine Schedule",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: _saveMedicine,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }
}
