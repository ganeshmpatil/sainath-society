export const residents = [
  { id: 1, name: 'राजेश कुमार', flat: 'A-101', wing: 'A', phone: '9876543210', email: 'rajesh@email.com', role: 'अध्यक्ष', status: 'मालक', parkingSlot: 'P-01' },
  { id: 2, name: 'प्रिया शर्मा', flat: 'A-102', wing: 'A', phone: '9876543211', email: 'priya@email.com', role: 'सचिव', status: 'मालक', parkingSlot: 'P-02' },
  { id: 3, name: 'अमित पाटील', flat: 'A-103', wing: 'A', phone: '9876543212', email: 'amit@email.com', role: 'खजिनदार', status: 'मालक', parkingSlot: 'P-03' },
  { id: 4, name: 'सुनीता देसाई', flat: 'B-201', wing: 'B', phone: '9876543213', email: 'sunita@email.com', role: 'सदस्य', status: 'भाडेकरू', parkingSlot: 'P-04' },
  { id: 5, name: 'विक्रम सिंह', flat: 'B-202', wing: 'B', phone: '9876543214', email: 'vikram@email.com', role: 'सदस्य', status: 'मालक', parkingSlot: 'P-05' },
  { id: 6, name: 'मीरा जोशी', flat: 'B-203', wing: 'B', phone: '9876543215', email: 'meera@email.com', role: 'सदस्य', status: 'मालक', parkingSlot: null },
  { id: 7, name: 'करण मेहता', flat: 'C-301', wing: 'C', phone: '9876543216', email: 'karan@email.com', role: 'सदस्य', status: 'भाडेकरू', parkingSlot: 'P-06' },
  { id: 8, name: 'अंजली रेड्डी', flat: 'C-302', wing: 'C', phone: '9876543217', email: 'anjali@email.com', role: 'सदस्य', status: 'मालक', parkingSlot: 'P-07' },
];

export const flatDetails = [
  {
    id: 1,
    flat: 'A-101',
    wing: 'A',
    floor: 1,
    area: '1200 चौ.फूट',
    ownerName: 'राजेश कुमार',
    shareCertNo: 'SC-001',
    nomineeName: 'सुमन कुमार',
    nomineeRelation: 'पत्नी',
    purchaseDate: '2018-05-15',
    documents: ['विक्री करार', 'NOC', 'शेअर प्रमाणपत्र', 'सोसायटी नोंदणी']
  },
  {
    id: 2,
    flat: 'A-102',
    wing: 'A',
    floor: 1,
    area: '1200 चौ.फूट',
    ownerName: 'प्रिया शर्मा',
    shareCertNo: 'SC-002',
    nomineeName: 'रवी शर्मा',
    nomineeRelation: 'पती',
    purchaseDate: '2019-02-20',
    documents: ['विक्री करार', 'NOC', 'शेअर प्रमाणपत्र']
  },
  {
    id: 3,
    flat: 'B-201',
    wing: 'B',
    floor: 2,
    area: '1400 चौ.फूट',
    ownerName: 'मोहन देसाई',
    shareCertNo: 'SC-003',
    nomineeName: 'सुनीता देसाई',
    nomineeRelation: 'पत्नी',
    purchaseDate: '2017-08-10',
    documents: ['विक्री करार', 'NOC', 'शेअर प्रमाणपत्र', 'भाडे करार']
  },
];

export const grievances = [
  { id: 1, flat: 'A-101', subject: 'बाथरूममध्ये पाणी गळती', description: 'छतातून सतत पाणी गळत आहे', status: 'Open', priority: 'High', createdAt: '2024-02-20', assignedTo: 'देखभाल टीम' },
  { id: 2, flat: 'B-202', subject: 'लिफ्ट व्यवस्थित काम करत नाही', description: 'लिफ्ट कधीकधी मजल्यांच्या मध्ये थांबते', status: 'In Progress', priority: 'Critical', createdAt: '2024-02-18', assignedTo: 'लिफ्ट कंत्राटदार' },
  { id: 3, flat: 'C-301', subject: 'पार्किंग जागेवर अतिक्रमण', description: 'शेजारी माझ्या वाटप केलेल्या जागेत पार्क करतात', status: 'Resolved', priority: 'Medium', createdAt: '2024-02-10', assignedTo: 'सचिव' },
  { id: 4, flat: 'A-103', subject: 'आवाजाची तक्रार', description: 'A-104 मधून रात्री उशिरा बांधकामाचा आवाज', status: 'Open', priority: 'Low', createdAt: '2024-02-22', assignedTo: 'अध्यक्ष' },
];

