import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/health_explorer_model.dart';
import '../../data/health_explorer_data.dart';
import '../../widgets/health_explorer/audio_read_button.dart';
import 'condition_detail_screen.dart';

class OrganHubScreen extends StatefulWidget {
  final BodyOrgan organ;
  final String langCode;
  final List<String> focusOrganIds;

  const OrganHubScreen({
    super.key,
    required this.organ,
    required this.langCode,
    required this.focusOrganIds,
  });

  @override
  State<OrganHubScreen> createState() => _OrganHubScreenState();
}

class _OrganHubScreenState extends State<OrganHubScreen> {
  late String _currentLang;
  bool _largeText = false;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.langCode;
  }

  String _buildSummaryToRead() {
    final organ = widget.organ;
    final name = organ.name.get(_currentLang);
    final func = organ.primaryFunction.get(_currentLang);
    final meta = organ.easyMetaphor.get(_currentLang);

    return "$name। $func। $meta";
  }

  @override
  Widget build(BuildContext context) {
    final bool isHi = _currentLang == 'hi';
    final organ = widget.organ;
    final conditions = HealthExplorerData.getConditionsForOrgan(organ.id);
    final isFocus = widget.focusOrganIds.contains(organ.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          organ.name.get(_currentLang),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: isHi ? "बड़ा फॉन्ट" : "Large Text",
            icon: Icon(
              Icons.format_size,
              color: _largeText ? const Color(0xFF2563EB) : Colors.grey.shade600,
            ),
            onPressed: () => setState(() => _largeText = !_largeText),
          ),
          TextButton(
            onPressed: () => setState(() => _currentLang = _currentLang == 'en' ? 'hi' : 'en'),
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
            if (isFocus)
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
                            ? "⭐ आपके स्वास्थ्य रिकॉर्ड के आधार पर मुख्य केंद्र"
                            : "⭐ Primary focus area from your Health Profile",
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

            // 2. Hero Organ Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(organ.emoji, style: const TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    organ.name.get(_currentLang),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    organ.systemName.get(_currentLang),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  AudioReadButton(
                    textToRead: _buildSummaryToRead(),
                    langCode: _currentLang,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. What it Does Card
            Container(
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
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.psychology_outlined, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isHi ? "यह अंग क्या काम करता है?" : "What this Organ Does",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    organ.primaryFunction.get(_currentLang),
                    style: TextStyle(
                      fontSize: _largeText ? 18 : 15,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb, size: 20, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            organ.easyMetaphor.get(_currentLang),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E40AF),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Conditions & Topics Section Header
            Row(
              children: [
                Text(
                  isHi ? "संबंधित स्वास्थ्य विषय एवं स्थितियां" : "Related Health Topics & Conditions",
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Conditions List Cards
            ...conditions.map((condition) {
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConditionDetailScreen(
                          condition: condition,
                          langCode: _currentLang,
                          isPersonalFocus: isFocus,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(condition.icon, style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                condition.name.get(_currentLang),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: _largeText ? 17 : 15,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isHi ? "लक्षण, कारण एवं दैनिक सावधानियां जानें" : "Symptoms, warning signs & daily habits",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
