import 'package:flutter/material.dart';
import '../../services/tts_service.dart';

class AudioReadButton extends StatelessWidget {
  final String textToRead;
  final String langCode;

  const AudioReadButton({
    super.key,
    required this.textToRead,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return ElevatedButton.icon(
          onPressed: () {
            TtsService.speak(text: textToRead, langCode: langCode);
          },
          icon: Icon(
            isPlaying ? Icons.stop_circle : Icons.volume_up_rounded,
            size: 22,
            color: isPlaying ? Colors.white : const Color(0xFF2563EB),
          ),
          label: Text(
            isPlaying
                ? (langCode == 'hi' ? "रोकें" : "Stop")
                : (langCode == 'hi' ? "सुनें 🔊" : "Listen 🔊"),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isPlaying ? Colors.white : const Color(0xFF2563EB),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isPlaying ? Colors.red.shade600 : const Color(0xFFEFF6FF),
            elevation: isPlaying ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isPlaying ? Colors.red : const Color(0xFFBFDBFE),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        );
      },
    );
  }
}