export const notices = [
  { id: 1, title: 'पाण्याची टाकी स्वच्छता', content: '25 फेब्रुवारी रोजी सकाळी 10 ते संध्याकाळी 4 वाजेपर्यंत टाकी स्वच्छतेसाठी पाणी पुरवठा खंडित राहील.', date: '2024-02-20', type: 'देखभाल', priority: 'High' },
  { id: 2, title: 'वार्षिक सर्वसाधारण सभा', content: '15 मार्च 2024 रोजी संध्याकाळी 6 वाजता सोसायटी हॉलमध्ये AGM आयोजित. सर्व सदस्यांनी उपस्थित राहावे.', date: '2024-02-18', type: 'बैठक', priority: 'Critical' },
  { id: 3, title: 'होळी उत्सव', content: '25 मार्च रोजी सोसायटी होळी उत्सव. कृपया तुमच्या कुटुंबातील सदस्यांची नोंदणी करा.', date: '2024-02-22', type: 'कार्यक्रम', priority: 'Normal' },
  { id: 4, title: 'देखभाल थकबाकी स्मरणपत्र', content: 'थकबाकी असलेल्या सदस्यांनी दंड टाळण्यासाठी महिनाअखेरपर्यंत रक्कम भरावी.', date: '2024-02-15', type: 'आर्थिक', priority: 'High' },
];

export const decisions = [
  { id: 1, title: 'CCTV बसवणे', description: 'सर्व विंगमध्ये 16 CCTV कॅमेरे बसवण्यास मान्यता', date: '2024-02-01', meetingType: 'समिती बैठक', votesFor: 8, votesAgainst: 0, status: 'अंमलात आणले' },
  { id: 2, title: 'सुरक्षा रक्षकांचा पगारवाढ', description: 'सुरक्षा कर्मचाऱ्यांना 10% पगारवाढीस मान्यता', date: '2024-01-15', meetingType: 'AGM', votesFor: 45, votesAgainst: 5, status: 'अंमलात आणले' },
  { id: 3, title: 'सौर पॅनेल बसवणे', description: 'सामायिक क्षेत्रातील दिव्यांसाठी सौर पॅनेल बसवण्याचा प्रस्ताव', date: '2024-02-10', meetingType: 'SGM', votesFor: 30, votesAgainst: 20, status: 'प्रलंबित' },
  { id: 4, title: 'बाग नूतनीकरण', description: 'नवीन झाडे आणि बसण्याच्या जागेसह सोसायटी बागेचे नूतनीकरण', date: '2024-02-05', meetingType: 'समिती बैठक', votesFor: 7, votesAgainst: 1, status: 'प्रगतीपथावर' },
];

export const suggestions = [
  { id: 1, flat: 'A-102', title: 'EV चार्जिंग स्टेशन बसवा', description: 'इलेक्ट्रिक वाहनांच्या वाढत्या संख्येमुळे पार्किंगमध्ये EV चार्जिंग स्टेशन बसवावे', date: '2024-02-20', upvotes: 25, status: 'विचाराधीन' },
  { id: 2, flat: 'B-201', title: 'साप्ताहिक योग वर्ग', description: 'दर रविवारी सकाळी छतावर योग वर्ग आयोजित करावे', date: '2024-02-18', upvotes: 18, status: 'मंजूर' },
  { id: 3, flat: 'C-302', title: 'चांगले कचरा वर्गीकरण', description: 'ओला आणि कोरडा कचरा वेगळे करण्यासाठी अधिक कचरापेट्या हव्यात', date: '2024-02-15', upvotes: 32, status: 'अंमलात आणले' },
  { id: 4, flat: 'A-103', title: 'अतिथी पार्किंग व्यवस्थापन', description: 'पासेससह अभ्यागत पार्किंग व्यवस्थापन प्रणाली लागू करावी', date: '2024-02-22', upvotes: 12, status: 'विचाराधीन' },
];

