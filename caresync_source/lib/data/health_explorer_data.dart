import '../models/health_explorer_model.dart';

class HealthExplorerData {
  // ─── 10 CORE ORGANS ──────────────────────────────────────────────────────────

  static const List<BodyOrgan> organs = [
    BodyOrgan(
      id: 'brain',
      name: BilingualText(en: 'Brain & Nerves', hi: 'मस्तिष्क एवं तंत्रिकाएं'),
      systemName: BilingualText(en: 'Nervous System', hi: 'तंत्रिका तंत्र'),
      region: BodyRegion.head,
      icon: 'brain',
      emoji: '🧠',
      xPercentFront: 0.50,
      yPercentFront: 0.10,
      xPercentBack: 0.50,
      yPercentBack: 0.09,
      primaryFunction: BilingualText(
        en: 'The master control center of your thoughts, memory, balance, and all body movements.',
        hi: 'यह आपके विचारों, याददाश्त, शारीरिक संतुलन और सभी गतिविधियों का मुख्य नियंत्रण केंद्र है।',
      ),
      easyMetaphor: BilingualText(
        en: 'Like the central computer of your entire body.',
        hi: 'आपके पूरे शरीर का मुख्य कंप्यूटर जो हर अंग को निर्देश भेजता है।',
      ),
      conditionIds: ['stroke', 'dementia', 'migraine'],
      associatedProfileKey: 'brain',
    ),
    BodyOrgan(
      id: 'eyes',
      name: BilingualText(en: 'Eyes & Vision', hi: 'आंखें एवं दृष्टि'),
      systemName: BilingualText(en: 'Sensory System', hi: 'संवेदी तंत्र'),
      region: BodyRegion.head,
      icon: 'eye',
      emoji: '👁️',
      xPercentFront: 0.43,
      yPercentFront: 0.13,
      primaryFunction: BilingualText(
        en: 'Captures light and sends clear visual signals to your brain so you can read, walk, and see loved ones.',
        hi: 'रोशनी को पकड़कर दिमाग तक साफ तस्वीरें पहुंचाती हैं ताकि आप पढ़ सकें और आसानी से देख सकें।',
      ),
      easyMetaphor: BilingualText(
        en: 'Like twin high-definition cameras with natural self-cleaning lenses.',
        hi: 'दो प्राकृतिक कैमरों की तरह जो दुनिया की रंगीन तस्वीरें दिमाग तक पहुंचाते हैं।',
      ),
      conditionIds: ['cataract', 'glaucoma', 'diabetic_retinopathy'],
      associatedProfileKey: 'eyes',
    ),
    BodyOrgan(
      id: 'ent',
      name: BilingualText(en: 'Ears, Nose & Throat', hi: 'कान, नाक और गला'),
      systemName: BilingualText(en: 'ENT & Balance', hi: 'श्रवण एवं श्वसन मार्ग'),
      region: BodyRegion.head,
      icon: 'ear',
      emoji: '👂',
      xPercentFront: 0.57,
      yPercentFront: 0.14,
      primaryFunction: BilingualText(
        en: 'Helps you hear voices, maintains body balance, filters the air you breathe, and aids clear speech.',
        hi: 'आवाज़ें सुनने, शरीर का संतुलन बनाए रखने और सांस की हवा को छानने में मदद करता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'Your body’s sound receivers and air purification gateway.',
        hi: 'शरीर का साउंड रिसीवर और ताजी हवा को छानने वाला मुख्य द्वार।',
      ),
      conditionIds: ['hearing_loss', 'vertigo', 'sinusitis'],
      associatedProfileKey: 'ent',
    ),
    BodyOrgan(
      id: 'heart',
      name: BilingualText(en: 'Heart & Blood Vessels', hi: 'हृदय एवं रक्त नलिकाएं'),
      systemName: BilingualText(en: 'Cardiovascular System', hi: 'हृदय एवं परिसंचरण तंत्र'),
      region: BodyRegion.chest,
      icon: 'heart',
      emoji: '❤️',
      xPercentFront: 0.53,
      yPercentFront: 0.28,
      primaryFunction: BilingualText(
        en: 'Pumps fresh, oxygen-rich blood through thousands of miles of blood vessels to every single cell.',
        hi: 'हर मिनट धड़क कर पूरे शरीर में जीवनदायिनी ऑक्सीजन और पौष्टिक रक्त पहुंचाता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'The hardest-working water pump in the world, beating over 100,000 times every day.',
        hi: 'एक शक्तिशाली मोटर पंप जो बिना रुके दिन-रात पूरे शरीर में खून का प्रवाह बनाए रखता है।',
      ),
      conditionIds: ['hypertension', 'heart_attack_warning', 'heart_failure'],
      associatedProfileKey: 'has_bp',
    ),
    BodyOrgan(
      id: 'lungs',
      name: BilingualText(en: 'Lungs & Airways', hi: 'फेफड़े एवं श्वसन नली'),
      systemName: BilingualText(en: 'Respiratory System', hi: 'श्वसन तंत्र'),
      region: BodyRegion.chest,
      icon: 'lungs',
      emoji: '🫁',
      xPercentFront: 0.44,
      yPercentFront: 0.29,
      xPercentBack: 0.44,
      yPercentBack: 0.27,
      primaryFunction: BilingualText(
        en: 'Takes in fresh oxygen from the air and expels carbon dioxide gas with every breath.',
        hi: 'हवा से शुद्ध ऑक्सीजन लेकर खून में घोलता है और हानिकारक कार्बन डाइऑक्साइड को बाहर निकालता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'Like a pair of flexible sponges that expand and contract 20,000 times a day.',
        hi: 'हवा से फूलने और सिकुड़ने वाले दो कोमल स्पंज जो सांस को साफ रखते हैं।',
      ),
      conditionIds: ['asthma', 'copd', 'pneumonia_tb'],
      associatedProfileKey: 'has_tb',
    ),
    BodyOrgan(
      id: 'stomach',
      name: BilingualText(en: 'Stomach & Liver', hi: 'पेट एवं लिवर (यकृत)'),
      systemName: BilingualText(en: 'Digestive System', hi: 'पाचन तंत्र'),
      region: BodyRegion.abdomen,
      icon: 'stomach',
      emoji: '🫃',
      xPercentFront: 0.52,
      yPercentFront: 0.43,
      primaryFunction: BilingualText(
        en: 'Breaks down your food into energy, absorbs vitamins, and detoxifies chemicals in the liver.',
        hi: 'भोजन को पचाकर ऊर्जा बनाता है और लिवर के जरिए हानिकारक तत्वों को साफ करता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'Your internal kitchen and chemical filtration refinery.',
        hi: 'शरीर का मुख्य रसोईघर और रसायनों को शुद्ध करने वाली प्रयोगशाला।',
      ),
      conditionIds: ['gerd_acidity', 'fatty_liver', 'indigestion'],
      associatedProfileKey: 'stomach',
    ),
    BodyOrgan(
      id: 'pancreas',
      name: BilingualText(en: 'Pancreas & Blood Sugar', hi: 'अग्न्याशय एवं शुगर संतुलन'),
      systemName: BilingualText(en: 'Metabolic & Endocrine System', hi: 'चयापचय तंत्र'),
      region: BodyRegion.abdomen,
      icon: 'pancreas',
      emoji: '🩸',
      xPercentFront: 0.47,
      yPercentFront: 0.47,
      primaryFunction: BilingualText(
        en: 'Produces insulin—the biological key that lets sugar enter your cells to give you energy.',
        hi: 'इंसुलिन बनाता है—जो चाबी की तरह कोशिकाओं का ताला खोलकर शुगर को ऊर्जा में बदलता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'The smart fuel gauge that balances your blood sugar levels 24/7.',
        hi: 'शरीर का स्मार्ट फ्यूल मीटर जो खून में मिठास की मात्रा को संतुलित रखता है।',
      ),
      conditionIds: ['type2_diabetes', 'hypoglycemia', 'hyperglycemia'],
      associatedProfileKey: 'sugar_logs',
    ),
    BodyOrgan(
      id: 'kidneys',
      name: BilingualText(en: 'Kidneys & Urinary Tract', hi: 'गुर्दे (किडनी) एवं मूत्र मार्ग'),
      systemName: BilingualText(en: 'Urinary & Excretory System', hi: 'उत्सर्जन तंत्र'),
      region: BodyRegion.abdomen,
      icon: 'kidneys',
      emoji: '🫘',
      xPercentFront: 0.54,
      yPercentFront: 0.52,
      xPercentBack: 0.50,
      yPercentBack: 0.48,
      primaryFunction: BilingualText(
        en: 'Filters 200 liters of blood daily to remove waste water, excess salts, and regulate blood pressure.',
        hi: 'रोजाना 200 लीटर खून को छानकर अपशिष्ट जल और फालतू नमक को पेशाब के जरिए बाहर निकालता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'Two ultra-precise water filter cartridges working non-stop behind your lower ribs.',
        hi: 'पीठ के निचले हिस्से में मौजूद दो सुपर वॉटर फिल्टर जो खून को हमेशा साफ रखते हैं।',
      ),
      conditionIds: ['kidney_health', 'kidney_stones', 'uti'],
      associatedProfileKey: 'kidneys',
    ),
    BodyOrgan(
      id: 'bones',
      name: BilingualText(en: 'Bones, Spine & Joints', hi: 'हड्डियां, रीढ़ और जोड़'),
      systemName: BilingualText(en: 'Musculoskeletal System', hi: 'कंकाल एवं जोड़ तंत्र'),
      region: BodyRegion.limbs,
      icon: 'bone',
      emoji: '🦴',
      xPercentFront: 0.38,
      yPercentFront: 0.68,
      xPercentBack: 0.50,
      yPercentBack: 0.38,
      primaryFunction: BilingualText(
        en: 'Provides the strong structural scaffold that protects internal organs and enables standing, walking, and bending.',
        hi: 'शरीर को मजबूत ढांचा देता है, भीतरी अंगों की रक्षा करता है और उठने-बैठने में मदद करता है।',
      ),
      easyMetaphor: BilingualText(
        en: 'The strong steel beams and smooth oiled hinges of your biological home.',
        hi: 'मजबूत खंभे और तेल लगे हुए कब्जों की तरह जो शरीर को बिना दर्द के हिलाने में मदद करते हैं।',
      ),
      conditionIds: ['osteoarthritis', 'osteoporosis', 'back_pain'],
      associatedProfileKey: 'bones',
    ),
    BodyOrgan(
      id: 'skin',
      name: BilingualText(en: 'Skin & Immunity', hi: 'त्वचा एवं रोग प्रतिरोधक क्षमता'),
      systemName: BilingualText(en: 'Integumentary & Immune System', hi: 'सुरक्षा एवं प्रतिरक्षा तंत्र'),
      region: BodyRegion.wholeBody,
      icon: 'shield',
      emoji: '🛡️',
      xPercentFront: 0.32,
      yPercentFront: 0.45,
      primaryFunction: BilingualText(
        en: 'Your body’s outermost protective armor against germs, maintaining body temperature and water balance.',
        hi: 'कीटाणुओं से बचाने वाली शरीर की सुरक्षा ढाल जो तापमान और पानी को संतुलित रखती है।',
      ),
      easyMetaphor: BilingualText(
        en: 'A waterproof, self-healing protective coat that covers your entire body.',
        hi: 'एक वाटरप्रूफ सुरक्षा कवच जो चोट लगने पर खुद ब खुद ठीक हो जाता है।',
      ),
      conditionIds: ['skin_aging_dehydration', 'wound_healing', 'immune_fatigue'],
      associatedProfileKey: 'skin',
    ),
  ];

