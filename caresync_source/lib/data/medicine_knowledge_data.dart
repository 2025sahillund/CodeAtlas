import '../models/health_explorer_model.dart';
import '../models/medicine_knowledge_model.dart';

class MedicineKnowledgeData {
  static const List<MedicineKnowledge> medicines = [
    // 1. PARACETAMOL / DOLO 650 / CROCIN
    MedicineKnowledge(
      id: 'paracetamol',
      genericName: 'Paracetamol (Acetaminophen)',
      brandNames: ['Dolo', 'Dolo 650', 'Dolo-650', 'Crocin', 'Calpol', 'Tylenol', 'Panadol', 'PCM', 'Pacimol', 'Febrex'],
      name: BilingualText(en: 'Paracetamol / Dolo 650', hi: 'पैरासिटामोल / डोलो 650 (Paracetamol)'),
      category: BilingualText(en: 'Pain & Fever Relief', hi: 'दर्द व बुखार की दवा'),
      relatedOrganId: 'bones',
      defaultDosage: '1 tablet (500mg or 650mg)',
      icon: '🌡️',
      whatItIs: BilingualText(
        en: 'The most common, trusted, and gentle medicine used worldwide to reduce fever, relieve headaches, body aches, and mild-to-moderate arthritis pain.',
        hi: 'बुखार कम करने, सिरदर्द, बदन दर्द और जोड़ों के हल्के दर्द से राहत पाने के लिए सबसे सुरक्षित और लोकप्रिय दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed by doctors for viral fever, post-vaccine soreness, seasonal flu body aches, knee joint discomfort, and dental pain.',
        hi: 'वायरल बुखार, मौसमी जुकाम में बदन टूटने, घुटनों के दर्द, सिरदर्द और दांत दर्द में आराम देने के लिए डॉक्टर द्वारा दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It blocks pain signaling messengers in the brain and resets the brain’s internal heat control center to gently bring elevated body temperature back to normal.',
        hi: 'यह दिमाग में दर्द के संकेत भेजने वाले संदेशवाहकों को रोकती है और दिमाग के तापमान नियंत्रण केंद्र को शांत करके बुखार कम करती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Can be taken safely with or without food. It is much gentler on the stomach lining than strong NSAID painkillers.',
        hi: 'इसे भोजन के पहले या बाद में लिया जा सकता है। यह अन्य तेज दर्द निवारक गोलियों की तुलना में पेट के लिए बहुत सुरक्षित है।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Extremely rare and gentle when taken within prescribed limits.', hi: 'सही खुराक में लेने पर आमतौर पर कोई दुष्प्रभाव नहीं होता।'),
        BilingualText(en: 'Very rarely, slight nausea or mild sweating as fever breaks.', hi: 'कभी-कभी बुखार उतरते समय हल्का पसीना आ सकता है।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Never exceed 4,000 mg (4 grams) in 24 hours to protect your liver.', hi: 'लिवर की सुरक्षा के लिए 24 घंटे में कुल 4 ग्राम से अधिक खुराक कभी न लें।'),
        BilingualText(en: 'Wait at least 4 to 6 hours between doses.', hi: 'दो खुराकों के बीच कम से कम 4 से 6 घंटे का अंतर रखें।'),
        BilingualText(en: 'Check other cough/cold syrups to ensure they don’t also contain paracetamol to avoid accidental double dosing.', hi: 'खांसी के सिरप में पैरासिटामोल की जांच करें ताकि अनजाने में दोहरी खुराक न हो जाए।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 High fever (above 102°F) that does not come down after 3 days.', hi: '🚨 तेज बुखार (102°F से अधिक) जो 3 दिन तक दवा लेने के बाद भी न उतरे।'),
        BilingualText(en: '🚨 Yellowing of the eyes or skin, or severe persistent right-upper-belly pain (liver concern).', hi: '🚨 आंखों या त्वचा का पीला पड़ना या पेट के ऊपरी दाहिने हिस्से में तेज दर्द।'),
      ],
    ),