export const financials = {
  summary: {
    totalCollection: 2450000,
    pendingDues: 185000,
    totalExpenses: 1850000,
    balance: 600000,
    corpusFund: 1500000,
  },
  income: [
    { id: 1, category: 'देखभाल शुल्क', amount: 1800000, month: 'फेब्रुवारी 2024' },
    { id: 2, category: 'पार्किंग शुल्क', amount: 150000, month: 'फेब्रुवारी 2024' },
    { id: 3, category: 'हॉल बुकिंग', amount: 45000, month: 'फेब्रुवारी 2024' },
    { id: 4, category: 'व्याज उत्पन्न', amount: 55000, month: 'फेब्रुवारी 2024' },
    { id: 5, category: 'हस्तांतरण शुल्क', amount: 100000, month: 'फेब्रुवारी 2024' },
  ],
  expenses: [
    { id: 1, category: 'सुरक्षा सेवा', amount: 180000, month: 'फेब्रुवारी 2024' },
    { id: 2, category: 'स्वच्छता', amount: 120000, month: 'फेब्रुवारी 2024' },
    { id: 3, category: 'वीज (सामायिक)', amount: 85000, month: 'फेब्रुवारी 2024' },
    { id: 4, category: 'पाणी शुल्क', amount: 45000, month: 'फेब्रुवारी 2024' },
    { id: 5, category: 'लिफ्ट देखभाल', amount: 35000, month: 'फेब्रुवारी 2024' },
    { id: 6, category: 'बाग देखभाल', amount: 25000, month: 'फेब्रुवारी 2024' },
    { id: 7, category: 'दुरुस्ती आणि देखभाल', amount: 65000, month: 'फेब्रुवारी 2024' },
    { id: 8, category: 'प्रशासकीय खर्च', amount: 30000, month: 'फेब्रुवारी 2024' },
  ],
  pendingMembers: [
    { flat: 'A-103', name: 'अमित पाटील', amount: 25000, months: 2 },
    { flat: 'B-203', name: 'मीरा जोशी', amount: 37500, months: 3 },
    { flat: 'C-301', name: 'करण मेहता', amount: 12500, months: 1 },
  ],
};

export const vehicles = [
  { id: 1, flat: 'A-101', type: 'कार', make: 'Honda City', number: 'MH-02-AB-1234', parkingSlot: 'P-01', stickerNo: 'STK-001' },
  { id: 2, flat: 'A-101', type: 'दुचाकी', make: 'Honda Activa', number: 'MH-02-CD-5678', parkingSlot: 'TW-01', stickerNo: 'STK-002' },
  { id: 3, flat: 'A-102', type: 'कार', make: 'Maruti Swift', number: 'MH-02-EF-9012', parkingSlot: 'P-02', stickerNo: 'STK-003' },
  { id: 4, flat: 'B-201', type: 'कार', make: 'Hyundai Creta', number: 'MH-02-GH-3456', parkingSlot: 'P-04', stickerNo: 'STK-004' },
  { id: 5, flat: 'B-202', type: 'कार', make: 'Toyota Innova', number: 'MH-02-IJ-7890', parkingSlot: 'P-05', stickerNo: 'STK-005' },
  { id: 6, flat: 'C-302', type: 'दुचाकी', make: 'Royal Enfield', number: 'MH-02-KL-1234', parkingSlot: 'TW-05', stickerNo: 'STK-006' },
];

export const polls = [
  { id: 1, title: 'सोसायटी कार्यक्रमांसाठी पसंतीची वेळ', options: [{ text: 'सकाळी (9-11)', votes: 15 }, { text: 'संध्याकाळी (5-7)', votes: 35 }, { text: 'वीकेंड दुपारी', votes: 20 }], endDate: '2024-03-01', status: 'Active', totalVoters: 70 },
  { id: 2, title: 'नवीन सुरक्षा एजन्सी निवड', options: [{ text: 'सिक्योरगार्ड सर्व्हिसेस', votes: 28 }, { text: 'सेफहोम सिक्युरिटी', votes: 32 }, { text: 'वॉचडॉग सर्व्हिसेस', votes: 10 }], endDate: '2024-02-25', status: 'Closed', totalVoters: 70 },
  { id: 3, title: 'दिवाळी उत्सव बजेट', options: [{ text: '₹ 50,000', votes: 12 }, { text: '₹ 75,000', votes: 25 }, { text: '₹ 1,00,000', votes: 18 }], endDate: '2024-03-15', status: 'Active', totalVoters: 55 },
];

