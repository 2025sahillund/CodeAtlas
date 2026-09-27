import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/health_explorer_model.dart';
import '../../widgets/health_explorer/audio_read_button.dart';
import '../../widgets/health_explorer/healthy_vs_affected_card.dart';
import '../../widgets/health_explorer/myth_vs_fact_card.dart';
import '../../services/tts_service.dart';

class ConditionDetailScreen extends StatefulWidget {
  final HealthCondition condition;
  final String langCode;
  final bool isPersonalFocus;

  const ConditionDetailScreen({
    super.key,
    required this.condition,
    required this.langCode,
    this.isPersonalFocus = false,
  });

  @override
  State<ConditionDetailScreen> createState() => _ConditionDetailScreenState();
}

class _ConditionDetailScreenState extends State<ConditionDetailScreen> {
  late String _currentLang;
  bool _largeText = false;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.langCode;
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  String _buildFullTextToRead() {
    final isHi = _currentLang == 'hi';
    final name = widget.condition.name.get(_currentLang);
    final explanation = widget.condition.plainExplanation.get(_currentLang);
    final symptoms = widget.condition.commonSymptoms.map((s) => s.get(_currentLang)).join('. ');
    final habits = widget.condition.precautionsAndHabits.map((h) => h.get(_currentLang)).join('. ');

    if (isHi) {
      return "$name के बारे में जानकारी। $explanation। मुख्य लक्षण: $symptoms। दैनिक सावधानियां और आदतें: $habits।";
    } else {
      return "Health guide for $name. $explanation. Common symptoms: $symptoms. Daily precautions and habits: $habits.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isHi = _currentLang == 'hi';
    final condition = widget.condition;
    final double bodyFontSize = _largeText ? 19.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          isHi ? "स्वास्थ्य मार्गदर्शिका" : "Health Guide",
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
              setState(() => _currentLang = _currentLang == 'en' ? 'hi' : 'en');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentLang == 'en' ? "हिंदी" : "English",
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
            // 1. Personal Focus Banner (if relevant)
            if (widget.isPersonalFocus)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFACC15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFCA8A04), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isHi
                            ? "⭐ आपके स्वास्थ्य रिकॉर्ड से संबंधित विषय"
                            : "⭐ Relevant to your Health Records",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: const Color(0xFF854D0E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Condition Title & Audio Read-Aloud
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(condition.icon, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition.name.get(_currentLang),
                        style: GoogleFonts.poppins(
                          fontSize: _largeText ? 22 : 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AudioReadButton(
                        textToRead: _buildFullTextToRead(),
                        langCode: _currentLang,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Plain English / Hindi Explanation Card
            _buildSectionCard(
              title: isHi ? "सरल शब्दों में समझें" : "In Plain English",
              icon: Icons.lightbulb_outline,
              iconColor: Colors.amber.shade700,
              content: Text(
                condition.plainExplanation.get(_currentLang),
                style: TextStyle(
                  fontSize: bodyFontSize,
                  height: 1.6,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Healthy vs Affected Visual Concept (if available)
            if (condition.visualConcept != null) ...[
              HealthyVsAffectedCard(
                concept: condition.visualConcept!,
                langCode: _currentLang,
              ),
              const SizedBox(height: 20),
            ],

            // 5. Common Symptoms Checklist
            _buildSectionCard(
              title: isHi ? "सामान्य लक्षण" : "Common Symptoms",
              icon: Icons.checklist_rounded,
              iconColor: const Color(0xFF2563EB),
              content: Column(
                children: condition.commonSymptoms.map((symptom) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFF2563EB)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            symptom.get(_currentLang),
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              height: 1.4,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 6. RED FLAG EMERGENCY CALLOUT BOX
            if (condition.redFlagWarnings.isNotEmpty) ...[
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
                        const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isHi ? "🚨 आपातकालीन खतरे के संकेत (तुरंत डॉक्टर को दिखाएं)" : "🚨 Emergency Red Flags (Seek Immediate Care)",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...condition.redFlagWarnings.map((warning) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          warning.get(_currentLang),
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

            // 7. Daily Habits & Precautions
            _buildSectionCard(
              title: isHi ? "दैनिक आदतें एवं सावधानियां" : "Daily Habits & Care",
              icon: Icons.health_and_safety_outlined,
              iconColor: const Color(0xFF16A34A),
              content: Column(
                children: condition.precautionsAndHabits.map((habit) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            habit.get(_currentLang),
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              height: 1.4,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 8. Questions for Doctor
            if (condition.questionsForDoctor.isNotEmpty) ...[
              _buildSectionCard(
                title: isHi ? "डॉक्टर से क्या पूछें?" : "Questions for Your Doctor",
                icon: Icons.question_answer_outlined,
                iconColor: Colors.purple.shade600,
                content: Column(
                  children: condition.questionsForDoctor.map((q) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 18, color: Colors.purple),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.get(_currentLang),
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 9. Myths vs Facts (if available)
            if (condition.mythsAndFacts != null && condition.mythsAndFacts!.isNotEmpty) ...[
              ...condition.mythsAndFacts!.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MythVsFactCard(item: item, langCode: _currentLang),
                );
              }),
            ],

            const SizedBox(height: 24),

            // 10. Educational Disclaimer Footer
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
                          ? "यह जानकारी केवल सामान्य स्वास्थ्य शिक्षा के लिए है। किसी भी चिकित्सीय निर्णय के लिए हमेशा अपने चिकित्सक से परामर्श लें।"
                          : "This educational guide is for informational purposes only and does not substitute professional medical consultation or diagnosis.",
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