  // ─── 22 CURATED CONDITIONS WITH BILINGUAL EDUCATION ──────────────────────────

  static const List<HealthCondition> conditions = [
    // 1. HYPERTENSION (HEART)
    HealthCondition(
      id: 'hypertension',
      name: BilingualText(en: 'High Blood Pressure (Hypertension)', hi: 'उच्च रक्तचाप (हाई ब्लड प्रेशर)'),
      organId: 'heart',
      icon: '❤️',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Think of your blood vessels like a garden hose. High blood pressure means the fluid is pushing too hard against the vessel walls, forcing the heart to pump against heavy resistance.',
        hi: 'रक्त नलिकाओं को पानी के पाइप की तरह समझें। हाई बीपी का मतलब है कि खून नसों की दीवारों पर बहुत तेज दबाव डाल रहा है, जिससे दिल पर ज्यादा जोर पड़ता है।',
      ),
      visualConcept: VisualConcept(
        healthyTitle: BilingualText(en: 'Normal Blood Pressure', hi: 'सामान्य रक्तचाप (120/80)'),
        healthyDescription: BilingualText(
          en: 'Blood flows smoothly through relaxed, flexible artery walls with minimal friction.',
          hi: 'लचीली और चौड़ी नसों में खून बिना किसी रुकावट के आसानी से बहता है।',
        ),
        affectedTitle: BilingualText(en: 'High Blood Pressure', hi: 'हाई ब्लड प्रेशर (140/90+)'),
        affectedDescription: BilingualText(
          en: 'Narrowed or stiff artery walls cause high friction, straining the heart pump.',
          hi: 'सिकुड़ी या सख्त नसों की दीवारों पर खून का दबाव बढ़ जाता है जिससे दिल पर तनाव आता है।',
        ),
      ),
      commonSymptoms: [
        BilingualText(en: 'Often called a "silent condition" because it usually has NO obvious symptoms.', hi: 'इसे "खामोश बीमारी" कहते हैं क्योंकि इसके अक्सर कोई साफ लक्षण नहीं दिखते।'),
        BilingualText(en: 'Mild morning headache behind the neck.', hi: 'सुबह के समय सिर के पिछले हिस्से में हल्का दर्द।'),
        BilingualText(en: 'Occasional lightheadedness or fatigue.', hi: 'कभी-कभार चक्कर आना या बिना वजह थकान महसूस होना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Sudden severe chest pain radiating to the left arm or jaw.', hi: '🚨 सीने में तेज जकड़न या दर्द जो बाएं हाथ या जबड़े तक फैले।'),
        BilingualText(en: '🚨 Severe shortness of breath while resting.', hi: '🚨 बैठे-बैठे अचानक सांस लेने में भारी तकलीफ होना।'),
        BilingualText(en: '🚨 Sudden blurred vision with confusion or slurred speech.', hi: '🚨 अचानक धुंधला दिखना या बोलने में लड़खड़ाहट होना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Reduce sodium (salt) in curries, pickles, and packaged snacks.', hi: 'अचार, पापड़ और खाने में अतिरिक्त नमक की मात्रा कम करें।'),
        BilingualText(en: 'Take a gentle 20-minute walk every day after meals.', hi: 'रोजाना सुबह या शाम को 20 मिनट धीमी गति से टहलें।'),
        BilingualText(en: 'Take prescribed BP medicines at the exact same time every morning.', hi: 'डॉक्टर द्वारा दी गई बीपी की दवाई रोज एक ही निश्चित समय पर लें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'What is my personal target blood pressure for my age?', hi: 'मेरी उम्र के हिसाब से मेरा सही बीपी कितना होना चाहिए?'),
        BilingualText(en: 'Should I monitor my BP at home in the morning or evening?', hi: 'मुझे घर पर बीपी सुबह नापना चाहिए या शाम को?'),
      ],
      mythsAndFacts: [
        MythFactItem(
          myth: BilingualText(en: 'I can stop taking my BP medicine when I feel good.', hi: 'जब मैं अच्छा महसूस करूं तो बीपी की दवाई बंद कर सकता हूं।'),
          fact: BilingualText(en: 'BP medicine keeps your pressure normal; stopping it causes dangerous silent spikes.', hi: 'दवाई ही आपके बीपी को सामान्य रखती है; इसे अचानक बंद करने से खतरनाक उछाल आ सकता है।'),
        ),
      ],
    ),

    // 2. HEART ATTACK & EMERGENCY WARNINGS
    HealthCondition(
      id: 'heart_attack_warning',
      name: BilingualText(en: 'Heart Warning Signs & Circulation Care', hi: 'दिल के खतरे के संकेत एवं देखभाल'),
      organId: 'heart',
      icon: '🫀',
      severityCategory: 'emergency_aware',
      plainExplanation: BilingualText(
        en: 'The heart muscle itself needs a constant supply of fresh blood. When the arteries feeding the heart become clogged by cholesterol plaque, the muscle struggles for oxygen.',
        hi: 'दिल की मांसपेशियों को भी काम करने के लिए खून की जरूरत होती है। जब दिल की नसों में चर्बी जम जाती है, तो दिल तक पर्याप्त ऑक्सीजन नहीं पहुंच पाती।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Chest fullness or mild heaviness during uphill walking.', hi: 'सीढ़ियां चढ़ते समय सीने में भारीपन या खिंचाव महसूस होना।'),
        BilingualText(en: 'Getting breathless faster than normal during daily chores.', hi: 'रोजमर्रा के कामों में पहले की तुलना में जल्दी सांस फूलना।'),
        BilingualText(en: 'Unexplained cold sweats or indigestion-like burning.', hi: 'अचानक ठंडा पसीना आना या सीने में जलन जैसा लगना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Crushing chest pressure feeling like an elephant sitting on the chest.', hi: '🚨 सीने पर भारी पत्थर जैसा दबाव या असहनीय दर्द।'),
        BilingualText(en: '🚨 Pain spreading to back, neck, jaw, stomach, or one/both arms.', hi: '🚨 दर्द जो पीठ, गर्दन, जबड़े या दोनों बाहों में फैल रहा हो।'),
        BilingualText(en: '🚨 CALL EMERGENCY (102 / 108 / 112) IMMEDIATELY if these occur.', hi: '🚨 ऐसा होने पर तुरंत एम्बुलेंस (102 / 108) को फोन करें।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Avoid oily deep-fried foods and trans fats.', hi: 'ज्यादा तला-भुना और बार-बार गर्म किया गया तेल न खाएं।'),
        BilingualText(en: 'Keep emergency contact numbers handy on your phone.', hi: 'अपने फोन में आपातकालीन नंबर हमेशा तैयार रखें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Do I need an ECG or Lipid Profile test this year?', hi: 'क्या मुझे इस साल ईसीजी (ECG) या कोलेस्ट्रॉल टेस्ट कराने की जरूरत है?'),
      ],
    ),

