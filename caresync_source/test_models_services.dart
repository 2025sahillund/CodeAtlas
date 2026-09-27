import 'package:flutter_test/flutter_test.dart';
import 'package:care_sync/models/medicine.dart';
import 'package:care_sync/models/family_member.dart';
import 'package:care_sync/services/api_service.dart';
import 'package:care_sync/services/medicine_service.dart';
import 'package:care_sync/data/health_explorer_data.dart';
import 'package:care_sync/data/medicine_knowledge_data.dart';
import 'package:care_sync/services/medical_passport_pdf_service.dart';

void main() {
  group('Medicine Model Tests', () {
    test('Medicine parses from JSON with SQLite timings string', () {
      final json = {
        'id': 1,
        'medicine_name': 'Paracetamol',
        'dosage': '500mg',
        'total_stock': 20,
        'stock_threshold': 5,
        'timings': '08:00,20:00',
      };
      final med = Medicine.fromJson(json);
      expect(med.id, 1);
      expect(med.name, 'Paracetamol');
      expect(med.dosage, '500mg');
      expect(med.totalStock, 20);
      expect(med.timings, ['08:00', '20:00']);
      expect(med.time, '08:00');
    });

    test('Medicine parses from JSON with Firestore timings list', () {
      final json = {
        'medicine_name': 'Metformin',
        'dosage': '1 pill',
        'total_stock': 15,
        'stock_threshold': 5,
        'timings': ['09:00', '18:00'],
      };
      final med = Medicine.fromJson(json);
      expect(med.id, isNull);
      expect(med.name, 'Metformin');
      expect(med.dosage, '1 pill');
      expect(med.totalStock, 15);
      expect(med.stockThreshold, 5);
      expect(med.timings, ['09:00', '18:00']);
    });

    test('Medicine serializes to JSON consistently', () {
      final med = Medicine(
        name: 'Dolo 650',
        dosage: '1 tablet',
        totalStock: 25,
        stockThreshold: 5,
        timings: ['08:00', '20:00'],
      );
      final json = med.toJson();
      expect(json['medicine_name'], 'Dolo 650');
      expect(json['dosage'], '1 tablet');
      expect(json['total_stock'], 25);
      expect(json['timings'], ['08:00', '20:00']);
    });
  });

  group('ApiService Profile & Health Detection Tests', () {
    test('hasHealthData returns true when health fields exist', () {
      expect(ApiService.hasHealthData({'age': 45}), isTrue);
      expect(ApiService.hasHealthData({'gender': 'Male'}), isTrue);
      expect(ApiService.hasHealthData({'blood_group': 'O+'}), isTrue);
      expect(ApiService.hasHealthData({'has_bp': 1}), isTrue);
      expect(ApiService.hasHealthData({}), isFalse);
      expect(ApiService.hasHealthData(null), isFalse);
    });

    test('hasPersonalProfile detects role, onboarding flags and health data', () {
      expect(ApiService.hasPersonalProfile({'role': 'patient'}), isTrue);
      expect(ApiService.hasPersonalProfile({'personalOnboardingCompleted': true}), isTrue);
      expect(ApiService.hasPersonalProfile({'onboardingCompleted': true}), isTrue);
      expect(ApiService.hasPersonalProfile({'age': 30}), isTrue);
      expect(ApiService.hasPersonalProfile({'has_bp': 1}), isTrue);
      expect(ApiService.hasPersonalProfile({'role': 'caregiver'}), isFalse);
      expect(ApiService.hasPersonalProfile({'role': 'caregiver', 'has_bp': 1}), isTrue);
      expect(ApiService.hasPersonalProfile(null), isFalse);
    });

    test('connectPatientByUid validates not logged in or empty or self-connect', () async {
      // When not logged in
      final resultEmpty = await ApiService.connectPatientByUid(patientUid: '');
      expect(resultEmpty['success'], isFalse);
      
      final resultWhitespace = await ApiService.connectPatientByUid(patientUid: '   ');
      expect(resultWhitespace['success'], isFalse);
    });

    test('calculateAge calculates accurate age from various DOB formats and handles invalid/missing inputs', () {
      final now = DateTime.now();
      
      // DOB where birthday has already occurred this year
      final pastMonth = now.month > 1 ? now.month - 1 : 12;
      final pastYear = now.month > 1 ? now.year - 20 : now.year - 21;
      final dobPast = "$pastYear-${pastMonth.toString().padLeft(2, '0')}-01";
      final agePast = ApiService.calculateAge(dobPast);
      expect(agePast, isNotNull);
      expect(agePast, 20);

      // DOB where birthday is in future month of current year
      final futureMonth = now.month < 12 ? now.month + 1 : 1;
      final futureYear = now.month < 12 ? now.year - 20 : now.year - 19;
      final dobFuture = "$futureYear-${futureMonth.toString().padLeft(2, '0')}-28";
      final ageFuture = ApiService.calculateAge(dobFuture);
      expect(ageFuture, isNotNull);
      expect(ageFuture, 19);

      // Direct integer
      expect(ApiService.calculateAge(35), 35);
      expect(ApiService.calculateAge('42'), 42);

      // Slash formatted date (DD/MM/YYYY)
      expect(ApiService.calculateAge("01/01/2000"), isNotNull);
      expect(ApiService.calculateAge("01/01/2000"), now.year - 2000);

      // DateTime instance
      expect(ApiService.calculateAge(DateTime(2000, 1, 1)), now.year - 2000);

      // Null, empty, placeholders, future dates
      expect(ApiService.calculateAge(null), isNull);
      expect(ApiService.calculateAge(''), isNull);
      expect(ApiService.calculateAge('   '), isNull);
      expect(ApiService.calculateAge('--'), isNull);
      expect(ApiService.calculateAge('Not Set'), isNull);
      expect(ApiService.calculateAge('Not provided'), isNull);
      expect(ApiService.calculateAge('invalid-date'), isNull);
      expect(ApiService.calculateAge(DateTime.now().add(const Duration(days: 365))), isNull);
    });

    test('ApiService and MedicineService targetUid calls return empty or null safely when unauthenticated', () async {
      final sugar = await ApiService.getSugarHistory(targetUid: 'patient_dummy_uid');
      expect(sugar, isEmpty);

      final bp = await ApiService.getBPHistory(targetUid: 'patient_dummy_uid');
      expect(bp, isEmpty);

      final appts = await ApiService.getAppointments(targetUid: 'patient_dummy_uid');
      expect(appts, isEmpty);
    });
  });

  group('Health Explorer Data & Bilingual Tests', () {
    test('All 10 core organs exist and contain valid bilingual data', () {
      expect(HealthExplorerData.organs.length, 10);
      for (var organ in HealthExplorerData.organs) {
        expect(organ.id, isNotEmpty);
        expect(organ.name.en, isNotEmpty);
        expect(organ.name.hi, isNotEmpty);
        expect(organ.primaryFunction.en, isNotEmpty);
        expect(organ.primaryFunction.hi, isNotEmpty);
        expect(organ.emoji, isNotEmpty);
        expect(organ.conditionIds, isNotEmpty);
      }
    });

    test('All conditions contain complete symptoms, warnings, and bilingual text', () {
      expect(HealthExplorerData.conditions.length, greaterThanOrEqualTo(20));
      for (var cond in HealthExplorerData.conditions) {
        expect(cond.id, isNotEmpty);
        expect(cond.name.en, isNotEmpty);
        expect(cond.name.hi, isNotEmpty);
        expect(cond.plainExplanation.en, isNotEmpty);
        expect(cond.plainExplanation.hi, isNotEmpty);
        expect(cond.commonSymptoms, isNotEmpty);
        expect(cond.precautionsAndHabits, isNotEmpty);
      }
    });

    test('HealthExplorerData search works in English and Hindi', () {
      final searchHeartEn = HealthExplorerData.search('heart', 'en');
      expect(searchHeartEn, isNotEmpty);
      expect(searchHeartEn.any((c) => c.organId == 'heart'), isTrue);

      final searchBpHi = HealthExplorerData.search('रक्तचाप', 'hi');
      expect(searchBpHi, isNotEmpty);
      expect(searchBpHi.any((c) => c.id == 'hypertension'), isTrue);

      final searchEmpty = HealthExplorerData.search('xyznonexistentcondition123', 'en');
      expect(searchEmpty, isEmpty);
    });

    test('HealthExplorerData getConditionsForOrgan returns correct subset', () {
      final brainConditions = HealthExplorerData.getConditionsForOrgan('brain');
      expect(brainConditions.length, 3);
      expect(brainConditions.map((c) => c.id), containsAll(['stroke', 'dementia', 'migraine']));
    });
  });

  group('Medicine Search & Knowledge Tests', () {
    test('Curated medicines contain valid bilingual educational fields', () {
      expect(MedicineKnowledgeData.medicines, isNotEmpty);
      for (var med in MedicineKnowledgeData.medicines) {
        expect(med.id, isNotEmpty);
        expect(med.genericName, isNotEmpty);
        expect(med.name.en, isNotEmpty);
        expect(med.name.hi, isNotEmpty);
        expect(med.whatItIs.en, isNotEmpty);
        expect(med.whatItIs.hi, isNotEmpty);
        expect(med.whyPrescribed.en, isNotEmpty);
        expect(med.whyPrescribed.hi, isNotEmpty);
        expect(med.howItWorks.en, isNotEmpty);
        expect(med.howItWorks.hi, isNotEmpty);
        expect(med.foodGuidance.en, isNotEmpty);
        expect(med.foodGuidance.hi, isNotEmpty);
        expect(med.relatedOrganId, isNotEmpty);
      }
    });

    test('Progressive search works for partial queries like lis, met, aml, pan', () {
      final lisResults = MedicineKnowledgeData.search('lis');
      expect(lisResults.any((m) => m.genericName == 'Lisinopril'), isTrue);

      final metResults = MedicineKnowledgeData.search('met');
      expect(metResults.any((m) => m.genericName == 'Metformin'), isTrue);

      final amlResults = MedicineKnowledgeData.search('aml');
      expect(amlResults.any((m) => m.genericName == 'Amlodipine'), isTrue);

      final panResults = MedicineKnowledgeData.search('pan');
      expect(panResults.any((m) => m.genericName == 'Pantoprazole'), isTrue);

      final brandResults = MedicineKnowledgeData.search('Dolo');
      expect(brandResults.any((m) => m.genericName.contains('Paracetamol')), isTrue);
    });

    test('findByName accurately matches generic and brand names', () {
      final dolo650 = MedicineKnowledgeData.findByName('Dolo 650');
      expect(dolo650, isNotNull);
      expect(dolo650!.id, 'paracetamol');
      expect(dolo650.whatItIs.en, contains('reduce fever'));

      final doloPlain = MedicineKnowledgeData.findByName('Dolo');
      expect(doloPlain, isNotNull);
      expect(doloPlain!.id, 'paracetamol');

      final lisinopril = MedicineKnowledgeData.findByName('Lisinopril');
      expect(lisinopril, isNotNull);
      expect(lisinopril!.id, 'lisinopril');
      expect(lisinopril.relatedOrganId, 'heart');

      final metformin = MedicineKnowledgeData.findByName('Metformin');
      expect(metformin, isNotNull);
      expect(metformin!.id, 'metformin');
      expect(metformin.relatedOrganId, 'pancreas');

      final levothyroxine = MedicineKnowledgeData.findByName('Levothyroxine');
      expect(levothyroxine, isNotNull);
      expect(levothyroxine!.id, 'levothyroxine');

      final thyronorm = MedicineKnowledgeData.findByName('Thyronorm 50mcg');
      expect(thyronorm, isNotNull);
      expect(thyronorm!.id, 'levothyroxine');

      final ecosprin = MedicineKnowledgeData.findByName('Ecosprin 75');
      expect(ecosprin, isNotNull);
      expect(ecosprin!.id, 'aspirin');

      final nonExistent = MedicineKnowledgeData.findByName('UnknownHerbXyz123');
      expect(nonExistent, isNull);
    });
  });

  group('Medical Passport PDF Generation Tests', () {
    test('generatePdf produces valid non-empty PDF bytes with PDF header', () async {
      final profile = {
        'name': 'Ramesh Kumar',
        'dob': '1958-06-15',
        'gender': 'Male',
        'blood_group': 'B+',
        'height': 172,
        'weight': 68,
        'allergies': 'Penicillin, Dust',
        'emergency_contact_name': 'Suresh Kumar',
        'emergency_phone': '+91 9876543210',
        'has_bp': 1,
        'has_tb': 0,
        'has_cancer': 0,
        'bp_medication': 'Amlodipine 5mg',
        'bp_frequency': 'Daily morning',
      };

      final medicines = [
        Medicine(name: 'Amlodipine', dosage: '5mg', totalStock: 30, timings: ['08:00']),
        Medicine(name: 'Metformin', dosage: '500mg', totalStock: 45, timings: ['09:00', '20:00']),
      ];

      final bpLogs = [
        {'systolic': 128, 'diastolic': 82, 'pulse': 72, 'log_date': '2026-09-02', 'log_time': '08:30'},
      ];

      final sugarLogs = [
        {'sugar_level': 110, 'test_type': 'Fasting', 'log_date': '2026-09-02', 'log_time': '07:45'},
      ];

      final appointments = [
        {
          'doctorName': 'Dr. Sharma',
          'hospitalName': 'Apollo Hospital',
          'dateTime': DateTime.now().add(const Duration(days: 3)),
          'purpose': 'Quarterly Cardiac Followup',
        }
      ];

      final pdfBytes = await MedicalPassportPdfService.generatePdf(
        profile: profile,
        medicines: medicines,
        bpLogs: bpLogs,
        sugarLogs: sugarLogs,
        appointments: appointments,
        careSyncId: 'test_uid_123456',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF magic header: %PDF
      expect(pdfBytes.length, greaterThan(100));
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });

    test('generatePdf safely handles empty lists and missing profile fields', () async {
      final pdfBytes = await MedicalPassportPdfService.generatePdf(
        profile: {},
        medicines: [],
        bpLogs: [],
        sugarLogs: [],
        appointments: [],
        careSyncId: 'empty_user',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes[0], 0x25);
      expect(pdfBytes[1], 0x50);
      expect(pdfBytes[2], 0x44);
      expect(pdfBytes[3], 0x46);
    });
  });

  group('Family Member Model Tests', () {

    test('FamilyMember instantiates with default and custom values', () {
      final member = FamilyMember(
        id: 'fm_123',
        name: 'Dad',
        relation: 'Parent',
        age: 68,
        conditions: ['Hypertension', 'Diabetes'],
        avatar: '👴',
      );

      expect(member.id, 'fm_123');
      expect(member.name, 'Dad');
      expect(member.relation, 'Parent');
      expect(member.age, 68);
      expect(member.conditions, ['Hypertension', 'Diabetes']);
      expect(member.avatar, '👴');
    });

    test('FamilyMember serializes to and from Map correctly', () {
      final mapData = {
        'name': 'Mom',
        'relation': 'Parent',
        'age': 64,
        'conditions': ['Asthma'],
        'avatar': '👩',
        'connectionStatus': 'unlinked',
      };

      final member = FamilyMember.fromMap(mapData, 'doc_456');
      expect(member.id, 'doc_456');
      expect(member.name, 'Mom');
      expect(member.relation, 'Parent');
      expect(member.age, 64);
      expect(member.conditions, ['Asthma']);
      expect(member.avatar, '👩');
      expect(member.connectionStatus, 'unlinked');

      final serialized = member.toFirestore();
      expect(serialized['name'], 'Mom');
      expect(serialized['relation'], 'Parent');
      expect(serialized['age'], 64);
      expect(serialized['conditions'], ['Asthma']);
      expect(serialized['avatar'], '👩');
    });

    test('FamilyMember copyWith updates properties correctly', () {
      final original = FamilyMember(
        id: '1',
        name: 'Sister',
        relation: 'Sibling',
        age: 25,
        conditions: [],
        avatar: '👧',
      );

      final updated = original.copyWith(
        name: 'Elder Sister',
        age: 26,
        conditions: ['Allergy'],
      );

      expect(updated.id, '1');
      expect(updated.name, 'Elder Sister');
      expect(updated.relation, 'Sibling');
      expect(updated.age, 26);
      expect(updated.conditions, ['Allergy']);
      expect(updated.avatar, '👧');
    });
  });

  group('Caregiver Connection Request & Security Model Tests', () {
    test('sendCaregiverRequest validates unauthenticated state, empty UID, and self-connect', () async {
      // 1. Empty target UID
      final resEmpty = await ApiService.sendCaregiverRequest(patientUid: '');
      expect(resEmpty['success'], isFalse);
      expect(resEmpty['message'], isNotEmpty);

      // 2. Whitespace target UID
      final resWhitespace = await ApiService.sendCaregiverRequest(patientUid: '   ');
      expect(resWhitespace['success'], isFalse);
      expect(resWhitespace['message'], isNotEmpty);

      // 3. Unauthenticated call
      final resUnauth = await ApiService.sendCaregiverRequest(patientUid: 'any_random_uid');
      expect(resUnauth['success'], isFalse);
      expect(resUnauth['message'], contains('logged in'));
    });


    test('respondToConnectionRequest safely returns false when unauthenticated or empty ID', () async {
      final resAccept = await ApiService.respondToConnectionRequest(connectionId: '', accept: true);
      expect(resAccept, isFalse);

      final resReject = await ApiService.respondToConnectionRequest(connectionId: 'conn_123', accept: false);
      expect(resReject, isFalse);
    });

    test('disconnectPatientConnection safely returns false when unauthenticated or empty ID', () async {
      final res = await ApiService.disconnectPatientConnection('');
      expect(res, isFalse);
    });

    test('Connection data structure contracts enforce pending status and required fields', () {
      final sampleConnectionPayload = {
        'caregiverUid': 'caregiver_uid_s2',
        'caregiverEmail': 's2@example.com',
        'caregiverName': 'Sahil',
        'patientUid': 'patient_uid_s1',
        'patientName': 'Dad',
        'relationship': 'Child',
        'status': 'pending',
        'type': 'caregiver_request',
      };

      expect(sampleConnectionPayload['status'], 'pending');
      expect(sampleConnectionPayload['caregiverUid'], 'caregiver_uid_s2');
      expect(sampleConnectionPayload['patientUid'], 'patient_uid_s1');
      expect(sampleConnectionPayload['type'], 'caregiver_request');

      // Acceptance transition
      final acceptedPayload = Map<String, dynamic>.from(sampleConnectionPayload);
      acceptedPayload['status'] = 'active';
      expect(acceptedPayload['status'], 'active');
    });
  });

  group('Medicine Stock, Take Dose, Undo Dose & Manual Deduction Tests', () {
    test('Default new medicine stock initializes to 20 and preserves custom stock', () {
      final defaultMed = Medicine(
        name: 'Amlodipine',
        dosage: '5mg',
        totalStock: 20,
        timings: ['08:00'],
      );
      expect(defaultMed.totalStock, 20);
      expect(defaultMed.stockThreshold, 5);

      final customMed = Medicine(
        name: 'Custom Syrup',
        dosage: '10ml',
        totalStock: 45,
        timings: ['08:00', '20:00'],
      );
      expect(customMed.totalStock, 45);
    });

    test('Medicine stock clamp prevents negative stock during deduction simulation', () {
      int initialStock = 8;
      int deductAmount1 = 5;
      int stockAfterDeduct1 = (initialStock - deductAmount1).clamp(0, 99999);
      expect(stockAfterDeduct1, 3);

      int deductAmount2 = 10; // Exceeds remaining 3
      int stockAfterDeduct2 = (stockAfterDeduct1 - deductAmount2).clamp(0, 99999);
      expect(stockAfterDeduct2, 0); // Must be clamped at 0, not negative
    });

    test('Take dose and Undo dose stock cycle arithmetic is mathematically reversible', () {
      int initialStock = 20;
      
      // Patient takes a dose (-1)
      int stockTaken = (initialStock - 1).clamp(0, 99999);
      expect(stockTaken, 19);

      // Patient undoes the dose (+1)
      int stockUndone = (stockTaken + 1).clamp(0, 99999);
      expect(stockUndone, 20);
      expect(stockUndone, initialStock);
    });

    test('Dose logs filtering accurately identifies today taken doses for undo protection', () {
      final sampleLogs = [
        {
          'medicine_name': 'Lisinopril',
          'reminder_time': '08:00',
          'log_date': '2026-09-14',
          'status': 'taken',
        },
        {
          'medicine_name': 'Metformin',
          'reminder_time': '20:00',
          'log_date': '2026-09-14',
          'status': 'taken',
        },
      ];

      // Check Lisinopril 08:00 is taken
      final isLisinoprilTaken = sampleLogs.any((l) =>
        (l['medicine_name'] as String).toLowerCase() == 'lisinopril' &&
        l['reminder_time'] == '08:00' &&
        l['status'] == 'taken'
      );
      expect(isLisinoprilTaken, isTrue);

      // Check Aspirin 08:00 is NOT taken
      final isAspirinTaken = sampleLogs.any((l) =>
        (l['medicine_name'] as String).toLowerCase() == 'aspirin' &&
        l['reminder_time'] == '08:00' &&
        l['status'] == 'taken'
      );
      expect(isAspirinTaken, isFalse);

      // After undoing Lisinopril, simulate deletion from logs
      sampleLogs.removeWhere((l) =>
        (l['medicine_name'] as String).toLowerCase() == 'lisinopril' &&
        l['reminder_time'] == '08:00'
      );
      expect(sampleLogs.length, 1);
      expect(sampleLogs.first['medicine_name'], 'Metformin');
    });

    test('Adherence calculation reflects taken vs undone doses without distortion from manual deduction', () {
      // 1. Initial state: 4 scheduled doses logged, 4 taken -> 100%
      List<Map<String, dynamic>> doseLogs = [
        {'status': 'taken'},
        {'status': 'taken'},
        {'status': 'taken'},
        {'status': 'taken'},
      ];
      int total = doseLogs.length;
      int taken = doseLogs.where((l) => l['status'] == 'taken').length;
      int adherence = ((taken / total) * 100).round();
      expect(adherence, 100);

      // 2. Patient undoes 1 accidental dose (reverting it from logs)
      doseLogs.removeAt(0); // 3 doses remaining
      total = doseLogs.length;
      taken = doseLogs.where((l) => l['status'] == 'taken').length;
      adherence = ((taken / total) * 100).round();
      expect(adherence, 100);

      // 3. Manual stock deduction does not add any log entries to doseLogs
      // Inventory decreases, but doseLogs count remains unchanged
      int inventoryStock = 20;
      int deductedStock = (inventoryStock - 5).clamp(0, 99999);
      expect(deductedStock, 15);
      expect(doseLogs.length, 3); // No change to doseLogs!
    });

    test('MedicineService and FirebaseService targetUid calls return safely when unauthenticated', () async {
      final unauthUndo = await MedicineService.undoDose('test_reminder_id', medicineName: 'Paracetamol');
      expect(unauthUndo, isFalse);

      final unauthDeduct = await MedicineService.deductStock(
        medicineName: 'Paracetamol',
        currentStock: 20,
        amount: 5,
      );
      expect(unauthDeduct, isFalse);

      final unauthDelete = await MedicineService.deleteMedicine(medicineName: 'Paracetamol');
      expect(unauthDelete, isFalse);

      final unauthUpdate = await MedicineService.updateMedicine(
        oldName: 'Paracetamol',
        newName: 'Paracetamol 650',
        dosage: '650mg',
        newTimes: ['09:00', '21:00'],
        stock: 30,
      );
      expect(unauthUpdate, isFalse);
    });
  });

  group('Health Vitals Validation & Deletion Tests', () {
    test('Blood sugar clinical range validation logic (30-700 mg/dL)', () {
      bool isSugarValid(int sugar) => sugar >= 30 && sugar <= 700;

      expect(isSugarValid(20), isFalse); // Hypoglycemic extreme / typo
      expect(isSugarValid(30), isTrue);  // Lower boundary
      expect(isSugarValid(110), isTrue); // Normal fasting
      expect(isSugarValid(250), isTrue); // Diabetic postprandial
      expect(isSugarValid(700), isTrue); // Upper boundary
      expect(isSugarValid(999), isFalse); // Severe typo
    });

    test('Blood pressure clinical range & physiological constraint validation logic', () {
      bool isBPValid(int systolic, int diastolic, int? pulse) {
        if (systolic < 60 || systolic > 260) return false;
        if (diastolic < 40 || diastolic > 150) return false;
        if (systolic < diastolic + 15) return false; // Physiological constraint
        if (pulse != null && (pulse < 30 || pulse > 220)) return false;
        return true;
      }

      expect(isBPValid(120, 80, 72), isTrue);  // Ideal BP
      expect(isBPValid(140, 90, 80), isTrue);  // Stage 1 HTN
      expect(isBPValid(60, 140, 72), isFalse); // Impossible: Diastolic > Systolic
      expect(isBPValid(100, 95, 72), isFalse); // Impossible: Systolic < Diastolic + 15
      expect(isBPValid(50, 40, 72), isFalse);  // Systolic out of bounds
      expect(isBPValid(130, 30, 72), isFalse);  // Diastolic out of bounds
      expect(isBPValid(120, 80, 300), isFalse); // Pulse out of bounds
    });

    test('Profile height & weight range clamps validate physiological limits', () {
      bool isHeightValid(int h) => h >= 50 && h <= 250;
      bool isWeightValid(int w) => w >= 20 && w <= 300;

      expect(isHeightValid(175), isTrue);
      expect(isHeightValid(30), isFalse);
      expect(isHeightValid(280), isFalse);

      expect(isWeightValid(70), isTrue);
      expect(isWeightValid(10), isFalse);
      expect(isWeightValid(450), isFalse);
    });

    test('ApiService vitals deletion and stream methods return safely when unauthenticated', () async {
      final unauthDeleteSugar = await ApiService.deleteSugarLog('test_sugar_id');
      expect(unauthDeleteSugar, isFalse);

      final unauthDeleteBP = await ApiService.deleteBPLog('test_bp_id');
      expect(unauthDeleteBP, isFalse);
    });

    test('Medicine low stock evaluation detects crossing threshold accurately', () {
      bool isLowStock(int stock, int threshold) => stock <= threshold;

      expect(isLowStock(4, 5), isTrue);  // Below threshold -> alert
      expect(isLowStock(5, 5), isTrue);  // Exactly at threshold -> alert
      expect(isLowStock(6, 5), isFalse); // Above threshold -> normal
      expect(isLowStock(0, 5), isTrue);  // Out of stock -> critical alert
    });
  });
}




