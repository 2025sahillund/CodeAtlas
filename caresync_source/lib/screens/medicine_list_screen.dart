import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_medicine_screen.dart';
import 'medicine_info_screen.dart';
import '../services/medicine_service.dart';
import '../models/medicine.dart';
import '../data/medicine_knowledge_data.dart';

class MedicineListScreen extends StatefulWidget {
  final String? targetUid;
  final bool isReadOnly;
  const MedicineListScreen({super.key, this.targetUid, this.isReadOnly = false});

  @override
  _MedicineListScreenState createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  late Future<List<Medicine>> medicinesFuture;

  @override
  void initState() {
    super.initState();
    _refreshMedicines();
  }

  void _refreshMedicines() {
    setState(() {
      medicinesFuture = MedicineService.getInventory(targetUid: widget.targetUid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMedicineScreen()),
                ).then((_) => _refreshMedicines());
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Medicine"),
            ),
      body: Column(
        children: [
          /// HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(widget.isReadOnly ? "Patient Medicines" : "My Medicines",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.isReadOnly ? "View-only patient medication records" : "Synced with Cloud Backup", style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          /// LIST
          Expanded(
            child: FutureBuilder<List<Medicine>>(
              future: medicinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Sync Error: ${snapshot.error}"));
                }
                
                final medicines = snapshot.data ?? [];
                if (medicines.isEmpty) {
                  return Center(
                    child: Text(widget.isReadOnly ? "No medicines recorded for this patient." : "No Medicines. Add one to sync with cloud."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = medicines[index];
                    final int stock = medicine.totalStock; 
                    final double stockPercentage = (stock / (stock > 20 ? stock : 20)).clamp(0.0, 1.0);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(medicine.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(medicine.dosage),
                                  ],
                                ),
                                Chip(
                                  label: Text(stock < 5 ? "Critical" : stock < 10 ? "Low" : "OK"),
                                  backgroundColor: stock < 5 ? Colors.red.shade100 : stock < 10 ? Colors.orange.shade100 : Colors.green.shade100,
                                )
                              ],
                            ),
                            
                            const SizedBox(height: 10),
                            
                            // Display All Scheduled Doses for this Medicine
                            if (medicine.timings != null && medicine.timings!.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: medicine.timings!.map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                )).toList(),
                              ),

                            const SizedBox(height: 15),
                            LinearProgressIndicator(
                              value: stockPercentage,
                              backgroundColor: Colors.grey.shade200,
                              color: stock < 10 ? Colors.red : Colors.blue,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("$stock units remaining"),
                                InkWell(
                                  onTap: () {
                                    final medKnowledge = MedicineKnowledgeData.findByName(medicine.name);
                                    if (medKnowledge != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MedicineInfoScreen(medicineKnowledge: medKnowledge),
                                        ),
                                      );
                                    } else {
                                      _showCustomMedicineInfo(context, medicine);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 5),
                                        Text(
                                          "Know More ℹ️",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: const Color(0xFF1E40AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            if (!widget.isReadOnly) ...[
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  // 1. Refill Action
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showRefillDialog(context, medicine, stock),
                                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                                      label: const Text("Refill"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2563EB),
                                        side: const BorderSide(color: Color(0xFF93C5FD)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 2. Manual Deduct Stock Action
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showDeductStockDialog(context, medicine, stock),
                                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                                      label: const Text("Deduct"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFD97706),
                                        side: const BorderSide(color: Color(0xFFFCD34D)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // 3. Edit Action
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                                    tooltip: "Edit Medicine",
                                    onPressed: () async {
                                      final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddMedicineScreen(
                                            existingMedicine: medicine,
                                            targetUid: widget.targetUid,
                                          ),
                                        ),
                                      );
                                      if (updated == true) {
                                        _refreshMedicines();
                                      }
                                    },
                                  ),
                                  // 4. Delete Action
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: "Remove Medicine",
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text("Remove Medicine?"),
                                          content: Text("This will delete ${medicine.name} from your inventory and cloud backup."),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (confirmed == true) {
                                        await MedicineService.deleteMedicine(
                                          medicineId: medicine.id,
                                          medicineName: medicine.name,
                                          timings: medicine.timings,
                                          targetUid: widget.targetUid,
                                        );
                                        _refreshMedicines();
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(content: Text("Deleted ${medicine.name}")),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRefillDialog(BuildContext context, Medicine medicine, int currentStock) {
    int refillAmount = 10;
    final customController = TextEditingController(text: "10");
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final predictedStock = currentStock + refillAmount;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Refill Stock",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        medicine.name,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current Stock: ", style: TextStyle(color: Colors.grey.shade700)),
                      Text("$currentStock units", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("After Refill: ", style: TextStyle(color: Colors.grey.shade700)),
                      Text(
                        "$predictedStock units",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Select Refill Quantity:",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [10, 20, 30].map((qty) {
                      final selected = !isCustom && refillAmount == qty;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text("+$qty"),
                          selected: selected,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                isCustom = false;
                                refillAmount = qty;
                                customController.text = qty.toString();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Custom Refill Quantity",
                      prefixIcon: const Icon(Icons.add, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      setDialogState(() {
                        isCustom = true;
                        refillAmount = parsed;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (refillAmount <= 0)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(dialogCtx);
                        final success = await MedicineService.refillStock(
                          medicineId: medicine.id,
                          medicineName: medicine.name,
                          currentStock: currentStock,
                          amount: refillAmount,
                          targetUid: widget.targetUid,
                        );
                        _refreshMedicines();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? "Refilled $refillAmount units of ${medicine.name}. New stock: $predictedStock"
                                  : "Failed to refill stock.",
                            ),
                            backgroundColor: success ? const Color(0xFF16A34A) : Colors.red,
                          ),
                        );
                      },
                child: const Text("Confirm Refill"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeductStockDialog(BuildContext context, Medicine medicine, int currentStock) {
    int deductAmount = 1;
    final customController = TextEditingController(text: "1");
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final predictedStock = (currentStock - deductAmount).clamp(0, 99999);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Deduct Stock",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        medicine.name,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Manually reduces inventory (e.g. dropped, damaged, or lost pills) without recording dose.",
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current Stock: ", style: TextStyle(color: Colors.grey.shade700)),
                      Text("$currentStock units", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("After Deduction: ", style: TextStyle(color: Colors.grey.shade700)),
                      Text(
                        "$predictedStock units",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: predictedStock < 5 ? Colors.red : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Select Quantity to Deduct:",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 5, 10].map((qty) {
                      final selected = !isCustom && deductAmount == qty;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text("-$qty"),
                          selected: selected,
                          selectedColor: const Color(0xFFD97706),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                isCustom = false;
                                deductAmount = qty;
                                customController.text = qty.toString();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Custom Quantity",
                      prefixIcon: const Icon(Icons.remove, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      setDialogState(() {
                        isCustom = true;
                        deductAmount = parsed;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (deductAmount <= 0)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(dialogCtx);
                        final success = await MedicineService.deductStock(
                          medicineId: medicine.id,
                          medicineName: medicine.name,
                          currentStock: currentStock,
                          amount: deductAmount,
                          targetUid: widget.targetUid,
                        );
                        _refreshMedicines();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? "Deducted $deductAmount units of ${medicine.name}. New stock: $predictedStock"
                                  : "Failed to deduct stock.",
                            ),
                            backgroundColor: success ? const Color(0xFFD97706) : Colors.red,
                          ),
                        );
                      },
                child: const Text("Confirm Deduction"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCustomMedicineInfo(BuildContext context, Medicine medicine) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text("💊", style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text("Dosage: ${medicine.dosage}", style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                "Important Patient Safety Reminder:",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                "Please take this medication strictly according to the specific dosage, timing, and meal directions given by your doctor or pharmacist. Never change or stop prescribed medication on your own.",
                style: TextStyle(color: Colors.grey.shade800, height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Understood / समझ आ गया", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