export const meetings = [
  { id: 1, type: 'AGM', title: 'वार्षिक सर्वसाधारण सभा 2024', date: '2024-03-15', time: 'संध्याकाळी 6:00', venue: 'सोसायटी हॉल', agenda: ['आर्थिक अहवाल 2023-24', 'समिती निवडणूक', 'बजेट मान्यता', 'सदस्य सूचना'], status: 'Scheduled', quorum: 51, expectedAttendees: 60 },
  { id: 2, type: 'SGM', title: 'विशेष सर्वसाधारण सभा - सौर प्रकल्प', date: '2024-02-28', time: 'रात्री 7:00', venue: 'सोसायटी हॉल', agenda: ['सौर पॅनेल बसवण्यास मान्यता', 'विक्रेता निवड', 'खर्च वाटप'], status: 'Scheduled', quorum: 51, expectedAttendees: 45 },
  { id: 3, type: 'समिती', title: 'मासिक समिती बैठक', date: '2024-02-20', time: 'रात्री 8:00', venue: 'कार्यालय', agenda: ['प्रलंबित तक्रारी', 'देखभाल समस्या', 'आगामी कार्यक्रम'], status: 'Completed', quorum: 5, expectedAttendees: 8 },
];

export const pendingTasks = [
  { id: 1, title: 'अग्निशमन NOC नूतनीकरण', dueDate: '2024-03-31', assignedTo: 'सचिव', priority: 'High', status: 'In Progress', category: 'अनुपालन' },
  { id: 2, title: 'वार्षिक लिफ्ट तपासणी', dueDate: '2024-04-15', assignedTo: 'देखभाल प्रमुख', priority: 'High', status: 'Pending', category: 'सुरक्षा' },
  { id: 3, title: 'पाण्याची टाकी स्वच्छता', dueDate: '2024-02-25', assignedTo: 'देखभाल प्रमुख', priority: 'Medium', status: 'Scheduled', category: 'देखभाल' },
  { id: 4, title: 'विमा नूतनीकरण', dueDate: '2024-05-01', assignedTo: 'खजिनदार', priority: 'High', status: 'Pending', category: 'अनुपालन' },
  { id: 5, title: 'कीटक नियंत्रण', dueDate: '2024-03-10', assignedTo: 'देखभाल प्रमुख', priority: 'Medium', status: 'Scheduled', category: 'देखभाल' },
  { id: 6, title: 'सदस्य निर्देशिका अद्यतन', dueDate: '2024-03-01', assignedTo: 'सचिव', priority: 'Low', status: 'In Progress', category: 'प्रशासकीय' },
];

export const inventory = [
  { id: 1, item: 'प्लास्टिक खुर्च्या', quantity: 100, location: 'हॉल स्टोअर रूम', condition: 'चांगले', lastChecked: '2024-02-01' },
  { id: 2, item: 'फोल्डिंग टेबल', quantity: 20, location: 'हॉल स्टोअर रूम', condition: 'चांगले', lastChecked: '2024-02-01' },
  { id: 3, item: 'बाग साधने सेट', quantity: 5, location: 'बाग शेड', condition: 'ठीक', lastChecked: '2024-01-15' },
  { id: 4, item: 'अग्निशामक यंत्र', quantity: 24, location: 'सर्व मजले', condition: 'चांगले', lastChecked: '2024-02-10' },
  { id: 5, item: 'पाणी पंप', quantity: 4, location: 'पंप रूम', condition: 'चांगले', lastChecked: '2024-02-05' },
  { id: 6, item: 'जनरेटर', quantity: 2, location: 'तळघर', condition: 'चांगले', lastChecked: '2024-01-20' },
  { id: 7, item: 'CCTV कॅमेरे', quantity: 16, location: 'सर्व क्षेत्रे', condition: 'चांगले', lastChecked: '2024-02-15' },
  { id: 8, item: 'स्वच्छता साधने', quantity: 10, location: 'स्टोअर रूम', condition: 'ठीक', lastChecked: '2024-02-01' },
];

export const hallBookings = [
  { id: 1, flat: 'A-102', purpose: 'वाढदिवस पार्टी', date: '2024-03-02', timeSlot: 'दुपारी 4:00 - रात्री 10:00', guests: 50, status: 'Confirmed', amount: 5000, deposit: 2000 },
  { id: 2, flat: 'B-201', purpose: 'साखरपुडा समारंभ', date: '2024-03-10', timeSlot: 'सकाळी 11:00 - दुपारी 4:00', guests: 100, status: 'Confirmed', amount: 8000, deposit: 3000 },
  { id: 3, flat: 'C-301', purpose: 'किटी पार्टी', date: '2024-03-05', timeSlot: 'दुपारी 3:00 - संध्याकाळी 7:00', guests: 25, status: 'Pending', amount: 3000, deposit: 1000 },
  { id: 4, flat: 'A-103', purpose: 'कौटुंबिक मेळावा', date: '2024-03-15', timeSlot: 'संध्याकाळी 6:00 - रात्री 11:00', guests: 40, status: 'Confirmed', amount: 5000, deposit: 2000 },
];

