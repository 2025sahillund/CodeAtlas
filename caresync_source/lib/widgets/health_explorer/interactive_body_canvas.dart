import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/health_explorer_model.dart';

class InteractiveBodyCanvas extends StatefulWidget {
  final List<BodyOrgan> organs;
  final List<String> focusOrganIds;
  final bool isBackView;
  final String langCode;
  final Function(BodyOrgan) onOrganSelected;

  const InteractiveBodyCanvas({
    super.key,
    required this.organs,
    required this.focusOrganIds,
    required this.isBackView,
    required this.langCode,
    required this.onOrganSelected,
  });

  @override
  State<InteractiveBodyCanvas> createState() => _InteractiveBodyCanvasState();
}

class _InteractiveBodyCanvasState extends State<InteractiveBodyCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        final canvasHeight = constraints.maxHeight;

        // Filter organs visible on current view (front vs back)
        final visibleOrgans = widget.organs.where((organ) {
          if (widget.isBackView) {
            return organ.xPercentBack != null && organ.yPercentBack != null;
          } else {
            return true;
          }
        }).toList();

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Anatomical Silhouette Background
            CustomPaint(
              size: Size(canvasWidth, canvasHeight),
              painter: _SilhouettePainter(isBackView: widget.isBackView),
            ),

            // 2. Interactive Organ Hotspots
            ...visibleOrgans.map((organ) {
              final xProp = widget.isBackView ? (organ.xPercentBack ?? organ.xPercentFront) : organ.xPercentFront;
              final yProp = widget.isBackView ? (organ.yPercentBack ?? organ.yPercentFront) : organ.yPercentFront;

              final left = (xProp * canvasWidth) - 30;
              final top = (yProp * canvasHeight) - 30;
              final isFocus = widget.focusOrganIds.contains(organ.id);

              return Positioned(
                left: left.clamp(8.0, canvasWidth - 68.0),
                top: top.clamp(8.0, canvasHeight - 68.0),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = isFocus ? _pulseAnimation.value : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTap: () => widget.onOrganSelected(organ),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: isFocus ? const Color(0xFFEAB308) : const Color(0xFF2563EB),
                              width: isFocus ? 3.0 : 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isFocus ? const Color(0xFFEAB308) : const Color(0xFF2563EB))
                                    .withValues(alpha: isFocus ? 0.45 : 0.25),
                                blurRadius: isFocus ? 12 : 8,
                                spreadRadius: isFocus ? 2 : 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Text(
                                organ.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                              if (isFocus)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEAB308),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // 3. View Indicator Badge
            Positioned(
              bottom: 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isBackView ? Icons.flip_camera_android : Icons.person_outline,
                      size: 14,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isBackView
                          ? (widget.langCode == 'hi' ? "पीठ का दृश्य" : "Back View")
                          : (widget.langCode == 'hi' ? "सामने का दृश्य" : "Front View"),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  final bool isBackView;

  _SilhouettePainter({required this.isBackView});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Body glow
    final glowPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h * 0.35), w * 0.45, glowPaint);

    final fillPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Head
    final headCenter = Offset(w * 0.50, h * 0.11);
    final headRadius = w * 0.10;
    path.addOval(Rect.fromCircle(center: headCenter, radius: headRadius));

    // Neck & Torso Outline
    path.moveTo(w * 0.45, h * 0.17); // Left neck
    path.lineTo(w * 0.45, h * 0.20);
    path.quadraticBezierTo(w * 0.30, h * 0.22, w * 0.24, h * 0.28); // Left shoulder
    path.lineTo(w * 0.20, h * 0.48); // Left arm
    path.quadraticBezierTo(w * 0.18, h * 0.52, w * 0.22, h * 0.52); // Left hand
    path.lineTo(w * 0.28, h * 0.38); // Left inner arm
    path.lineTo(w * 0.34, h * 0.38); // Left chest
    path.quadraticBezierTo(w * 0.36, h * 0.50, w * 0.35, h * 0.60); // Left waist
    path.lineTo(w * 0.32, h * 0.88); // Left leg
    path.quadraticBezierTo(w * 0.32, h * 0.94, w * 0.38, h * 0.94); // Left foot
    path.lineTo(w * 0.46, h * 0.65); // Inseam crotch
    path.lineTo(w * 0.54, h * 0.65);
    path.lineTo(w * 0.62, h * 0.94); // Right foot
    path.quadraticBezierTo(w * 0.68, h * 0.94, w * 0.68, h * 0.88);
    path.lineTo(w * 0.65, h * 0.60); // Right waist
    path.quadraticBezierTo(w * 0.64, h * 0.50, w * 0.66, h * 0.38);
    path.lineTo(w * 0.72, h * 0.38); // Right inner arm
    path.lineTo(w * 0.78, h * 0.52); // Right hand
    path.quadraticBezierTo(w * 0.82, h * 0.52, w * 0.80, h * 0.48);
    path.lineTo(w * 0.76, h * 0.28); // Right shoulder
    path.quadraticBezierTo(w * 0.70, h * 0.22, w * 0.55, h * 0.20);
    path.lineTo(w * 0.55, h * 0.17); // Right neck
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Spine guideline if back view
    if (isBackView) {
      final spinePaint = Paint()
        ..color = const Color(0xFF64748B).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      
      final spinePath = Path();
      spinePath.moveTo(w * 0.50, h * 0.21);
      spinePath.lineTo(w * 0.50, h * 0.62);
      canvas.drawPath(spinePath, spinePaint);

      // Vertebrae dashes
      for (double y = h * 0.24; y <= h * 0.60; y += h * 0.04) {
        canvas.drawLine(Offset(w * 0.47, y), Offset(w * 0.53, y), spinePaint);
      }
    } else {
      // Clavicle & Rib hints for front view
      final ribPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(w * 0.40, h * 0.23), Offset(w * 0.48, h * 0.24), ribPaint);
      canvas.drawLine(Offset(w * 0.60, h * 0.23), Offset(w * 0.52, h * 0.24), ribPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) {
    return oldDelegate.isBackView != isBackView;
  }
}
