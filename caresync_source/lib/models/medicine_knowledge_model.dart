import 'health_explorer_model.dart';

class MedicineKnowledge {
  final String id;
  final String genericName;
  final List<String> brandNames;
  final BilingualText name;
  final BilingualText category;
  final String relatedOrganId;
  final BilingualText whatItIs;
  final BilingualText whyPrescribed;
  final BilingualText howItWorks;
  final BilingualText foodGuidance;
  final List<BilingualText> commonSideEffects;
  final List<BilingualText> commonPrecautions;
  final List<BilingualText> whenToContactDoctor;
  final String defaultDosage;
  final String icon;

  const MedicineKnowledge({
    required this.id,
    required this.genericName,
    required this.brandNames,
    required this.name,
    required this.category,
    required this.relatedOrganId,
    required this.whatItIs,
    required this.whyPrescribed,
    required this.howItWorks,
    required this.foodGuidance,
    required this.commonSideEffects,
    required this.commonPrecautions,
    required this.whenToContactDoctor,
    this.defaultDosage = '1 tablet',
    this.icon = '💊',
  });
}