    // 2. LISINOPRIL
    MedicineKnowledge(
      id: 'lisinopril',
      genericName: 'Lisinopril',
      brandNames: ['Zestril', 'Prinivil', 'Lipril', 'Listril', 'Lisinopril'],
      name: BilingualText(en: 'Lisinopril', hi: 'लिसिनोप्रिल (Lisinopril)'),
      category: BilingualText(en: 'Blood Pressure & Heart (ACE Inhibitor)', hi: 'ब्लड प्रेशर एवं हृदय सुरक्षा'),
      relatedOrganId: 'heart',
      defaultDosage: '1 tablet (5mg or 10mg)',
      icon: '❤️',
      whatItIs: BilingualText(
        en: 'A cornerstone daily cardiovascular medicine used to control high blood pressure, protect the heart, and improve survival after heart attacks.',
        hi: 'हाई ब्लड प्रेशर को नियंत्रित करने, दिल को सुरक्षित रखने और दिल के दौरे के बाद हृदय की रक्षा के लिए दी जाने वाली मुख्य दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to keep blood pressure smoothly inside target ranges, reduce excessive pumping strain on heart muscles, and protect kidney filters in diabetic patients.',
        hi: 'बीपी को सुरक्षित सीमा में रखने, दिल की मांसपेशियों पर अतिरिक्त खिंचाव घटाने और डायबिटीज के मरीजों के गुर्दों (किडनी) को खराब होने से बचाने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It blocks the enzyme that makes angiotensin II (a natural chemical that tightens arteries). This allows blood vessels to relax, widen, and lower pressure throughout the body.',
        hi: 'यह नसों को सिकोड़ने वाले एंजाइम को रोककर रक्त नलिकाओं को चौड़ा और शिथिल करती है जिससे दिल बिना जोर लगाए खून पंप कर पाता है।',
      ),
      foodGuidance: BilingualText(
        en: 'Can be taken with or without food. Take at the same time every day with a full glass of water.',
        hi: 'इसे भोजन के साथ या बिना भोजन के लिया जा सकता है; रोज एक ही निश्चित समय पर पानी के साथ लें।',
      ),
      commonSideEffects: [
        BilingualText(en: 'A persistent, dry, tickly cough that does not produce phlegm.', hi: 'लगातार रहने वाली सूखी, हल्की खांसी जिसमें बलगम नहीं आता।'),
        BilingualText(en: 'Mild lightheadedness or dizziness when standing up quickly.', hi: 'बिस्तर या कुर्सी से अचानक उठने पर हल्का चक्कर या हल्कापन लगना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Rise slowly from sitting or lying down positions to avoid dizziness.', hi: 'चक्कर से बचने के लिए लेटने या बैठने के बाद हमेशा धीरे-धीरे खड़े हों।'),
        BilingualText(en: 'Do not stop taking this medicine abruptly without speaking to your doctor.', hi: 'डॉक्टर की सलाह के बिना इस दवा को अचानक बंद न करें।'),
        BilingualText(en: 'Avoid high-potassium salt substitutes unless approved by your doctor.', hi: 'डॉक्टर की सलाह के बिना अधिक पोटेशियम वाले नमक के विकल्पों से बचें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Sudden swelling of your lips, face, tongue, or difficulty breathing (Angioedema).', hi: '🚨 होंठ, चेहरे या जीभ पर अचानक सूजन आना या सांस लेने में भारी तकलीफ होना।'),
        BilingualText(en: '🚨 Severe lightheadedness, confusion, or fainting spells.', hi: '🚨 बहुत तेज चक्कर आना या बेहोशी महसूस होना।'),
      ],
    ),

