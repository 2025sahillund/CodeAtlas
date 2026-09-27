class HealthProfile {
  String age;
  String gender;
  String height;
  String weight;
  String activityLevel;
  bool smokes;
  bool alcohol;
  double sleepHours;
  String bloodGroup;
  String allergies;
  String emergencyName;
  String emergencyPhone;
  List<String> conditions;

  HealthProfile({
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.smokes,
    required this.alcohol,
    required this.sleepHours,
    required this.bloodGroup,
    required this.allergies,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.conditions,
  });
}