export const moveInOut = [
  { id: 1, flat: 'B-201', type: 'आगमन', tenantName: 'सुनीता देसाई', date: '2024-02-01', ownerName: 'मोहन देसाई', securityDeposit: 50000, agreementEndDate: '2025-01-31', status: 'पूर्ण', policeVerification: 'पूर्ण' },
  { id: 2, flat: 'C-301', type: 'आगमन', tenantName: 'करण मेहता', date: '2024-01-15', ownerName: 'सुरेश गुप्ता', securityDeposit: 60000, agreementEndDate: '2025-01-14', status: 'पूर्ण', policeVerification: 'पूर्ण' },
  { id: 3, flat: 'A-104', type: 'निर्गमन', tenantName: 'रोहित वर्मा', date: '2024-02-28', ownerName: 'कविता शाह', securityDeposit: 45000, agreementEndDate: '2024-02-28', status: 'प्रगतीपथावर', policeVerification: 'लागू नाही' },
  { id: 4, flat: 'B-204', type: 'आगमन', tenantName: 'नेहा कपूर', date: '2024-03-01', ownerName: 'अनिल गुप्ता', securityDeposit: 55000, agreementEndDate: '2026-02-28', status: 'प्रलंबित', policeVerification: 'प्रलंबित' },
];

export const bylaws = [
  { id: 1, section: 'सदस्यत्व', title: 'सदस्यत्व पात्रता', content: 'सोसायटीमध्ये फ्लॅट मालकी असलेली कोणतीही व्यक्ती सदस्यत्वासाठी पात्र आहे. सदस्यत्व हस्तांतरणासाठी सोसायटीची NOC आवश्यक आहे.' },
  { id: 2, section: 'सदस्यत्व', title: 'मतदान अधिकार', content: 'प्रत्येक फ्लॅटला एक मत आहे. संयुक्त मालकीच्या बाबतीत, फक्त एक सदस्य मतदानाचा अधिकार वापरू शकतो.' },
  { id: 3, section: 'देखभाल', title: 'थकबाकी भरणा', content: 'देखभाल शुल्क दर महिन्याच्या 10 तारखेपर्यंत देय आहे. विलंबित भरण्यावर 18% वार्षिक व्याज लागू.' },
  { id: 4, section: 'देखभाल', title: 'थकबाकीसाठी दंड', content: '3 महिन्यांपेक्षा जास्त काळ थकबाकी असलेल्या सदस्यांच्या सामायिक सुविधा वापर रद्द केल्या जाऊ शकतात.' },
  { id: 5, section: 'सामान्य', title: 'पार्किंग वाटप', content: 'फ्लॅट मालकीवर आधारित पार्किंग स्लॉट वाटप. 2BHK साठी एक स्लॉट, 3BHK आणि त्यापुढे दोन स्लॉट.' },
  { id: 6, section: 'सामान्य', title: 'पाळीव प्राणी धोरण', content: 'पाळीव प्राण्यांना परवानगी आहे परंतु सामायिक क्षेत्रात पट्ट्याने बांधलेले असावे. पाळीव प्राणी मालक स्वच्छतेसाठी जबाबदार आहेत.' },
  { id: 7, section: 'सामान्य', title: 'नूतनीकरण नियम', content: 'अंतर्गत नूतनीकरणासाठी पूर्व मान्यता आवश्यक. कामाचे तास फक्त आठवड्याच्या दिवशी सकाळी 9 ते संध्याकाळी 6.' },
  { id: 8, section: 'बैठका', title: 'AGM आवश्यकता', content: 'आर्थिक वर्ष संपल्यानंतर 6 महिन्यांच्या आत AGM आयोजित करणे आवश्यक. गणसंख्या एकूण सदस्यांच्या 51%.' },
];

export const currentUser = {
  id: 1,
  name: 'राजेश कुमार',
  flat: 'A-101',
  role: 'अध्यक्ष',
  email: 'rajesh@email.com',
  phone: '9876543210',
  isAdmin: true,
};
