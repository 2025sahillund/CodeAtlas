class BilingualText {
  final String en;
  final String hi;

  const BilingualText({
    required this.en,
    required this.hi,
  });

  String get(String langCode) {
    return langCode == 'hi' ? hi : en;
  }
}

enum BodyRegion {
  head,
  chest,
  abdomen,
  limbs,
  back,
  wholeBody,
}

class VisualConcept {
  final BilingualText healthyTitle;
  final BilingualText healthyDescription;
  final BilingualText affectedTitle;
  final BilingualText affectedDescription;
  final String healthyIcon;
  final String affectedIcon;

  const VisualConcept({
    required this.healthyTitle,
    required this.healthyDescription,
    required this.affectedTitle,
    required this.affectedDescription,
    this.healthyIcon = '🟢',
    this.affectedIcon = '🔴',
  });
}

class MythFactItem {
  final BilingualText myth;
  final BilingualText fact;

  const MythFactItem({
    required this.myth,
    required this.fact,
  });
}

class HealthCondition {
  final String id;
  final BilingualText name;
  final String organId;
  final BilingualText plainExplanation;
  final List<BilingualText> commonSymptoms;
  final List<BilingualText> redFlagWarnings;
  final List<BilingualText> precautionsAndHabits;
  final List<BilingualText> questionsForDoctor;
  final VisualConcept? visualConcept;
  final List<MythFactItem>? mythsAndFacts;
  final String severityCategory; // 'common', 'chronic', 'emergency_aware'
  final String icon;

  const HealthCondition({
    required this.id,
    required this.name,
    required this.organId,
    required this.plainExplanation,
    required this.commonSymptoms,
    required this.redFlagWarnings,
    required this.precautionsAndHabits,
    required this.questionsForDoctor,
    this.visualConcept,
    this.mythsAndFacts,
    this.severityCategory = 'common',
    this.icon = '🩺',
  });
}

class BodyOrgan {
  final String id;
  final BilingualText name;
  final BilingualText systemName;
  final BodyRegion region;
  final String icon;
  final String emoji;
  final double xPercentFront; // Proportional X (0.0 to 1.0) on front silhouette
  final double yPercentFront; // Proportional Y (0.0 to 1.0) on front silhouette
  final double? xPercentBack;  // Proportional X on back silhouette
  final double? yPercentBack;  // Proportional Y on back silhouette
  final BilingualText primaryFunction;
  final BilingualText easyMetaphor;
  final List<String> conditionIds;
  final VisualConcept? defaultVisualConcept;
  final String associatedProfileKey; // e.g. 'has_bp', 'has_tb', 'sugar_logs', etc.

  const BodyOrgan({
    required this.id,
    required this.name,
    required this.systemName,
    required this.region,
    required this.icon,
    required this.emoji,
    required this.xPercentFront,
    required this.yPercentFront,
    this.xPercentBack,
    this.yPercentBack,
    required this.primaryFunction,
    required this.easyMetaphor,
    required this.conditionIds,
    this.defaultVisualConcept,
    this.associatedProfileKey = '',
  });
}
