import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/medicine_knowledge_model.dart';
import '../data/health_explorer_data.dart';
import '../widgets/health_explorer/audio_read_button.dart';
import '../services/tts_service.dart';
import 'health_explorer/organ_hub_screen.dart';

class MedicineInfoScreen extends StatefulWidget {
  final MedicineKnowledge medicineKnowledge;
  final String initialLangCode;

  const MedicineInfoScreen({
    super.key,
    required this.medicineKnowledge,
    this.initialLangCode = 'en',
  });

  @override
  State<MedicineInfoScreen> createState() => _MedicineInfoScreenState();
}

class _MedicineInfoScreenState extends State<MedicineInfoScreen> {
  late String _langCode;
  bool _largeText = false;

  @override
  void initState() {
    super.initState();
    _langCode = widget.initialLangCode;
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  String _buildFullTextToRead() {
    final med = widget.medicineKnowledge;
    final isHi = _langCode == 'hi';
    final name = med.name.get(_langCode);
    final whatItIs = med.whatItIs.get(_langCode);
    final why = med.whyPrescribed.get(_langCode);
    final how = med.howItWorks.get(_langCode);
    final food = med.foodGuidance.get(_langCode);

    if (isHi) {
      return "$name के बारे में जानकारी। $whatItIs। यह क्यों दी जाती है: $why। कैसे काम करती है: $how। भोजन सलाह: $food।";
    } else {
      return "Information for $name. $whatItIs. Why it is prescribed: $why. How it works: $how. Food guidance: $food.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.medicineKnowledge;
    final bool isHi = _langCode == 'hi';
    final double bodyFontSize = _largeText ? 19.0 : 16.0;
    final relatedOrgan = HealthExplorerData.getOrganById(med.relatedOrganId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          isHi ? "दवा की संपूर्ण जानकारी" : "Medicine Guide",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Text size toggle
          IconButton(
            tooltip: isHi ? "बड़ा फॉन्ट" : "Large Text",
            icon: Icon(
              Icons.format_size,
              color: _largeText ? const Color(0xFF2563EB) : Colors.grey.shade600,
            ),
            onPressed: () => setState(() => _largeText = !_largeText),
          ),
          // Language toggle
          TextButton(
            onPressed: () {
              TtsService.stop();
              setState(() => _langCode = _langCode == 'en' ? 'hi' : 'en');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _langCode == 'en' ? "हिंदी" : "English",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Medicine Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(med.icon, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med.name.get(_langCode),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: _largeText ? 22 : 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              med.category.get(_langCode),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (med.brandNames.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: med.brandNames.map((brand) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            brand,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  AudioReadButton(
                    textToRead: _buildFullTextToRead(),
                    langCode: _langCode,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Related Body Organ Link Chip
            if (relatedOrgan != null) ...[
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrganHubScreen(
                        organ: relatedOrgan,
                        langCode: _langCode,
                        focusOrganIds: const [],
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Text(relatedOrgan.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHi ? "संबंधित अंग: ${relatedOrgan.name.get(_langCode)}" : "Target Organ: ${relatedOrgan.name.get(_langCode)}",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                            Text(
                              isHi ? "अंग के बारे में विस्तार से जानने के लिए टैप करें →" : "Tap to explore this organ in Health Explorer →",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 3. What is it?
            _buildSectionCard(
              title: isHi ? "यह दवा क्या है?" : "What is this medicine?",
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF2563EB),
              content: Text(
                med.whatItIs.get(_langCode),
                style: TextStyle(fontSize: bodyFontSize, height: 1.5, color: Colors.grey.shade800),
              ),
            ),

            const SizedBox(height: 18),

            // 4. Why is it prescribed?
            _buildSectionCard(
              title: isHi ? "डॉक्टर यह दवा क्यों देते हैं?" : "Why is it prescribed?",
              icon: Icons.assignment_outlined,
              iconColor: Colors.teal.shade700,
              content: Text(
                med.whyPrescribed.get(_langCode),
                style: TextStyle(fontSize: bodyFontSize, height: 1.5, color: Colors.grey.shade800),
              ),
            ),

            const SizedBox(height: 18),

            // 5. How does it work?
            _buildSectionCard(
              title: isHi ? "यह शरीर में कैसे काम करती है?" : "How does it work?",
              icon: Icons.lightbulb_outline_rounded,
              iconColor: Colors.amber.shade800,
              content: Text(
                med.howItWorks.get(_langCode),
                style: TextStyle(fontSize: bodyFontSize, height: 1.5, color: Colors.grey.shade800),
              ),
            ),

            const SizedBox(height: 18),

            // 6. Food & Timing Guidance
            _buildSectionCard(
              title: isHi ? "भोजन और समय संबंधी सलाह" : "Food & Timing Advice",
              icon: Icons.restaurant_outlined,
              iconColor: Colors.orange.shade800,
              content: Text(
                med.foodGuidance.get(_langCode),
                style: TextStyle(
                  fontSize: bodyFontSize,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 7. Common Side Effects
            if (med.commonSideEffects.isNotEmpty) ...[
              _buildSectionCard(
                title: isHi ? "सामान्य दुष्प्रभाव (Side Effects)" : "Common Side Effects",
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.amber.shade700,
                content: Column(
                  children: med.commonSideEffects.map((sideEffect) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.fiber_manual_record, size: 8, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sideEffect.get(_langCode),
                              style: TextStyle(fontSize: bodyFontSize, height: 1.4, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 8. Important Precautions
            if (med.commonPrecautions.isNotEmpty) ...[
              _buildSectionCard(
                title: isHi ? "जरूरी सावधानियां" : "Important Precautions",
                icon: Icons.shield_outlined,
                iconColor: Colors.green.shade700,
                content: Column(
                  children: med.commonPrecautions.map((precaution) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              precaution.get(_langCode),
                              style: TextStyle(fontSize: bodyFontSize, height: 1.4, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 9. RED FLAG WARNINGS
            if (med.whenToContactDoctor.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isHi ? "🚨 डॉक्टर से तुरंत कब संपर्क करें?" : "🚨 When to Contact Doctor Urgently",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...med.whenToContactDoctor.map((warning) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          warning.get(_langCode),
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF991B1B),
                            height: 1.4,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 10. Medical Disclaimer Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHi
                          ? "यह जानकारी केवल सामान्य शिक्षा के लिए है। अपनी दवा, खुराक और समय का पालन हमेशा अपने डॉक्टर या फार्मासिस्ट के पर्चे के अनुसार ही करें।"
                          : "This educational guide is for general awareness. Always follow your doctor's or pharmacist's specific prescription for dosage and timing.",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }
}
