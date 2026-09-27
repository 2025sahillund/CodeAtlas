import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/health_explorer_model.dart';

class HealthyVsAffectedCard extends StatefulWidget {
  final VisualConcept concept;
  final String langCode;

  const HealthyVsAffectedCard({
    super.key,
    required this.concept,
    required this.langCode,
  });

  @override
  State<HealthyVsAffectedCard> createState() => _HealthyVsAffectedCardState();
}

class _HealthyVsAffectedCardState extends State<HealthyVsAffectedCard> {
  bool _showAffected = false;

  @override
  Widget build(BuildContext context) {
    final bool isHi = widget.langCode == 'hi';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isHi ? "स्वस्थ बनाम प्रभावित अवस्था" : "Healthy vs Affected Concept",
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

          // Segmented Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAffected = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_showAffected ? Colors.green.shade600 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_showAffected
                            ? [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            isHi ? "स्वस्थ अंग" : "Healthy State",
                            style: GoogleFonts.poppins(
                              color: !_showAffected ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAffected = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _showAffected ? Colors.orange.shade700 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _showAffected
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            isHi ? "प्रभावित अवस्था" : "Affected State",
                            style: GoogleFonts.poppins(
                              color: _showAffected ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dynamic Content Box with Animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey<bool>(_showAffected),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _showAffected ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _showAffected ? Colors.orange.shade200 : Colors.green.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _showAffected ? widget.concept.affectedIcon : widget.concept.healthyIcon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _showAffected
                              ? widget.concept.affectedTitle.get(widget.langCode)
                              : widget.concept.healthyTitle.get(widget.langCode),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _showAffected ? Colors.orange.shade900 : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _showAffected
                        ? widget.concept.affectedDescription.get(widget.langCode)
                        : widget.concept.healthyDescription.get(widget.langCode),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _showAffected ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