    // 3. HEART FAILURE & FLUID RETENTION
    HealthCondition(
      id: 'heart_failure',
      name: BilingualText(en: 'Heart Strain & Swelling (Heart Failure)', hi: 'दिल की कमजोरी एवं पैरों में सूजन'),
      organId: 'heart',
      icon: '💓',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Heart failure does NOT mean the heart stopped; it means the heart muscle is pumping with less force, causing fluid to pool in the feet and lungs.',
        hi: 'इसका मतलब दिल का रुकना नहीं है, बल्कि दिल की पम्पिंग क्षमता थोड़ी कमजोर होना है, जिससे पैरों या फेफड़ों में पानी जमा होने लगता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Swelling in both ankles, feet, or legs by evening.', hi: 'शाम होते-होते दोनों टखनों या पैरों में सूजन आ जाना।'),
        BilingualText(en: 'Needing 2 or 3 pillows under the head to breathe comfortably while sleeping.', hi: 'सोते समय सांस लेने के लिए सिर के नीचे 2-3 तकिए लगाने की जरूरत पड़ना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Sudden weight gain of 2 kg in 2 days from fluid retention.', hi: '🚨 2 दिन में 2 किलो वजन अचानक बढ़ जाना (पानी भरने के कारण)।'),
        BilingualText(en: '🚨 Coughing up pink-tinged frothy sputum with breathlessness.', hi: '🚨 सांस फूलने के साथ झागदार खांसी आना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Weigh yourself every morning after using the bathroom.', hi: 'रोज सुबह शौच के बाद अपना वजन नोट करें।'),
        BilingualText(en: 'Follow doctor advice on daily water intake limits.', hi: 'डॉक्टर द्वारा बताए गए पानी पीने के दैनिक नियम का पालन करें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'How much water should I drink in 24 hours?', hi: 'मुझे 24 घंटे में अधिकतम कितना पानी पीना चाहिए?'),
      ],
    ),

    // 4. STROKE AWARENESS (BRAIN)
    HealthCondition(
      id: 'stroke',
      name: BilingualText(en: 'Brain Stroke Awareness (F.A.S.T.)', hi: 'ब्रेन स्ट्रोक (लकवा) के लक्षण'),
      organId: 'brain',
      icon: '🧠',
      severityCategory: 'emergency_aware',
      plainExplanation: BilingualText(
        en: 'A stroke happens when a blood clot blocks blood flow to a part of the brain. Remembering F.A.S.T. (Face, Arms, Speech, Time) saves lives.',
        hi: 'जब दिमाग की किसी नस में खून का थक्का जम जाता है तो उस हिस्से को खून नहीं मिलता। F.A.S.T. के चार नियम याद रखकर जान बचाई जा सकती है।',
      ),
      visualConcept: VisualConcept(
        healthyTitle: BilingualText(en: 'Normal Brain Circulation', hi: 'दिमाग में सामान्य रक्त प्रवाह'),
        healthyDescription: BilingualText(en: 'Unobstructed arteries supply constant oxygen to all brain regions.', hi: 'दिमाग के सभी हिस्सों तक खून और ऑक्सीजन बिना रुकावट पहुंचती है।'),
        affectedTitle: BilingualText(en: 'Blocked Artery (Ischemic Event)', hi: 'नस में रुकावट (स्ट्रोक)'),
        affectedDescription: BilingualText(en: 'A clot stops blood flow, causing rapid weakness on one side of the body.', hi: 'खून का थक्का जमने से शरीर के एक तरफ अचानक कमजोरी आ जाती है।'),
      ),
      commonSymptoms: [
        BilingualText(en: 'Face: One side of the face droops when smiling.', hi: 'F - Face (चेहरा): मुस्कुराने पर चेहरे का एक कोना झुक जाना।'),
        BilingualText(en: 'Arms: One arm drifts down when raising both arms.', hi: 'A - Arms (हाथ): दोनों हाथ उठाने पर एक हाथ नीचे गिरना या सुन्न होना।'),
        BilingualText(en: 'Speech: Words sound slurred or confusing.', hi: 'S - Speech (आवाज): बोलने में जीभ लड़खड़ाना या समझ न आना।'),
        BilingualText(en: 'Time: Time is brain! Seek emergency hospital care within 3 hours.', hi: 'T - Time (समय): 3 घंटे के अंदर तुरंत बड़े अस्पताल पहुंचें।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Sudden numbness or weakness of the face, arm, or leg on one side.', hi: '🚨 शरीर के एक हिस्से का अचानक सुन्न पड़ जाना या ताकत खत्म होना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Strictly control blood pressure and blood sugar.', hi: 'अपने ब्लड प्रेशर और शुगर को हमेशा नियंत्रण में रखें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Am I taking a blood-thinner medicine, and what precautions should I follow?', hi: 'क्या मैं खून पतला करने की दवाई ले रहा हूँ, इसके क्या नियम हैं?'),
      ],
    ),

    // 5. DEMENTIA & MEMORY CARE (BRAIN)
    HealthCondition(
      id: 'dementia',
      name: BilingualText(en: 'Memory Care & Healthy Aging', hi: 'याददाश्त एवं मानसिक स्वास्थ्य'),
      organId: 'brain',
      icon: '💭',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Occasional forgetfulness like misplacing keys is normal with age. However, difficulty remembering familiar names, dates, or getting lost in known streets deserves medical attention.',
        hi: 'चश्मा या चाबी रखकर भूलना सामान्य है। लेकिन रोज मिलने वाले लोगों के नाम भूलना या जानी-पहचानी जगहों पर रास्ता भूलना जांच का विषय है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Asking the same question repeatedly within minutes.', hi: 'एक ही बात को कुछ ही मिनटों में बार-बार पूछना।'),
        BilingualText(en: 'Difficulty managing money, bills, or telephone numbers.', hi: 'पैसे गिनने, बिल भरने या फोन नंबर डायल करने में परेशानी होना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Wandering outside the home and forgetting the way back.', hi: '🚨 घर से बाहर निकल जाना और वापस लौटने का रास्ता भूल जाना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Stay socially active: talk to children, grandchildren, and friends daily.', hi: 'परिवार और दोस्तों से रोज बातचीत करें और अकेलेपन से बचें।'),
        BilingualText(en: 'Solve puzzles, read newspapers, or listen to music.', hi: 'अखबार पढ़ें, पहेलियां सुलझाएं या नए शौक अपनाएं।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Can Vitamin B12 or Thyroid deficiency cause my forgetfulness?', hi: 'क्या विटामिन B12 या थायराइड की कमी से भूलने की समस्या हो सकती है?'),
      ],
    ),

    // 6. MIGRAINE & TENSION HEADACHES (BRAIN)
    HealthCondition(
      id: 'migraine',
      name: BilingualText(en: 'Headaches & Neuralgia', hi: 'सिरदर्द एवं माइग्रेन'),
      organId: 'brain',
      icon: '⚡',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'Headaches can come from muscle tension in the neck, eye strain, high blood pressure, or neural sensitivity like migraines.',
        hi: 'सिरदर्द गर्दन की मांसपेशियों में खिंचाव, आंखों की कमजोरी, हाई बीपी या माइग्रेन की वजह से हो सकता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Throbbing pain on one side of the head with sensitivity to bright light.', hi: 'सिर के एक तरफ तेज टीस मारता दर्द और तेज रोशनी से चिड़चिड़ापन।'),
        BilingualText(en: 'Tight band-like sensation around the forehead by evening.', hi: 'माथे के चारों तरफ कसकर पट्टी बंधी होने जैसा दर्द।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 "Thunderclap" headache—the most severe headache of your life starting in seconds.', hi: '🚨 जीवन का सबसे तेज सिरदर्द जो अचानक कुछ ही सेकंड में शुरू हो जाए।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Drink adequate water and avoid skipping meals.', hi: 'भरपूर पानी पिएं और लंबे समय तक भूखे न रहें।'),
        BilingualText(en: 'Check reading glasses prescription yearly.', hi: 'साल में एक बार अपनी आंखों के चश्मे का नंबर जरूर जांचें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Could my headache be related to my blood pressure readings?', hi: 'क्या मेरा सिरदर्द मेरे ब्लड प्रेशर से जुड़ा हो सकता है?'),
      ],
    ),

    // 7. CATARACTS (EYES)
    HealthCondition(
      id: 'cataract',
      name: BilingualText(en: 'Cataract (Cloudy Lens)', hi: 'मोतियाबिंद (आंखों का धुंधलापन)'),
      organId: 'eyes',
      icon: '👁️',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'The natural clear lens inside your eye gradually becomes cloudy over time, like looking through a foggy or frosted bathroom window.',
        hi: 'उम्र के साथ आंख का प्राकृतिक पारदर्शी लेंस धुंधला हो जाता है, जैसे किसी धुंधले या भाप जमे शीशे से देखना।',
      ),
      visualConcept: VisualConcept(
        healthyTitle: BilingualText(en: 'Clear Natural Lens', hi: 'साफ प्राकृतिक लेंस'),
        healthyDescription: BilingualText(en: 'Light passes crisply onto the retina, creating sharp images.', hi: 'रोशनी आसानी से पार होकर पर्दे पर बिल्कुल साफ तस्वीर बनाती है।'),
        affectedTitle: BilingualText(en: 'Clouded Cataract Lens', hi: 'मोतियाबिंद वाला लेंस'),
        affectedDescription: BilingualText(en: 'Cloudy protein buildup scatters light, making vision blurry and faded.', hi: 'लेंस पर धुंधलापन आ जाने से तस्वीरें धुंधली और फीकी दिखती हैं।'),
      ),
      commonSymptoms: [
        BilingualText(en: 'Cloudy, blurry, or dimmed vision while watching TV or reading.', hi: 'पढ़ते समय या टीवी देखते समय सब कुछ धुंधला या कोहरे जैसा दिखना।'),
        BilingualText(en: 'Trouble seeing at night with glare around streetlights.', hi: 'रात में गाड़ी की लाइट या बल्ब के चारों ओर गोल घेरा (Glare) दिखना।'),
        BilingualText(en: 'Colors looking faded or yellowish.', hi: 'रंग पहले जितने चटकीले न दिखकर फीके या पीले दिखना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Sudden painful loss of vision in one eye.', hi: '🚨 किसी एक आंख में अचानक तेज दर्द के साथ रोशनी कम होना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Wear sunglasses outdoors to protect from UV rays.', hi: 'धूप में निकलते समय आंखों को धूप के चश्मे से सुरक्षित रखें।'),
        BilingualText(en: 'Cataract is easily curable with a simple, painless 15-minute modern surgery.', hi: 'मोतियाबिंद 15 मिनट के एक सरल और सुरक्षित ऑपरेशन से पूरी तरह ठीक हो जाता है।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Is my cataract mature enough to need lens replacement surgery?', hi: 'क्या मेरा मोतियाबिंद पक चुका है और लेंस बदलवाने की जरूरत है?'),
      ],
    ),

    // 8. GLAUCOMA (EYES)
    HealthCondition(
      id: 'glaucoma',
      name: BilingualText(en: 'Glaucoma (Eye Pressure)', hi: 'काला मोतिया / ग्लूकोमा (आंख का दबाव)'),
      organId: 'eyes',
      icon: '🔍',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Fluid pressure builds up inside the eyeball, slowly damaging the optic nerve from the outer edges inward without early pain.',
        hi: 'आंख के अंदर का तरल दबाव बढ़ जाता है, जिससे देखने वाली मुख्य नस धीरे-धीरे कमजोर होने लगती है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Loss of side (peripheral) vision, as if looking through a narrow tunnel.', hi: 'आस-पास का दायरा कम दिखना और केवल सामने का ही दिखाई देना।'),
        BilingualText(en: 'Frequent changes in eye-glass prescriptions.', hi: 'चश्मे का नंबर बार-बार तेजी से बदलना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Severe sudden eye pain, nausea, and seeing rainbow halos around lights.', hi: '🚨 आंख में अचानक असहनीय दर्द, उल्टी का मन होना और बल्ब के चारों ओर इंद्रधनुषी छल्ले दिखना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Put prescribed glaucoma eye drops daily without skipping a single day.', hi: 'डॉक्टर द्वारा दी गई आई ड्रॉप्स (Eye Drops) रोज नियम से डालें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'What is my current eye pressure (IOP) reading in both eyes?', hi: 'मेरी दोनों आंखों का दबाव (IOP) इस समय कितना है?'),
      ],
    ),

    // 9. DIABETIC RETINOPATHY (EYES)
    HealthCondition(
      id: 'diabetic_retinopathy',
      name: BilingualText(en: 'Diabetic Eye Care (Retinopathy)', hi: 'डायबिटीज में आंखों की देखभाल (रेटिनोपैथी)'),
      organId: 'eyes',
      icon: '🩺',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Long-term high blood sugar weakens the delicate tiny blood vessels in the retina at the back of the eye.',
        hi: 'लंबे समय तक शुगर बढ़ी रहने से आंख के पिछले पर्दे (रेटिना) की बारीक नसें कमजोर हो जाती हैं।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Dark spots or floating cobwebs (floaters) drifting in vision.', hi: 'नजर के सामने काले धब्बे या जाले तैरते हुए दिखाई देना।'),
        BilingualText(en: 'Fluctuating vision that gets blurry when sugar is high.', hi: 'शुगर बढ़ने पर नजर का अचानक धुंधला हो जाना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Sudden dark curtain or shadow falling over part of your vision.', hi: '🚨 नजर के किसी हिस्से के सामने अचानक काला पर्दा सा छा जाना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Get a dilated retina eye checkup once every year if you have diabetes.', hi: 'यदि आपको शुगर है तो साल में एक बार आंखों की पुतली फैलाकर पर्दे की जांच जरूर कराएं।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Is there any sign of vessel leakage on my retina exam?', hi: 'क्या मेरे आंख के पर्दे पर नसों से रिसाव का कोई लक्षण दिख रहा है?'),
      ],
    ),

    // 10. TYPE 2 DIABETES (PANCREAS)
    HealthCondition(
      id: 'type2_diabetes',
      name: BilingualText(en: 'Type 2 Diabetes (Blood Sugar)', hi: 'टाइप 2 डायबिटीज (शुगर की बीमारी)'),
      organId: 'pancreas',
      icon: '🩸',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'The pancreas either makes too little insulin, or your cells become resistant to it, causing glucose sugar to pile up in your bloodstream instead of fueling cells.',
        hi: 'अग्न्याशय (Pancreas) कम इंसुलिन बनाता है या कोशिकाएं उसका सही इस्तेमाल नहीं कर पातीं, जिससे खून में शुगर का स्तर बढ़ जाता है।',
      ),
      visualConcept: VisualConcept(
        healthyTitle: BilingualText(en: 'Balanced Sugar Metabolism', hi: 'संतुलित शुगर व्यवस्था'),
        healthyDescription: BilingualText(en: 'Insulin unlocks cells, allowing food energy to be used efficiently.', hi: 'इंसुलिन चाबी की तरह काम करके शुगर को कोशिकाओं के अंदर भेजकर ऊर्जा में बदलता है।'),
        affectedTitle: BilingualText(en: 'High Blood Sugar (Insulin Resistance)', hi: 'शुगर का खून में जमाव'),
        affectedDescription: BilingualText(en: 'Sugar remains trapped in the blood, starving cells and damaging vessels.', hi: 'कोशिकाओं का ताला न खुलने से शुगर खून में ही जमा होकर नसों को नुकसान पहुंचाती है।'),
      ),
      commonSymptoms: [
        BilingualText(en: 'Waking up multiple times at night to pass urine.', hi: 'रात को बार-बार पेशाब जाने के लिए नींद खुलना।'),
        BilingualText(en: 'Excessive thirst and dry mouth even after drinking water.', hi: 'पानी पीने के बाद भी बार-बार बहुत तेज प्यास और गला सूखना।'),
        BilingualText(en: 'Slow healing of small scratches or foot cuts.', hi: 'पैरों या हाथों में लगी छोटी-मोटी चोट का बहुत देर से भरना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Shaking, cold sweats, dizziness, and confusion (Low Sugar Shock).', hi: '🚨 शरीर कांपना, पसीना छूटना, चक्कर आना और घबराहट (लो शुगर का झटका)।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Eat more green vegetables, whole grains, and limit sweets/white rice.', hi: 'हरी सब्जियां, सलाद और फाइबर ज्यादा खाएं; मीठा और सफेद चावल सीमित करें।'),
        BilingualText(en: 'Inspect bottom of both feet every night for blisters or cracks.', hi: 'रोज रात को अपने पैरों के तलवों की जांच करें कि कोई छाला या कट तो नहीं है।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'What is my 3-month average HbA1c test result?', hi: 'मेरा 3 महीने का औसत शुगर टेस्ट (HbA1c) कितना आया है?'),
      ],
    ),

    // 11. HYPOGLYCEMIA (LOW SUGAR)
    HealthCondition(
      id: 'hypoglycemia',
      name: BilingualText(en: 'Low Blood Sugar Crisis (Hypoglycemia)', hi: 'लो ब्लड शुगर (अचानक शुगर गिरना)'),
      organId: 'pancreas',
      icon: '⚠️',
      severityCategory: 'emergency_aware',
      plainExplanation: BilingualText(
        en: 'Blood sugar dropping below 70 mg/dL is an urgent situation. The brain starves of fuel, causing immediate shakes, sweating, and rapid heart rate.',
        hi: 'ब्लड शुगर का 70 से नीचे गिरना एक आपात स्थिति है। दिमाग को तुरंत ऊर्जा न मिलने से शरीर कांपने लगता है और पसीना छूटता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Sudden shaking hands, trembling, and severe cold sweat.', hi: 'अचानक हाथ-पैर कांपना और माथे पर ठंडा पसीना आना।'),
        BilingualText(en: 'Extreme sudden hunger and racing heartbeat.', hi: 'अचानक बहुत तेज भूख लगना और दिल की धड़कन तेज होना।'),
        BilingualText(en: 'Dizziness, blurred vision, and irritability.', hi: 'चक्कर आना, आंखों के आगे अंधेरा छाना और चिड़चिड़ापन।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Follow the 15-15 Rule: Eat 3 teaspoons of sugar or half cup juice immediately.', hi: '🚨 तुरंत 3 चम्मच चीनी, गुड़ या आधा गिलास मीठा शरबत पिएं।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Always keep 3-4 sugar candies or glucose tablets in your pocket.', hi: 'अपनी जेब में हमेशा 3-4 टॉफियां या ग्लूकोज की गोलियां रखें।'),
        BilingualText(en: 'Never delay meals after taking morning diabetes medicine.', hi: 'सुबह शुगर की दवाई लेने के बाद नाश्ता करने में देरी न करें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Should I adjust my medicine dosage if I experience low sugar episodes?', hi: 'अगर मुझे बार-बार लो शुगर हो तो क्या दवाई की खुराक कम करनी चाहिए?'),
      ],
    ),

    // 12. ASTHMA & BRONCHIAL CARE (LUNGS)
    HealthCondition(
      id: 'asthma',
      name: BilingualText(en: 'Asthma & Bronchial Wheeze', hi: 'अस्थमा / दमा (सांस की नली में सूजन)'),
      organId: 'lungs',
      icon: '🫁',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'The breathing pipes inside the lungs become sensitive, swollen, and tight when exposed to cold air, dust, smoke, or seasonal pollen.',
        hi: 'फेफड़ों की सांस की नलियां धूल, धुएं या ठंडी हवा के संपर्क में आने पर सिकुड़ जाती हैं और उनमें सूजन आ जाती है।',
      ),
      visualConcept: VisualConcept(
        healthyTitle: BilingualText(en: 'Wide Open Airway', hi: 'खुली और साफ सांस नली'),
        healthyDescription: BilingualText(en: 'Air moves silently in and out with zero chest tightness.', hi: 'हवा बिना किसी रुकावट या सीटी की आवाज के आसानी से आती-जाती है।'),
        affectedTitle: BilingualText(en: 'Narrowed Swollen Airway', hi: 'सिकुड़ी हुई सांस नली'),
        affectedDescription: BilingualText(en: 'Constricted muscles and mucus produce a whistling wheeze sound.', hi: 'नली सिकुड़ने से सांस लेते समय सीटी जैसी आवाज (Wheezing) आती है।'),
      ),
      commonSymptoms: [
        BilingualText(en: 'Whistling or wheezing sound when breathing out.', hi: 'सांस छोड़ते समय छाती से सीटी जैसी आवाज आना।'),
        BilingualText(en: 'Dry cough that gets worse during late night or early morning.', hi: 'देर रात या भोर के समय सूखी खांसी का दौरा पड़ना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Inability to speak full sentences without gasping for breath.', hi: '🚨 सांस के लिए तड़पना और एक पूरा वाक्य भी न बोल पाना।'),
        BilingualText(en: '🚨 Blue color on fingernails or lips (lack of oxygen).', hi: '🚨 नाखूनों या होंठों का रंग नीला पड़ना (ऑक्सीजन की भारी कमी)।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Keep your rescue inhaler within arm’s reach at all times.', hi: 'अपना इनहेलर हमेशा अपने तकिए के पास या जेब में रखें।'),
        BilingualText(en: 'Cover your nose with a warm cloth during cold winter mornings.', hi: 'सर्दियों की सुबह बाहर निकलते समय नाक और मुंह पर मफलर बांधें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Can you verify that my inhaler technique is correct?', hi: 'क्या मैं इनहेलर सही तरीके से खींच रहा हूँ, कृपया जांचें?'),
      ],
    ),

    // 13. COPD (LUNGS)
    HealthCondition(
      id: 'copd',
      name: BilingualText(en: 'COPD (Chronic Airway Obstruction)', hi: 'सीओपीडी (फेफड़ों की पुरानी बीमारी)'),
      organId: 'lungs',
      icon: '💨',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Often related to past smoking or biomass chulha smoke exposure, the tiny air sacs in the lungs lose their bounce, trapping stale air.',
        hi: 'बीड़ी-सिगरेट या चूल्हे के धुएं के लंबे संपर्क से फेफड़ों की छोटी थैलियां कमजोर हो जाती हैं और हवा अंदर फंसने लगती है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Daily chronic cough producing clear or white phlegm.', hi: 'रोजाना सुबह उठते ही बलगम वाली लगातार खांसी आना।'),
        BilingualText(en: 'Breathlessness even while bathing or dressing.', hi: 'नहाते या कपड़े बदलते समय भी सांस फूल जाना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Yellow/green phlegm with high fever and sudden worsening of breath.', hi: '🚨 तेज बुखार के साथ पीला-हरा बलगम और सांस का बहुत ज्यादा फूलना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Practice pursed-lip breathing (inhale through nose, exhale slowly through pursed lips).', hi: 'नाक से सांस लेकर होंठों को सीटी की तरह बनाकर धीरे-धीरे छोड़ें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Do I need annual flu or pneumonia vaccination to protect my lungs?', hi: 'क्या मुझे फेफड़ों की सुरक्षा के लिए निमोनिया का टीका लगवाना चाहिए?'),
      ],
    ),

    // 14. PNEUMONIA & TUBERCULOSIS (LUNGS)
    HealthCondition(
      id: 'pneumonia_tb',
      name: BilingualText(en: 'Lung Infections & TB Care', hi: 'फेफड़ों का संक्रमण एवं टीबी'),
      organId: 'lungs',
      icon: '🛡️',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Bacteria or viruses can cause fluid to accumulate in the lung air sacs. Tuberculosis (TB) is a completely curable infection requiring consistent full-course medication.',
        hi: 'कीटाणुओं से फेफड़ों में पानी और बलगम भर सकता है। टीबी एक पूरी तरह ठीक होने वाली बीमारी है बशर्ते दवाई का पूरा कोर्स नियम से किया जाए।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Cough lasting for more than 2 weeks.', hi: 'लगातार 2 हफ्ते से ज्यादा समय तक खांसी रहना।'),
        BilingualText(en: 'Evening fever and night sweats with gradual weight loss.', hi: 'शाम को हल्का बुखार आना, रात में पसीना और वजन का घटना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Coughing up fresh red blood streaks in sputum.', hi: '🚨 खांसी या बलगम में खून के छींटे आना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Never stop TB medicines halfway, even if you feel 100% better.', hi: 'टीबी की दवाइयां बीच में कभी न छोड़ें, भले ही आप पूरी तरह ठीक महसूस करें।'),
        BilingualText(en: 'Keep living rooms well-ventilated with fresh cross sunlight.', hi: 'कमरे में धूप और ताजी हवा का पूरा प्रबंध रखें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'When is my next sputum check or chest X-ray scheduled?', hi: 'मेरी अगली बलगम जांच या एक्स-रे कब होना है?'),
      ],
    ),

    // 15. GERD & ACID REFLUX (STOMACH)
    HealthCondition(
      id: 'gerd_acidity',
      name: BilingualText(en: 'Acid Reflux & Heartburn (GERD)', hi: 'एसिडिटी एवं सीने में जलन (GERD)'),
      organId: 'stomach',
      icon: '🔥',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'The valve between your food pipe and stomach becomes loose, allowing sharp stomach acid to travel upward into your chest and throat.',
        hi: 'खाने की नली और पेट के बीच का ढक्कन ढीला होने से पेट का तेजाब ऊपर छाती और गले की तरफ आने लगता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Burning sensation behind the chest bone after eating.', hi: 'खाना खाने के बाद छाती की हड्डी के पीछे जलन होना।'),
        BilingualText(en: 'Sour, bitter fluid coming up into the mouth when lying down flat.', hi: 'सीधे लेटने पर मुंह में खट्टा या कड़वा पानी आना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Difficulty swallowing food, or food feeling stuck in the throat.', hi: '🚨 खाना निगलने में दर्द होना या भोजन गले में अटका हुआ महसूस होना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Eat dinner at least 2 hours before going to sleep.', hi: 'सोने से कम से कम 2 घंटे पहले रात का खाना खा लें।'),
        BilingualText(en: 'Elevate the head of your bed by 6 inches with an extra pillow or riser.', hi: 'सोते समय सिरहाने को थोड़ा ऊंचा रखें ताकि एसिड ऊपर न चढ़े।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Can long-term antacid tablets affect my calcium or kidney levels?', hi: 'क्या लंबे समय तक एंटासिड गोली लेने से कैल्शियम या किडनी पर असर पड़ता है?'),
      ],
    ),

    // 16. FATTY LIVER & METABOLISM (STOMACH)
    HealthCondition(
      id: 'fatty_liver',
      name: BilingualText(en: 'Liver Health & Fatty Liver', hi: 'लिवर की सेहत एवं फैटी लिवर'),
      organId: 'stomach',
      icon: '🫃',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Excess calories, sugars, and sedentary routines cause fat droplets to store inside liver cells, making the liver sluggish at filtering toxins.',
        hi: 'अतिरिक्त कैलोरी, मीठा और कम शारीरिक गतिविधि से लिवर की कोशिकाओं में चर्बी जम जाती है, जिससे लिवर सुस्त हो जाता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Mild dull heaviness in the upper right side of the belly.', hi: 'पेट के ऊपरी दाएं हिस्से में हल्का भारीपन।'),
        BilingualText(en: 'General low energy and sluggish digestion.', hi: 'दिनभर सुस्ती रहना और खाना देर से पचना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Yellowing of the eyes/skin (jaundice) or dark tea-colored urine.', hi: '🚨 आंखों या त्वचा का पीला पड़ना (पीलिया) या चाय जैसा गहरा पेशाब आना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Avoid sweetened beverages, packaged fruit juices, and alcohol.', hi: 'मीठी कोल्ड ड्रिंक, पैकेट वाले जूस और शराब से पूरी तरह परहेज करें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'What did my latest Liver Function Test (LFT) and Ultrasound show?', hi: 'मेरे लिवर फंक्शन टेस्ट (LFT) और अल्ट्रासाउंड की रिपोर्ट कैसी है?'),
      ],
    ),

    // 17. KIDNEY HEALTH & STONES (KIDNEYS)
    HealthCondition(
      id: 'kidney_health',
      name: BilingualText(en: 'Kidney Health & Stone Prevention', hi: 'गुर्दों की सुरक्षा एवं पथरी से बचाव'),
      organId: 'kidneys',
      icon: '🫘',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'Kidneys work best when you drink enough water. Insufficient hydration allows concentrated minerals to crystallize into painful kidney stones.',
        hi: 'गुर्दे तभी अच्छे से काम करते हैं जब शरीर में पानी की कमी न हो। कम पानी पीने से खनिज जमने लगते हैं और पथरी बन जाती है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Sudden sharp pain in the lower back radiating toward the groin.', hi: 'कमर के निचले हिस्से से आगे की तरफ जाता हुआ तेज चुभन वाला दर्द।'),
        BilingualText(en: 'Burning feeling or red/pink color while passing urine.', hi: 'पेशाब करते समय तेज जलन या पेशाब का रंग लाल/गुलाबी दिखना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Inability to pass urine for over 12 hours with severe lower belly swelling.', hi: '🚨 12 घंटे से ज्यादा समय तक पेशाब का बिल्कुल न उतरना और पेट में सूजन।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Drink water evenly throughout the day so your urine stays pale straw-colored.', hi: 'दिनभर में नियमित पानी पिएं ताकि पेशाब का रंग हल्का पीला या पानी जैसा साफ रहे।'),
        BilingualText(en: 'Avoid taking unprescribed painkiller pills (NSAIDs) which damage kidneys.', hi: 'बिना डॉक्टर की सलाह के दर्द निवारक दवाइयां (Painkillers) बार-बार न खाएं।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Are my Blood Urea and Serum Creatinine levels in the safe range?', hi: 'क्या मेरा यूरिया और सीरम क्रिएटिनिन (Creatinine) सामान्य सीमा में है?'),
      ],
    ),

    // 18. OSTEOARTHRITIS & KNEE CARE (BONES)
    HealthCondition(
      id: 'osteoarthritis',
      name: BilingualText(en: 'Knee & Joint Care (Osteoarthritis)', hi: 'घुटनों व जोड़ों का दर्द (गठिया / ऑस्टियोआर्थराइटिस)'),
      organId: 'bones',
      icon: '🦴',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'The smooth, rubbery cartilage cushion between your knee bones gradually wears down, causing friction, stiffness, and clicking sounds when standing up.',
        hi: 'घुटनों की हड्डियों के बीच की चिकनी गद्दी (कार्टिलेज) उम्र के साथ घिस जाती है, जिससे उठने-बैठने पर रगड़ और दर्द होता है।',
      ),
      visualConcept: VisualConcept(
        healthyTitle: BilingualText(en: 'Healthy Joint Cushion', hi: 'स्वस्थ जोड़ (पूरी गद्दी)'),
        healthyDescription: BilingualText(en: 'Thick smooth cartilage allows effortless, painless joint movement.', hi: 'मोटी चिकनी गद्दी हड्डियों को आपस में टकराने से बचाती है।'),
        affectedTitle: BilingualText(en: 'Worn Cartilage (Arthritis)', hi: 'घिसा हुआ जोड़ (गठिया)'),
        affectedDescription: BilingualText(en: 'Thinned cartilage causes bone-on-bone friction and stiffness.', hi: 'गद्दी पतली होने से हड्डियां आपस में रगड़ खाती हैं और सूजन आती है।'),
      ),
      commonSymptoms: [
        BilingualText(en: 'Morning stiffness in knees or fingers lasting 10 to 15 minutes.', hi: 'सुबह उठने पर घुटनों या उंगलियों में 10-15 मिनट की अकड़न रहना।'),
        BilingualText(en: 'Crackling or crunching sound (crepitus) while climbing stairs.', hi: 'सीढ़ियां चढ़ते या नीचे उतरते समय घुटने से कट-कट की आवाज आना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 A joint suddenly becoming red, hot to touch, and severely swollen.', hi: '🚨 किसी जोड़ का अचानक लाल पड़ जाना, छूने पर बहुत गर्म और सूज जाना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Sit on a chair instead of squatting on the floor to protect knee cartilage.', hi: 'जमीन पर पालथी मारकर बैठने के बजाय कुर्सी का इस्तेमाल करें।'),
        BilingualText(en: 'Practice gentle seated leg extensions to strengthen thigh muscles.', hi: 'कुर्सी पर बैठकर पैरों को सीधा ऊपर उठाने की हल्की कसरत करें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'What safe exercises and knee support braces do you recommend for me?', hi: 'मेरे घुटनों की मजबूती के लिए कौन सी सुरक्षित कसरत सही रहेगी?'),
      ],
    ),

    // 19. OSTEOPOROSIS (BONES)
    HealthCondition(
      id: 'osteoporosis',
      name: BilingualText(en: 'Bone Strength & Fall Protection (Osteoporosis)', hi: 'हड्डियों की कमजोरी (ऑस्टियोपोरोसिस)'),
      organId: 'bones',
      icon: '🛡️',
      severityCategory: 'chronic',
      plainExplanation: BilingualText(
        en: 'Bones lose their internal density and mineral honeycomb structure, becoming brittle and prone to fracture even from a minor slip.',
        hi: 'हड्डियों के अंदर का घनत्व कम हो जाता है और वे कमजोर हो जाती हैं, जिससे मामूली फिसलने पर भी फ्रैक्चर का खतरा रहता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Gradual loss of height over years or stooping posture.', hi: 'सालों में धीरे-धीरे कद कम होना या आगे की तरफ झुककर चलना।'),
        BilingualText(en: 'Sudden back pain caused by a hairline fracture in the spine vertebrae.', hi: 'रीढ़ की हड्डी में अचानक तेज दर्द होना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Inability to stand or bear weight on the leg after a slip (Hip Fracture).', hi: '🚨 फिसलने के बाद पैर पर खड़ा न हो पाना या कूल्हे में तेज दर्द (हिप फ्रैक्चर)।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Ensure adequate sunlight exposure for natural Vitamin D synthesis.', hi: 'सुबह की हल्की धूप में 15 मिनट बैठें ताकि शरीर को विटामिन D मिले।'),
        BilingualText(en: 'Remove loose floor rugs and install bathroom grab bars.', hi: 'घर के फर्श से फिसलने वाले पायदान हटाएं और बाथरूम में हैंड ग्रैब बार लगवाएं।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Should I get a DEXA Bone Mineral Density scan?', hi: 'क्या मुझे अपनी हड्डियों का घनत्व (DEXA Scan) जांच कराना चाहिए?'),
      ],
    ),

    // 20. HEARING LOSS & VERTIGO (ENT)
    HealthCondition(
      id: 'hearing_loss',
      name: BilingualText(en: 'Hearing Care & Balance (Vertigo)', hi: 'सुनने की क्षमता एवं चक्कर आना (वर्टिगो)'),
      organId: 'ent',
      icon: '👂',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'The inner ear contains tiny hair sensors for hearing and fluid canals for balance. Natural aging can reduce high-pitch sounds or cause room-spinning vertigo.',
        hi: 'अंदरूनी कान में सुनने के बारीक सेंसर और संतुलन बनाने वाली नलियां होती हैं। उम्र के साथ आवाज धीमी सुनाई देना या चक्कर आना हो सकता है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Needing the television volume much higher than family members.', hi: 'घर के बाकी सदस्यों की तुलना में टीवी की आवाज बहुत तेज रखने की जरूरत पड़ना।'),
        BilingualText(en: 'Feeling like the room is spinning when turning over in bed.', hi: 'बिस्तर में करवट बदलते समय कमरा गोल-गोल घूमता हुआ महसूस होना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Sudden complete loss of hearing in one ear within a few hours.', hi: '🚨 किसी एक कान से अचानक कुछ ही घंटों में सुनना बिल्कुल बंद हो जाना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Never insert sharp safety pins or cotton buds deep into ear canals.', hi: 'कान के अंदर कभी भी माचिस की तीली या पिन न डालें।'),
        BilingualText(en: 'Modern hearing aids are tiny and dramatically improve quality of life.', hi: 'आधुनिक हियरिंग एड बहुत छोटे और आरामदायक होते हैं।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Can a simple Audiometry hearing test help select the right hearing aid?', hi: 'क्या एक ऑडियोमेट्री जांच से मेरे लिए सही हियरिंग एड चुना जा सकता है?'),
      ],
    ),

    // 21. SKIN AGING & DEHYDRATION (SKIN)
    HealthCondition(
      id: 'skin_aging_dehydration',
      name: BilingualText(en: 'Skin Moisture & Senior Skin Care', hi: 'त्वचा की देखभाल एवं सूखापन'),
      organId: 'skin',
      icon: '🧴',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'As we age, the skin produces less natural protective oil and becomes thinner and easily bruised or itchy.',
        hi: 'उम्र बढ़ने पर त्वचा में प्राकृतिक तेल का बनना कम हो जाता है, जिससे त्वचा पतली, सूखी और खुजलीदार हो जाती है।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Dry, flaky skin and winter itching on arms and lower legs.', hi: 'सर्दियों में हाथों और पिंडलियों पर सफेद पपड़ी और तेज खुजली होना।'),
        BilingualText(en: 'Purple patches (bruises) from minor bumps on forearm skin.', hi: 'हाथों पर हल्की सी चोट लगने पर भी नीले-बैंगनी निशान पड़ जाना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 A mole or dark skin spot that rapidly changes size, shape, or bleeds.', hi: '🚨 किसी तिल या मस्से का आकार तेजी से बदलना या उससे खून रिसना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Apply coconut oil or moisturizer immediately after bathing while skin is damp.', hi: 'नहाने के तुरंत बाद जब त्वचा थोड़ी गीली हो तभी नारियल तेल या मॉइस्चराइजर लगाएं।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Which gentle soap and moisturizing lotion is best for my sensitive skin?', hi: 'मेरी रूखी त्वचा के लिए कौन सा हल्का साबुन और लोशन सही रहेगा?'),
      ],
    ),

    // 22. IMMUNITY & AGE-RELATED FATIGUE (SKIN & WHOLE BODY)
    HealthCondition(
      id: 'immune_fatigue',
      name: BilingualText(en: 'Immune Vitality & Beating Fatigue', hi: 'रोग प्रतिरोधक क्षमता एवं ऊर्जा'),
      organId: 'skin',
      icon: '🛡️',
      severityCategory: 'common',
      plainExplanation: BilingualText(
        en: 'The immune system is like an internal police force. Good sleep, protein-rich food, and daily hydration keep your defense cells alert against infections.',
        hi: 'शरीर की रोग प्रतिरोधक क्षमता भीतरी पुलिस की तरह है। अच्छी नींद, पौष्टिक आहार और पानी इसे मजबूत बनाए रखते हैं।',
      ),
      commonSymptoms: [
        BilingualText(en: 'Feeling constantly tired even after a full night’s rest.', hi: 'पूरी रात सोने के बाद भी दिनभर सुस्ती और कमजोरी महसूस होना।'),
        BilingualText(en: 'Catching seasonal colds and respiratory infections repeatedly.', hi: 'मौसम बदलते ही बार-बार जुकाम और खांसी की चपेट में आना।'),
      ],
      redFlagWarnings: [
        BilingualText(en: '🚨 Unexplained high fever with chills and confusion.', hi: '🚨 बिना किसी कारण के तेज कंपकंपी वाला बुखार और बेहोशी सी छाना।'),
      ],
      precautionsAndHabits: [
        BilingualText(en: 'Include lentils (dal), curd/yogurt, and seasonal fruits daily.', hi: 'रोजाना दाल, दही, दूध और ताजे मौसमी फलों को अपने भोजन में शामिल करें।'),
        BilingualText(en: 'Get 7 to 8 hours of peaceful sleep at night.', hi: 'रात को 7 से 8 घंटे की सुकून भरी नींद अवश्य लें।'),
      ],
      questionsForDoctor: [
        BilingualText(en: 'Should I check my Hemoglobin (Hb) or Vitamin levels for my fatigue?', hi: 'क्या मेरी कमजोरी की जांच के लिए हीमोग्लोबिन (Hb) टेस्ट कराना चाहिए?'),
      ],
    ),
  ];

  // ─── HELPER METHODS ─────────────────────────────────────────────────────────

  static BodyOrgan? getOrganById(String organId) {
    try {
      return organs.firstWhere((o) => o.id == organId);
    } catch (_) {
      return null;
    }
  }

  static HealthCondition? getConditionById(String conditionId) {
    try {
      return conditions.firstWhere((c) => c.id == conditionId);
    } catch (_) {
      return null;
    }
  }

  static List<HealthCondition> getConditionsForOrgan(String organId) {
    return conditions.where((c) => c.organId == organId).toList();
  }

  static List<HealthCondition> search(String query, String langCode) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    return conditions.where((c) {
      final nameEn = c.name.en.toLowerCase();
      final nameHi = c.name.hi.toLowerCase();
      final organ = getOrganById(c.organId);
      final organNameEn = organ?.name.en.toLowerCase() ?? '';
      final organNameHi = organ?.name.hi.toLowerCase() ?? '';

      return nameEn.contains(q) ||
          nameHi.contains(q) ||
          organNameEn.contains(q) ||
          organNameHi.contains(q);
    }).toList();
  }
}
