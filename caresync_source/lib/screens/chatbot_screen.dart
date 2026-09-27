import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  List<Message> messages = [
    Message(
      text: "Hello! I'm your CareSync AI Assistant. I can help with BP, TB, Breast Cancer & lifestyle advice. How can I help you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isTyping = false;

  /// 🔥 PRODUCTION API CALL
  Future<String> getBotResponseFromBackend(String input) async {
    try {
      final response = await http.post(
        // Senior Fix: Added /chatbot prefix to match registered route
        Uri.parse("http://10.0.2.2:5000/chatbot/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": input}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["response"];
      } else {
        return "I'm having trouble connecting to the medical engine. Please try again later.";
      }
    } catch (e) {
      return "⚠️ Connectivity issue. Ensure the CareSync server is running.";
    }
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add(Message(text: text, isUser: true, timestamp: DateTime.now()));
      isTyping = true;
    });

    controller.clear();
    scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () async {
      String reply = await getBotResponseFromBackend(text);
      if (mounted) {
        setState(() {
          messages.add(Message(text: reply, isUser: false, timestamp: DateTime.now()));
          isTyping = false;
        });
        scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          /// Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple, Colors.pink]),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CareSync AI", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Specialized Health Assistant", style: TextStyle(color: Colors.white70, fontSize: 12))
                    ],
                  ),
                ),
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.psychology, color: Colors.purple),
                )
              ],
            ),
          ),

          /// Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && isTyping) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text("Typing..."))),
                  );
                }
                final msg = messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.blue.shade600 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                    ),
                    child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87, fontSize: 15)),
                  ),
                );
              },
            ),
          ),

          /// Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Ask about BP, TB, lifestyle...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      filled: true, fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: sendMessage,
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: () => sendMessage(controller.text),
                  mini: true, backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
