import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/medicine_service.dart';
import '../models/medicine.dart';
import 'add_medicine_screen.dart';

class ScanPrescriptionScreen extends StatefulWidget {
  const ScanPrescriptionScreen({super.key});

  @override
  State<ScanPrescriptionScreen> createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  bool isScanning = false;
  bool scanned = false;
  File? _image;
  final picker = ImagePicker();
  final textRecognizer = TextRecognizer();

  List<Map<String, dynamic>> detectedMedicines = [];

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  Future<void> handlePickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        isScanning = true;
        scanned = false;
      });
      _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;

    final inputImage = InputImage.fromFile(_image!);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      List<Map<String, dynamic>> results = [];
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String text = line.text.trim();
          if (text.length > 3) {
            RegExp dosageRegExp = RegExp(r"(\d+(\.\d+)?\s*(mg|ml|mcg|g|tabs|units))", caseSensitive: false);
            Match? match = dosageRegExp.firstMatch(text);
            
            if (match != null) {
              String dosage = match.group(0)!;
              String name = text.replaceFirst(dosage, "").trim();
              if (name.isNotEmpty) {
                results.add({
                  "name": name,
                  "dosage": dosage,
                  "frequency": "Once Daily",
                  "timing": ["09:00"],
                });
              }
            } else if (text.split(' ').length <= 3 && !text.contains(RegExp(r'[0-9]'))) {
              results.add({
                "name": text,
                "dosage": "As directed",
                "frequency": "Once Daily",
                "timing": ["09:00"],
              });
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        detectedMedicines = results.take(10).toList(); 
        isScanning = false;
        scanned = true;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No medicines detected. Please try a clearer photo or add manually.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error processing image: $e")),
      );
    }
  }

  void _showEditDialog(int? index) {
    final bool isNew = index == null;
    final Map<String, dynamic> med = isNew 
        ? {"name": "", "dosage": "As directed", "frequency": "Once Daily", "timing": ["09:00"]}
        : Map<String, dynamic>.from(detectedMedicines[index]);

    final nameController = TextEditingController(text: med["name"]);
    final dosageController = TextEditingController(text: med["dosage"]);
    String frequency = med["frequency"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNew ? "Add Medicine" : "Edit Medicine"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Medicine Name"),
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: "Dosage"),
              ),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                items: ["Once Daily", "Twice Daily", "Thrice Daily"].map((f) => 
                  DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) => frequency = val!,
                decoration: const InputDecoration(labelText: "Frequency"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              setState(() {
                final updatedMed = {
                  "name": nameController.text,
                  "dosage": dosageController.text,
                  "frequency": frequency,
                  "timing": med["timing"],
                };
                if (isNew) {
                  detectedMedicines.add(updatedMed);
                  scanned = true; 
                } else {
                  detectedMedicines[index] = updatedMed;
                }
              });
              Navigator.pop(context);
            }, 
            child: const Text("Done")
          ),
        ],
      ),
    );
  }

  void _removeMedicine(int index) {
    setState(() {
      detectedMedicines.removeAt(index);
    });
  }

  Future<void> _confirmAndSave() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (detectedMedicines.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("No medicines to save.")));
      return;
    }

    setState(() => isScanning = true);
    
    try {
      final List<Medicine> existingMeds = await MedicineService.getInventory();
      int savedCount = 0;
      int skippedCount = 0;

      for (var med in detectedMedicines) {
        // Simple Duplicate Check
        bool exists = existingMeds.any((e) => e.name.toLowerCase() == med["name"].toString().toLowerCase());
        
        if (!exists) {
          bool success = await MedicineService.addMedicine(
            name: med["name"],
            dosage: med["dosage"],
            times: List<String>.from(med["timing"]),
            stock: 20,
          );
          if (success) savedCount++;
        } else {
          skippedCount++;
        }
      }

      if (mounted) {
        setState(() => isScanning = false);
      }
      
      String message = "$savedCount medicines saved.";
      if (skippedCount > 0) message += " $skippedCount skipped as duplicates.";
      
      messenger.showSnackBar(SnackBar(content: Text(message)));
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => isScanning = false);
      }
      messenger.showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Scan Prescription"),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.purple, Colors.pink]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!scanned && !isScanning)
              Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.description, size: 60, color: Colors.purple),
                        SizedBox(height: 15),
                        Text("Upload Prescription", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text("Take a photo or upload image to extract medicines.", textAlign: TextAlign.center),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => handlePickImage(ImageSource.camera),
                              icon: Icon(Icons.camera),
                              label: Text("Take Photo"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade100),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => handlePickImage(ImageSource.gallery),
                              icon: Icon(Icons.upload),
                              label: Text("Upload"),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        TextButton.icon(
                          onPressed: () => _showEditDialog(null),
                          icon: Icon(Icons.add),
                          label: Text("Add Manually Instead"),
                        )
                      ],
                    ),
                  ),
                ),
              ),

            if (isScanning)
              Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator(color: Colors.purple)),
              ),

            if (scanned && !isScanning) ...[
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Review Detected Medicines", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => _showEditDialog(null),
                          icon: Icon(Icons.add),
                          label: Text("Add"),
                        )
                      ],
                    ),
                    SizedBox(height: 10),
                    if (detectedMedicines.isEmpty)
                      Center(child: Text("No medicines in list. Click 'Add' or 'Scan Again'.")),
                    ...detectedMedicines.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var med = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    child: const Icon(Icons.medication, color: Color(0xFF2563EB), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(med["name"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text("${med["dosage"]} • ${med["frequency"]}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    tooltip: "Quick Edit",
                                    onPressed: () => _showEditDialog(idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    tooltip: "Remove",
                                    onPressed: () => _removeMedicine(idx),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.schedule, size: 16),
                                  label: const Text("Customize & Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final saved = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddMedicineScreen(
                                          initialName: med["name"],
                                          initialDosage: med["dosage"],
                                          initialTiming: med["timing"] is List<String>
                                              ? List<String>.from(med["timing"])
                                              : null,
                                          initialStock: 20,
                                        ),
                                      ),
                                    );
                                    if (saved == true) {
                                      _removeMedicine(idx);
                                      messenger.showSnackBar(
                                        SnackBar(content: Text("Scheduled ${med['name']}")),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() { scanned = false; _image = null; }),
                            child: Text("Scan Again"),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmAndSave,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: Text("Confirm & Save All"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],

            Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("ℹ️ Please verify medicines with your doctor. OCR detection is provided for convenience and must be reviewed.", style: TextStyle(fontSize: 12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget howItWorksStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(number, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ],
          ),
        )
      ],
    );
  }
}