    // 3. METFORMIN
    MedicineKnowledge(
      id: 'metformin',
      genericName: 'Metformin',
      brandNames: ['Glycomet', 'Glucophage', 'Obimet', 'Formin', 'Riomet', 'Cetapin', 'Glyciphage', 'Metformin'],
      name: BilingualText(en: 'Metformin', hi: 'मेटफॉर्मिन (Metformin / Glycomet)'),
      category: BilingualText(en: 'Type 2 Diabetes (Blood Sugar Balancer)', hi: 'शुगर नियंत्रण (डायबिटीज दवा)'),
      relatedOrganId: 'pancreas',
      defaultDosage: '1 tablet (500mg or 850mg)',
      icon: '🩸',
      whatItIs: BilingualText(
        en: 'The world’s most trusted first-choice medicine for controlling elevated blood glucose in adults with Type 2 Diabetes.',
        hi: 'टाइप 2 डायबिटीज में खून की शुगर को सुरक्षित स्तर पर बनाए रखने के लिए दुनिया की सबसे भरोसेमंद और प्रमुख दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to help your body use its natural insulin effectively, lower high fasting and post-meal sugars, and prevent long-term diabetic complications.',
        hi: 'यह शरीर को इंसुलिन का सही उपयोग करने में मदद करती है, खाली पेट व भोजन के बाद की शुगर कम करती है और डायबिटीज के दुष्प्रभावों से बचाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It reduces the amount of excess sugar released by the liver and helps muscle cells absorb glucose from food for energy instead of letting it accumulate in the bloodstream.',
        hi: 'यह लिवर से निकलने वाली फालतू शुगर को कम करती है और भोजन की शुगर को मांसपेशियों में भेजकर ऊर्जा में बदलती है।',
      ),
      foodGuidance: BilingualText(
        en: 'ALWAYS take Metformin with or immediately after meals. Taking it on an empty stomach often causes stomach upset and nausea.',
        hi: 'अति महत्वपूर्ण: पेट दर्द, गैस या मतली से बचने के लिए इसे हमेशा भोजन के साथ या खाना खाने के तुरंत बाद लें। खाली पेट न लें।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild stomach fullness, soft stools, or metallic taste in the mouth during initial weeks.', hi: 'शुरुआती दिनों में पेट में हल्का भारीपन, दस्त या मुंह में धातु जैसा स्वाद।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Never skip your regular meals after taking your diabetes medicine.', hi: 'दवा लेने के बाद भोजन करने में ज्यादा देर न करें।'),
        BilingualText(en: 'Stay well-hydrated with clean water throughout the day.', hi: 'दिनभर में पर्याप्त मात्रा में सादा पानी पिएं।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Extreme unexplained fatigue, fast deep breathing, or severe abdominal pain (Lactic Acidosis signs).', hi: '🚨 बहुत ज्यादा कमजोरी, तेज-तेज गहरी सांसें चलना और पेट में असहनीय दर्द होना।'),
      ],
    ),

    // 4. LEVOTHYROXINE / THYRONORM
    MedicineKnowledge(
      id: 'levothyroxine',
      genericName: 'Levothyroxine',
      brandNames: ['Thyronorm', 'Eltroxin', 'Synthroid', 'Thyrox', 'Levoxyl', 'Thyroxine', 'Levothyroxine'],
      name: BilingualText(en: 'Levothyroxine / Thyronorm', hi: 'लेवोथायरोक्सिन / थायरोनॉर्म (Thyronorm)'),
      category: BilingualText(en: 'Thyroid Hormone Replacement', hi: 'थायराइड हार्मोन संतुलन'),
      relatedOrganId: 'pancreas',
      defaultDosage: '1 tablet (25mcg, 50mcg, 75mcg, or 100mcg)',
      icon: '🦋',
      whatItIs: BilingualText(
        en: 'A bio-identical replacement hormone that replenishes thyroid hormone levels when the body’s thyroid gland is underactive (Hypothyroidism).',
        hi: 'थायराइड ग्रंथि जब कम हार्मोन बनाती है (Hypothyroidism), तो शरीर में हार्मोन की कमी को पूरा करने वाली जरूरी दैनिक दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to restore normal energy levels, relieve extreme fatigue and sluggishness, maintain healthy body weight, and regulate heart rate and metabolism.',
        hi: 'सुस्ती और थकान दूर करने, वजन नियंत्रित रखने, शरीर की ऊर्जा और पाचन क्रिया को सही गति देने के लिए डॉक्टर द्वारा दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It acts exactly like your body’s natural thyroxine (T4) hormone, keeping every cell and organ running at its normal, healthy operational speed.',
        hi: 'यह शरीर के प्राकृतिक थायराइड हार्मोन की तरह काम करके सभी अंगों की कार्यक्षमता और उपापचय (मेटाबॉलिज्म) को संतुलित रखती है।',
      ),
      foodGuidance: BilingualText(
        en: 'CRITICAL: Take first thing in the morning on an EMPTY STOMACH with plain water. Wait at least 30 to 60 minutes before having tea, coffee, milk, or breakfast.',
        hi: 'अति महत्वपूर्ण: सुबह उठते ही खाली पेट केवल सादे पानी से लें। चाय, कॉफी, दूध या नाश्ते से कम से कम 30-60 मिनट पहले लें।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Virtually zero side effects when taken at the exact dosage your body needs.', hi: 'सही मात्रा में लेने पर इसका शरीर पर कोई बुरा असर नहीं होता।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Do not take Calcium or Iron tablets at the same time; space them by at least 4 hours to avoid blocking thyroid absorption.', hi: 'कैल्शियम या आयरन की गोली इसके साथ न लें; दोनों दवाओं के बीच कम से कम 4 घंटे का अंतर रखें।'),
        BilingualText(en: 'Get regular TSH blood tests as advised by your doctor to keep dosage accurate.', hi: 'खुराक की सही जांच के लिए समय-समय पर TSH ब्लड टेस्ट जरूर कराएं।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Rapid or pounding heartbeat, chest tightness, excessive heat sweating, or sudden unexplained weight loss (overdose signs).', hi: '🚨 दिल की धड़कन बहुत तेज होना, घबराहट, अत्यधिक पसीना आना (खुराक ज्यादा होने के संकेत)।'),
      ],
    ),

    // 5. AMLODIPINE
    MedicineKnowledge(
      id: 'amlodipine',
      genericName: 'Amlodipine',
      brandNames: ['Norvasc', 'Amlovas', 'Amlong', 'Amlopres', 'Stamlo', 'Amlodipine'],
      name: BilingualText(en: 'Amlodipine', hi: 'एम्लोडिपिन (Amlodipine / Amlong)'),
      category: BilingualText(en: 'Blood Pressure & Chest Pain (Calcium Channel Blocker)', hi: 'ब्लड प्रेशर एवं सीने के दर्द से राहत'),
      relatedOrganId: 'heart',
      defaultDosage: '1 tablet (5mg or 10mg)',
      icon: '💓',
      whatItIs: BilingualText(
        en: 'A long-acting daily medicine used to treat high blood pressure (hypertension) and prevent chest tightness or angina.',
        hi: 'हाई ब्लड प्रेशर को कम करने और सीने में खिंचाव (एंजाइना) से बचाव के लिए रोज ली जाने वाली प्रमुख दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to lower high blood pressure, reduce your risk of strokes and heart attacks, and help your heart pump with greater comfort.',
        hi: 'बीपी को सामान्य सीमा में रखने और स्ट्रोक (लकवे) व दिल के दौरे के खतरे को कम करने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It prevents calcium from entering smooth muscle cells in blood vessel walls, relaxing and widening the arteries so blood flows smoothly.',
        hi: 'यह रक्त नलिकाओं की मांसपेशियों को आराम देकर नसों को चौड़ा करती है ताकि दिल को खून फेंकने में ज्यादा जोर न लगाना पड़े।',
      ),
      foodGuidance: BilingualText(
        en: 'Take once daily with or without food at the same time. Avoid drinking large quantities of grapefruit juice.',
        hi: 'रोजाना दिन में एक बार लें, खाने से पहले या बाद में। इसके साथ चकोतरे (ग्रेपफ्रूट) का रस न पिएं।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild swelling in the ankles or feet by late evening.', hi: 'शाम के समय टखनों या पैरों में हल्की सूजन आ जाना।'),
        BilingualText(en: 'Facial flushing (feeling warm in face and neck).', hi: 'चेहरे और गर्दन पर हल्की गर्माहट या लाली महसूस होना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'If you notice ankle puffiness, elevate your feet on a footstool while resting.', hi: 'पैरों में सूजन दिखने पर बैठते समय पैरों को छोटे स्टूल पर ऊपर रखें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Severe worsening of ankle or leg swelling.', hi: '🚨 पैरों या टखनों में बहुत ज्यादा सूजन बढ़ जाना।'),
        BilingualText(en: '🚨 Sudden rapid, irregular, or pounding heartbeat.', hi: '🚨 दिल की धड़कन का अचानक बहुत तेज या अनियमित होना।'),
      ],
    ),

    // 6. ATORVASTATIN
    MedicineKnowledge(
      id: 'atorvastatin',
      genericName: 'Atorvastatin',
      brandNames: ['Lipitor', 'Atorva', 'Atocor', 'Storvas', 'Lipikind', 'Tonact', 'Atorvastatin'],
      name: BilingualText(en: 'Atorvastatin', hi: 'एटोरवास्टेटिन (Atorvastatin / Atorva)'),
      category: BilingualText(en: 'Cholesterol & Heart Protection (Statin)', hi: 'कोलेस्ट्रॉल कम करने वाली दवा'),
      relatedOrganId: 'heart',
      defaultDosage: '1 tablet (10mg, 20mg, or 40mg)',
      icon: '🛡️',
      whatItIs: BilingualText(
        en: 'A highly effective statin medicine that lowers "bad" LDL cholesterol and triglycerides while protecting blood vessel walls from fatty plaque blockages.',
        hi: 'खून में खराब कोलेस्ट्रॉल (LDL) को कम करने और नसों में चर्बी के जमाव को रोककर दिल को सुरक्षित रखने वाली दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to prevent heart attacks, stabilize cholesterol plaques inside arteries, and reduce stroke risk in high-risk senior patients.',
        hi: 'नसों में ब्लॉकेज को रोकने और दिल के दौरे व लकवे के खतरे को कम करने के लिए डॉक्टर द्वारा दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It blocks the liver enzyme responsible for manufacturing bad cholesterol and helps the liver clear existing cholesterol from circulating blood.',
        hi: 'यह लिवर में कोलेस्ट्रॉल बनने की गति को धीमा करती है और नसों की अंदरूनी दीवारों को साफ व मजबूत रखती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Usually taken once daily at bedtime, with or without food. The liver produces most cholesterol overnight.',
        hi: 'आमतौर पर इसे रात को सोने से पहले लिया जाता है, क्योंकि लिवर रात में सबसे ज्यादा कोलेस्ट्रॉल बनाता है।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild muscle aches or stiffness in legs or arms.', hi: 'जांघों या बाहों की मांसपेशियों में हल्का दर्द या भारीपन।'),
        BilingualText(en: 'Mild digestive sluggishness or constipation.', hi: 'हल्का कब्ज या पाचन का धीमा होना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Continue a heart-healthy diet with low saturated oils and keep up light daily walks.', hi: 'कम तेल-घी वाला पौष्टिक भोजन लें और रोज सैर करने का नियम बनाए रखें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Unexplained, severe muscle tenderness, weakness, and dark tea-colored urine (Rhabdomyolysis warning).', hi: '🚨 मांसपेशियों में असहनीय दर्द, कमजोरी और चाय जैसा गहरा पेशाब आना।'),
      ],
    ),

    // 7. TELMISARTAN
    MedicineKnowledge(
      id: 'telmisartan',
      genericName: 'Telmisartan',
      brandNames: ['Micardis', 'Telma', 'Telpres', 'Cresar', 'Telsar', 'Telmikind', 'Telmisartan'],
      name: BilingualText(en: 'Telmisartan', hi: 'टेल्मिसार्टन (Telmisartan / Telma)'),
      category: BilingualText(en: 'Blood Pressure & Kidney Protection (ARB)', hi: 'ब्लड प्रेशर एवं गुर्दा सुरक्षा'),
      relatedOrganId: 'heart',
      defaultDosage: '1 tablet (40mg or 80mg)',
      icon: '❤️',
      whatItIs: BilingualText(
        en: 'A modern, 24-hour long-acting blood pressure medicine that relaxes arteries and protects vital kidney function.',
        hi: 'हाई ब्लड प्रेशर को 24 घंटे तक नियंत्रित रखने और गुर्दों को सुरक्षित रखने वाली आधुनिक दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to maintain steady blood pressure day and night and safeguard kidney filters in senior patients with hypertension or diabetes.',
        hi: 'दिन-रात बीपी को स्थिर रखने और बुजुर्गों में किडनी के फिल्टर को सुरक्षित रखने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It blocks angiotensin II receptors on blood vessel walls, keeping arteries relaxed and open so blood travels smoothly.',
        hi: 'यह नसों पर दबाव डालने वाले संकेतों को रोककर नसों को हमेशा खुला और ढीला रखती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Take once daily in the morning with a glass of water, with or without food.',
        hi: 'रोज सुबह एक निश्चित समय पर पानी के साथ लें, खाने से पहले या बाद में।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild dizziness when standing up; mild lower back tiredness.', hi: 'उठने पर हल्का चक्कर या कमर में हल्का दर्द।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Avoid high-potassium salt substitutes without doctor approval.', hi: 'डॉक्टर की सलाह के बिना पोटेशियम युक्त नमक (सेंधा नमक की अधिकता) से बचें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Swelling of face or feet, or persistent severe lightheadedness.', hi: '🚨 चेहरे या पैरों पर सूजन आना या लगातार चक्कर बने रहना।'),
      ],
    ),

    // 8. ASPIRIN / ECOSPRIN
    MedicineKnowledge(
      id: 'aspirin',
      genericName: 'Aspirin (Low Dose)',
      brandNames: ['Ecosprin', 'Ecosprin 75', 'Ecosprin 150', 'Disprin', 'Loprin', 'Delisprin', 'ASA', 'Aspirin'],
      name: BilingualText(en: 'Aspirin / Ecosprin (Low Dose)', hi: 'एस्पिरिन / इकोस्प्रिन (खून पतला करने वाली दवा)'),
      category: BilingualText(en: 'Heart & Stroke Prevention (Antiplatelet)', hi: 'दिल का दौरा व स्ट्रोक रोकथाम'),
      relatedOrganId: 'heart',
      defaultDosage: '1 tablet (75mg or 150mg)',
      icon: '🛡️',
      whatItIs: BilingualText(
        en: 'A low-dose blood thinner (antiplatelet) that prevents blood cells from sticking together to form dangerous arterial clots.',
        hi: 'खून को पतला रखने और नसों में खतरनाक थक्के (Clots) जमने से रोकने वाली जरूरी जीवनरक्षक दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed to prevent heart attacks, recurrent angina, and brain strokes in patients with cardiovascular risks.',
        hi: 'दिल के दौरे, सीने में दर्द और दिमाग में लकवे (स्ट्रोक) के खतरे को रोकने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It stops blood platelets from clumping together into clots inside narrowed or stented blood vessels.',
        hi: 'यह खून की कोशिकाओं को आपस में चिपककर थक्का बनाने से रोकती है जिससे खून आसानी से बहता रहे।',
      ),
      foodGuidance: BilingualText(
        en: 'ALWAYS take after meals or with a little milk to protect your stomach lining from acid irritation.',
        hi: 'पेट में जलन या अल्सर से बचने के लिए इसे हमेशा खाना खाने के बाद या दूध के साथ लें। खाली पेट न लें।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild stomach acidity or easier small bruises on skin when bumped.', hi: 'हल्की एसिडिटी या हल्की चोट पर त्वचा पर जल्दी नीला निशान पड़ जाना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Always inform your dentist or surgeon that you take Aspirin before any dental or medical procedure.', hi: 'दांत निकालने या किसी भी ऑपरेशन से पहले डॉक्टर को जरूर बताएं कि आप एस्पिरिन लेते हैं।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Black tarry stools, coughing up blood, or unusual gum bleeding that does not stop.', hi: '🚨 काला दस्त होना, उल्टी में खून आना या मसूड़ों से लगातार खून बहना।'),
      ],
    ),

    // 9. PANTOPRAZOLE / PAN 40
    MedicineKnowledge(
      id: 'pantoprazole',
      genericName: 'Pantoprazole',
      brandNames: ['Pan', 'Pan 40', 'Pan-40', 'Pantocid', 'Pantodac', 'Protonix', 'Pantocar', 'Pantoprazole'],
      name: BilingualText(en: 'Pantoprazole / Pan 40', hi: 'पेंटोप्राजोल / पैन 40 (Pantoprazole)'),
      category: BilingualText(en: 'Stomach Acid & Heartburn (Proton Pump Inhibitor)', hi: 'पेट का एसिड व गैस नियंत्रण'),
      relatedOrganId: 'stomach',
      defaultDosage: '1 tablet (40mg)',
      icon: '🫃',
      whatItIs: BilingualText(
        en: 'A proton pump inhibitor that significantly reduces excess stomach acid to treat heartburn, gastritis, and heal ulcers.',
        hi: 'पेट में बनने वाले फालतू एसिड (तेजाब) को कम करके सीने की जलन और अल्सर से बचाने वाली दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed for acid reflux (GERD), sour burps, burning stomach pain, and to shield the stomach when taking blood thinners or painkillers.',
        hi: 'सीने में जलन (एसिडिटी), खट्टी डकारें और दर्द निवारक दवाओं से पेट की सुरक्षा के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It switches off the tiny acid-producing pumps in the stomach wall, allowing irritated food pipes and stomach tissue to rest and heal.',
        hi: 'यह पेट की दीवारों में मौजूद एसिड बनाने वाले नन्हे पंपों को धीमा कर देती है जिससे पेट को ठंडक मिलती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Best taken in the MORNING 30 to 60 minutes BEFORE breakfast on an empty stomach with plain water.',
        hi: 'सबसे अच्छा असर पाने के लिए इसे सुबह नाश्ते से 30-60 मिनट पहले खाली पेट पानी के साथ लें।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild headache or slight change in bowel frequency.', hi: 'हल्का सिरदर्द या पेट में हल्की गैस।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Do not crush or chew the tablet; swallow it whole with water.', hi: 'गोली को चबाएं या तोड़ें नहीं; इसे पूरा पानी से निगलें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Severe watery diarrhea lasting more than 2 consecutive days.', hi: '🚨 लगातार 2 दिन से ज्यादा तेज पतले दस्त होना।'),
      ],
    ),

    // 10. SALBUTAMOL / ASTHALIN INHALER
    MedicineKnowledge(
      id: 'salbutamol',
      genericName: 'Salbutamol (Albuterol)',
      brandNames: ['Asthalin', 'Ventolin', 'ProAir', 'Aerolin', 'Salbair', 'Salbutamol'],
      name: BilingualText(en: 'Salbutamol / Asthalin Inhaler', hi: 'सालबुटामोल / अस्थालीन (Asthalin) इनहेलर'),
      category: BilingualText(en: 'Respiratory Rescue (Fast Bronchodilator)', hi: 'सांस की तकलीफ से तुरंत राहत'),
      relatedOrganId: 'lungs',
      defaultDosage: '1 to 2 puffs as needed',
      icon: '🫁',
      whatItIs: BilingualText(
        en: 'A fast-acting "rescue" medicine inhaled directly into the lungs to quickly open tight airways during breathlessness or wheezing.',
        hi: 'अचानक सांस फूलने या छाती में सीटी जैसी आवाज आने पर तुरंत राहत देने वाली इनहेलर दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed for sudden asthma flare-ups, COPD breathing difficulty, and acute chest tightness.',
        hi: 'अस्थमा (दमा) का दौरा पड़ने या सांस की नली सिकुड़ने पर नली को तुरंत खोलने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It relaxes the constricted bronchial muscles wrapping around airway tubes within 5 minutes, allowing air to flow freely into the lungs.',
        hi: 'यह 5 मिनट के अंदर सांस की नलियों की जकड़ी हुई मांसपेशियों को ढीला करके फेफड़ों के रास्ते खोल देती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Can be used at any time when required, regardless of meal timings.',
        hi: 'भोजन की परवाह किए बिना जरूरत पड़ने पर किसी भी समय लिया जा सकता है।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild hand trembling or faster heart rate for 15-20 minutes after inhalation.', hi: 'इनहेलर लेने के बाद 15-20 मिनट तक हाथों में हल्की कंपकंपी या धड़कन तेज होना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Always rinse your mouth with water and spit it out after using inhalers.', hi: 'इनहेलर का कश लेने के बाद हमेशा सादे पानी से कुल्ला करके थूक दें।'),
        BilingualText(en: 'Keep your inhaler readily accessible at your bedside and when stepping outdoors.', hi: 'अपना इनहेलर हमेशा तकिए के पास या अपनी जेब में रखें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 If you need more than 4 puffs in a single day and breathlessness still does not improve (Medical Emergency).', hi: '🚨 4 कश लेने के बाद भी सांस न संभल रही हो तो तुरंत अस्पताल जाएं।'),
      ],
    ),

    // 11. CALCIUM + VITAMIN D3 / SHELCAL
    MedicineKnowledge(
      id: 'calcium_vit_d',
      genericName: 'Calcium Carbonate + Vitamin D3',
      brandNames: ['Shelcal', 'Shelcal 500', 'Gemcal', 'Caltrate', 'Cipcal', 'Maxical', 'Calcium'],
      name: BilingualText(en: 'Calcium + Vitamin D3 / Shelcal', hi: 'कैल्शियम एवं विटामिन डी3 (Calcium + D3 / Shelcal)'),
      category: BilingualText(en: 'Bone & Joint Strength Supplement', hi: 'हड्डियों व जोड़ों की मजबूती'),
      relatedOrganId: 'bones',
      defaultDosage: '1 tablet (500mg Calcium + 250IU D3)',
      icon: '🦴',
      whatItIs: BilingualText(
        en: 'An essential mineral and vitamin combination that strengthens aging bones, protects joint cartilage, and prevents fractures.',
        hi: 'उम्रदराज हड्डियों को मजबूत बनाने और टूटने (फ्रैक्चर) से बचाने वाला जरूरी खनिज व विटामिन सप्लीमेंट।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed for brittle bones (osteoporosis), knee osteoarthritis, and general calcium deficiency in seniors.',
        hi: 'कमजोर हड्डियों (ऑस्टियोपोरोसिस), घुटनों के दर्द और शरीर में कैल्शियम की कमी दूर करने के लिए दिया जाता है।',
      ),
      howItWorks: BilingualText(
        en: 'Calcium provides the physical hardness of bones, while Vitamin D acts as the carrier to absorb calcium from your food into the bloodstream.',
        hi: 'कैल्शियम हड्डियों को मजबूती देता है और विटामिन D खाने में से कैल्शियम को सोखने में मदद करता है।',
      ),
      foodGuidance: BilingualText(
        en: 'Best taken AFTER lunch or dinner with a glass of water for maximum digestive absorption.',
        hi: 'दोपहर या रात के खाने के बाद पानी के साथ लेना सबसे फायदेमंद होता है।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild constipation or slight bloating in some seniors.', hi: 'कुछ बुजुर्गों में हल्का कब्ज या पेट में भारीपन।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Drink adequate water daily and space by 4 hours from thyroid medication.', hi: 'खूब पानी पिएं और थायराइड की दवा से कम से कम 4 घंटे की दूरी रखें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Severe persistent constipation or history of recurrent kidney stones.', hi: '🚨 बहुत ज्यादा कब्ज रहना या पहले से गुर्दे में पथरी की समस्या होना।'),
      ],
    ),

    // 12. GLIMEPIRIDE
    MedicineKnowledge(
      id: 'glimepiride',
      genericName: 'Glimepiride',
      brandNames: ['Amaryl', 'Glimy', 'Zoryl', 'Gemer', 'Glimestar', 'Glimepiride'],
      name: BilingualText(en: 'Glimepiride', hi: 'ग्लाइमपिराइड (Glimepiride)'),
      category: BilingualText(en: 'Type 2 Diabetes (Insulin Stimulator)', hi: 'डायबिटीज दवा (इंसुलिन बढ़ाने वाली)'),
      relatedOrganId: 'pancreas',
      defaultDosage: '1 tablet (1mg or 2mg)',
      icon: '🩸',
      whatItIs: BilingualText(
        en: 'A sulfonylurea diabetes medicine that prompts the pancreas to release more natural insulin after eating.',
        hi: 'अग्न्याशय (Pancreas) को सक्रिय करके खून में प्राकृतिक इंसुलिन की मात्रा बढ़ाने वाली डायबिटीज दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed when lifestyle changes and Metformin alone are not sufficient to keep blood sugars in the safe zone.',
        hi: 'जब केवल खान-पान से शुगर काबू में न आ रही हो, तब शुगर को सुरक्षित स्तर पर लाने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It stimulates beta cells in the pancreas to secrete additional insulin into the bloodstream after meals.',
        hi: 'यह अग्न्याशय की कोशिकाओं को संदेश देकर भोजन के बाद इंसुलिन का स्राव बढ़ाती है।',
      ),
      foodGuidance: BilingualText(
        en: 'CRITICAL: Take with breakfast or the first main meal. NEVER take on an empty stomach without eating immediately.',
        hi: 'अति महत्वपूर्ण: सुबह के नाश्ते या पहले मुख्य भोजन के साथ लें। दवा लेकर भूखे न रहें वरना शुगर गिर सकती है।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Risk of low blood sugar (hypoglycemia) if a meal is delayed or missed.', hi: 'खाना देर से खाने पर शुगर अचानक कम होने (लो शुगर) का खतरा।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Always carry a small pack of glucose candy or sweets in your pocket.', hi: 'अपनी जेब में हमेशा थोड़ी मिश्री, चीनी या टॉफी रखें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Shaking, cold sweat, rapid pulse, and sudden dizziness (Low Sugar episode).', hi: '🚨 हाथ कांपना, माथे पर ठंडा पसीना और घबराहट होना (लो शुगर के लक्षण)।'),
      ],
    ),

    // 13. CLOPIDOGREL
    MedicineKnowledge(
      id: 'clopidogrel',
      genericName: 'Clopidogrel',
      brandNames: ['Plavix', 'Clopilet', 'Deplatt', 'Ceruvin', 'Noklot', 'Clopidogrel'],
      name: BilingualText(en: 'Clopidogrel / Plavix', hi: 'क्लोपिडोग्रेल (Clopidogrel / Plavix)'),
      category: BilingualText(en: 'Blood Thinner & Stent Protection', hi: 'खून पतला करने वाली दवा (स्टेंट सुरक्षा)'),
      relatedOrganId: 'heart',
      defaultDosage: '1 tablet (75mg)',
      icon: '🛡️',
      whatItIs: BilingualText(
        en: 'A powerful antiplatelet blood thinner that prevents dangerous blood clots from forming inside heart stents or narrowed arteries.',
        hi: 'खून के थक्के बनने से रोकने और दिल में लगे स्टेंट (Stent) को खुला रखने वाली जरूरी दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Essential for patients with heart stents, previous heart attacks, or vascular disease to prevent recurrent blockage.',
        hi: 'एंजियोप्लास्टी (स्टेंट) के बाद नसों को फिर से बंद होने से बचाने के लिए डॉक्टर द्वारा दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It prevents platelets from binding together and adhering to the metal mesh of cardiac stents.',
        hi: 'यह खून की कोशिकाओं को स्टेंट की जाली पर चिपकने से रोकती है जिससे नया थक्का नहीं बनता।',
      ),
      foodGuidance: BilingualText(
        en: 'Take once daily at the same time every day, with or without food.',
        hi: 'रोजाना एक ही समय पर लें, खाने से पहले या बाद में।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Small cuts bleed longer than usual; easier skin bruising.', hi: 'हल्का कट लगने पर खून थोड़ी ज्यादा देर तक रिसना या त्वचा पर नीले निशान पड़ना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Never stop this medicine without cardiologist permission, especially during the first year after a stent.', hi: 'स्टेंट डलने के बाद डॉक्टर की अनुमति के बिना इस दवा को एक दिन भी बंद न करें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Blood in urine, black stools, or unusual severe sudden headache.', hi: '🚨 पेशाब में खून आना, काला दस्त या अचानक बहुत तेज सिरदर्द होना।'),
      ],
    ),

    // 14. FUROSEMIDE / LASIX
    MedicineKnowledge(
      id: 'furosemide',
      genericName: 'Furosemide',
      brandNames: ['Lasix', 'Frusenex', 'Furocot', 'Furosemide'],
      name: BilingualText(en: 'Furosemide / Lasix', hi: 'फ्यूरोसेमाइड / लैसिक्स (Lasix)'),
      category: BilingualText(en: 'Water Pill (Diuretic) for Swelling & Heart Support', hi: 'पैरों की सूजन व पानी निकालने वाली दवा'),
      relatedOrganId: 'kidneys',
      defaultDosage: '1 tablet (20mg or 40mg)',
      icon: '🫘',
      whatItIs: BilingualText(
        en: 'A fast-acting diuretic ("water pill") that helps the kidneys expel trapped fluid and salt from swollen tissues.',
        hi: 'शरीर और पैरों में भरे फालतू पानी और नमक को पेशाब के रास्ते बाहर निकालने वाली दवा।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed for swollen ankles, fluid buildup in the lungs, and heart weakness.',
        hi: 'पैरों और टखनों की सूजन उतारने और फेफड़ों में पानी भरने से सांस फूलने पर आराम देने के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It directs the kidneys to filter more water into urine, reducing total fluid volume and relieving pressure on the heart.',
        hi: 'यह गुर्दों से ज्यादा पेशाब बनाकर शरीर का भारीपन और नसों का तनाव कम करती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Take in the MORNING after breakfast. Avoid taking late in the evening so nighttime sleep is not interrupted by frequent urination.',
        hi: 'इसे सुबह नाश्ते के बाद लें। शाम को या रात में न लें ताकि रात को बार-बार पेशाब के लिए नींद न खुले।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Frequent urination for 4 to 6 hours after taking the tablet.', hi: 'गोली लेने के बाद 4-6 घंटे तक बार-बार पेशाब लगना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'Stand up slowly from bed to avoid lightheadedness.', hi: 'बिस्तर से उठते समय अचानक खड़े न हों, पहले 1 मिनट बैठें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Severe dry mouth, intense thirst, muscle cramps, or extreme dizziness.', hi: '🚨 बहुत ज्यादा गला सूखना, मांसपेशियों में ऐंठन या भारी कमजोरी।'),
      ],
    ),

    // 15. MONTELUKAST
    MedicineKnowledge(
      id: 'montelukast',
      genericName: 'Montelukast',
      brandNames: ['Singulair', 'Montair', 'Montek', 'Telekast', 'Romilast', 'Montelukast'],
      name: BilingualText(en: 'Montelukast', hi: 'मोंटेलुकास्ट (Montelukast)'),
      category: BilingualText(en: 'Allergy & Asthma Airway Protection', hi: 'एलर्जी व सांस की नली सुरक्षा'),
      relatedOrganId: 'lungs',
      defaultDosage: '1 tablet (10mg)',
      icon: '🫁',
      whatItIs: BilingualText(
        en: 'A daily preventive medicine that reduces allergic swelling and constriction in airway tubes and nasal passages.',
        hi: 'सांस की नली और नाक में एलर्जी व सूजन को रोकने वाली दैनिक सुरक्षा गोली।',
      ),
      whyPrescribed: BilingualText(
        en: 'Prescribed for nighttime asthma cough, seasonal allergic rhinitis, and wheezing.',
        hi: 'मौसम बदलने पर छींकें आने, रात में खांसी का दौरा पड़ने और दमे की रोकथाम के लिए दी जाती है।',
      ),
      howItWorks: BilingualText(
        en: 'It blocks leukotrienes—inflammatory chemicals that make breathing passages swell and produce thick mucus.',
        hi: 'यह एलर्जी पैदा करने वाले रसायनों को रोककर सांस की नली को शांत और खुला रखती है।',
      ),
      foodGuidance: BilingualText(
        en: 'Usually taken once daily in the evening or at bedtime, with or without food.',
        hi: 'आमतौर पर शाम को या रात को सोने से पहले ली जाती है, खाने के साथ या बाद में।',
      ),
      commonSideEffects: [
        BilingualText(en: 'Mild drowsiness or vivid dreams in some patients.', hi: 'हल्की नींद आना या अजीब सपने आना।'),
      ],
      commonPrecautions: [
        BilingualText(en: 'This is a daily maintenance drug; use your inhaler for sudden acute attacks.', hi: 'यह रोज की सुरक्षा दवा है, अचानक सांस फूलने पर इनहेलर का ही प्रयोग करें।'),
      ],
      whenToContactDoctor: [
        BilingualText(en: '🚨 Severe mood changes, agitation, or severe sleep disruption.', hi: '🚨 स्वभाव में अत्यधिक चिड़चिड़ापन या घबराहट होना।'),
      ],
    ),
  ];

  // ─── ROBUST SEARCH & SMART MATCHING ──────────────────────────────────────────

  static List<MedicineKnowledge> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final cleanQuery = _normalize(q);
    final tokens = cleanQuery.split(' ').where((t) => t.length >= 2).toList();

    return medicines.where((med) {
      final generic = _normalize(med.genericName);
      final nameEn = _normalize(med.name.en);
      final nameHi = med.name.hi.toLowerCase();
      final brands = med.brandNames.map(_normalize).toList();

      if (generic.contains(cleanQuery) || nameEn.contains(cleanQuery) || nameHi.contains(q)) {
        return true;
      }

      if (brands.any((b) => b.contains(cleanQuery) || cleanQuery.contains(b))) {
        return true;
      }

      for (var token in tokens) {
        if (generic.contains(token) || brands.any((b) => b.contains(token))) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  static MedicineKnowledge? findByName(String name) {
    final raw = name.trim().toLowerCase();
    if (raw.isEmpty) return null;

    final clean = _normalize(raw);
    final tokens = clean.split(' ').where((t) => t.length >= 3).toList();

    // 1. Exact or direct match
    for (var med in medicines) {
      final gen = _normalize(med.genericName);
      final en = _normalize(med.name.en);
      final brands = med.brandNames.map(_normalize).toList();

      if (gen == clean || en == clean || med.id == clean) {
        return med;
      }
      if (brands.any((b) => b == clean)) {
        return med;
      }
    }

    // 2. Contains match in either direction
    for (var med in medicines) {
      final gen = _normalize(med.genericName);
      final en = _normalize(med.name.en);
      final brands = med.brandNames.map(_normalize).toList();

      if (clean.contains(gen) || gen.contains(clean) || clean.contains(en) || en.contains(clean)) {
        return med;
      }

      for (var b in brands) {
        if (clean.contains(b) || b.contains(clean)) {
          return med;
        }
      }
    }

    // 3. Significant word token match (e.g. "Dolo" in "Dolo 650" or "Metformin" in "Metformin 500mg")
    for (var token in tokens) {
      // ignore pure numbers like "650", "500"
      if (int.tryParse(token) != null) continue;

      for (var med in medicines) {
        final gen = _normalize(med.genericName);
        final brands = med.brandNames.map(_normalize).toList();

        if (gen.contains(token) || brands.any((b) => b.contains(token))) {
          return med;
        }
      }
    }

    return null;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
