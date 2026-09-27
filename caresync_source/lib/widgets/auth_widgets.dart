import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WavePainter extends CustomPainter {
  final Color color1;
  final Color color2;

  WavePainter(this.color1, this.color2);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final path1 = Path();
    path1.moveTo(0, size.height * 0.8);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.5, size.width * 0.5, size.height * 0.8);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 1.1, size.width, size.height * 0.8);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()..color = color2;
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width * 0.8, size.height * 0.9);
    path2.quadraticBezierTo(size.width * 0.9, size.height * 1, size.width, size.height * 0.85);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget buildAuthTextField({
  required BuildContext context,
  required String label,
  required IconData icon,
  bool isPassword = false,
  bool? showPassword,
  VoidCallback? onTogglePassword,
  TextInputType? keyboardType,
  required Function(String) onChanged,
  required String? Function(String?) validator,
}) {
  final theme = Theme.of(context);
  return TextFormField(
    obscureText: isPassword && !(showPassword ?? false),
    onChanged: onChanged,
    validator: validator,
    keyboardType: keyboardType,
    style: GoogleFonts.poppins(fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: theme.hintColor, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                (showPassword ?? false) ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: theme.hintColor,
                size: 20,
              ),
              onPressed: onTogglePassword,
            )
          : null,
      filled: true,
      fillColor: theme.brightness == Brightness.light ? Colors.grey[50] : Colors.white10,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
  );
}
