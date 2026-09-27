import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/health_explorer_model.dart';
import '../../data/health_explorer_data.dart';
import '../../widgets/health_explorer/interactive_body_canvas.dart';
import '../../services/api_service.dart';
import 'organ_hub_screen.dart';
import 'condition_detail_screen.dart';

class HealthExplorerScreen extends StatefulWidget {
  final String? targetUid;
  const HealthExplorerScreen({super.key, this.targetUid});

  @override
  State<HealthExplorerScreen> createState() => _HealthExplorerScreenState();
}

class _HealthExplorerScreenState extends State<HealthExplorerScreen> {
  String _langCode = 'en'; // 'en' or 'hi'
  bool _largeText = false;
  bool _isBackView = false;
  bool _isListView = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<String> _focusOrganIds = [];

  @override
  void initState() {
    super.initState();
    _loadUserFocusData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserFocusData() async {
    try {
      final profile = await ApiService.getProfile(targetUid: widget.targetUid);
      final bpLogs = await ApiService.getBPHistory(targetUid: widget.targetUid);
      final sugarLogs = await ApiService.getSugarHistory(targetUid: widget.targetUid);

      final List<String> focus = [];

      if (profile != null) {
        if (profile['has_bp'] == 1 || profile['has_bp'] == true || bpLogs.isNotEmpty) {
          focus.add('heart');
        }
        if (profile['has_tb'] == 1 || profile['has_tb'] == true) {
          focus.add('lungs');
        }
        if (sugarLogs.isNotEmpty) {
          focus.add('pancreas');
        }
      }

      if (mounted) {
        setState(() {
          _focusOrganIds = focus;
        });
      }
    } catch (_) {}
  }

  void _navigateToOrgan(BodyOrgan organ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganHubScreen(
          organ: organ,
          langCode: _langCode,
          focusOrganIds: _focusOrganIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHi = _langCode == 'hi';
    final searchResults = _searchQuery.isEmpty ? <HealthCondition>[] : HealthExplorerData.search(_searchQuery, _langCode);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHi ? "शरीर एवं स्वास्थ्य अन्वेषक" : "Health Explorer",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              isHi ? "मानव शरीर और बीमारियों की सरल जानकारी" : "Interactive Body & Health Lab",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
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

          // Bilingual Language Toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: InkWell(
              onTap: () {
                setState(() => _langCode = _langCode == 'en' ? 'hi' : 'en');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _langCode == 'en' ? "हिंदी" : "English",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: isHi ? "अंग, बीमारी या लक्षण खोजें..." : "Search organs, symptoms, or conditions...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),

            // Search Results Dropdown (if searching)
            if (_searchQuery.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  isHi ? "खोज परिणाम (${searchResults.length})" : "Search Results (${searchResults.length})",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
              if (searchResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      isHi ? "कोई परिणाम नहीं मिला।" : "No health topics matched your search.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...searchResults.map((cond) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: Text(cond.icon, style: const TextStyle(fontSize: 24)),
                      title: Text(cond.name.get(_langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConditionDetailScreen(
                              condition: cond,
                              langCode: _langCode,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              const SizedBox(height: 20),
            ],

            // If not searching, display Main Body Explorer
            if (_searchQuery.isEmpty) ...[
              // 2. "Your Health Focus" Carousel (Personalized Banner)
              if (_focusOrganIds.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFCA8A04), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        isHi ? "आपके स्वास्थ्य मुख्य बिंदु (Health Focus)" : "Your Health Focus Areas",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _focusOrganIds.map((organId) {
                      final organ = HealthExplorerData.getOrganById(organId);
                      if (organ == null) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ActionChip(
                          avatar: Text(organ.emoji, style: const TextStyle(fontSize: 16)),
                          label: Text(
                            "${organ.name.get(_langCode)} ⭐",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFF854D0E),
                            ),
                          ),
                          backgroundColor: const Color(0xFFFEF9C3),
                          side: const BorderSide(color: Color(0xFFFACC15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onPressed: () => _navigateToOrgan(organ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 3. View Mode Switches (Body vs List & Front vs Back)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Body vs List Toggle
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isListView = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: !_isListView ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isListView ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.accessibility_new, size: 14, color: !_isListView ? const Color(0xFF2563EB) : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    isHi ? "शरीर नक्शा" : "Body Map",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !_isListView ? const Color(0xFF2563EB) : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isListView = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isListView ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isListView ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.list_alt, size: 14, color: _isListView ? const Color(0xFF2563EB) : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    isHi ? "सूची" : "List",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isListView ? const Color(0xFF2563EB) : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Front / Back View Switch (only in Body View)
                    if (!_isListView)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.flip, size: 14),
                        label: Text(
                          _isBackView ? (isHi ? "सामने देखें" : "Front View") : (isHi ? "पीठ देखें" : "Back View"),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => setState(() => _isBackView = !_isBackView),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. MAIN DISPLAY: Interactive Body OR List View
              if (!_isListView) ...[
                // Body Viewport Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 420,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: InteractiveBodyCanvas(
                      organs: HealthExplorerData.organs,
                      focusOrganIds: _focusOrganIds,
                      isBackView: _isBackView,
                      langCode: _langCode,
                      onOrganSelected: _navigateToOrgan,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Senior-Friendly Horizontal Quick Organ Carousel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    isHi ? "अंगों की सूची (टैप करके पढ़ें)" : "Tap an organ to explore:",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: HealthExplorerData.organs.length,
                    itemBuilder: (context, idx) {
                      final organ = HealthExplorerData.organs[idx];
                      final isFocus = _focusOrganIds.contains(organ.id);

                      return GestureDetector(
                        onTap: () => _navigateToOrgan(organ),
                        child: Container(
                          width: 86,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isFocus ? const Color(0xFFFACC15) : Colors.grey.shade200,
                              width: isFocus ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(organ.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                organ.name.get(_langCode),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isFocus ? const Color(0xFF854D0E) : Colors.grey.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // List View (All 10 Organs in a vertical stack)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: HealthExplorerData.organs.length,
                  itemBuilder: (context, idx) {
                    final organ = HealthExplorerData.organs[idx];
                    final isFocus = _focusOrganIds.contains(organ.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isFocus ? const Color(0xFFFACC15) : Colors.grey.shade200,
                          width: isFocus ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          child: Text(organ.emoji, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Row(
                          children: [
                            Text(organ.name.get(_langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (isFocus) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star, size: 14, color: Color(0xFFEAB308)),
                            ],
                          ],
                        ),
                        subtitle: Text(organ.systemName.get(_langCode), style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
                        onTap: () => _navigateToOrgan(organ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),

              // 5. Educational Disclaimer Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isHi
                            ? "स्वास्थ्य अन्वेषक केवल सामान्य शैक्षिक जागरूकता के लिए है। किसी भी बीमारी के निदान या उपचार के लिए हमेशा अपने डॉक्टर से सलाह लें।"
                            : "CareSync Health Explorer is strictly an educational tool. Always consult your healthcare provider for medical diagnosis and treatment decisions.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
