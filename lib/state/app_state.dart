import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../services/engine.dart';

/// Single source of truth for the app. Every list here maps 1:1 to a Supabase
/// table in supabase/schema.sql — during integration, swap the in-memory
/// mutations for repository calls and keep the same public API.
class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;

  // Preferences
  String lang = 'en';
  bool onboarded = false;
  String userName = 'Preeti Maheshwari';
  String userPhone = '+91 90016 71377';
  String userCity = 'Pratapgarh, Rajasthan';
  String vaultPin = '1234';
  bool ashaMode = false;
  bool abhaLinked = false;
  String abhaNumber = '';
  bool remindersOn = true;

  // Session
  String activeMemberId = 'm1';
  bool vaultUnlocked = false;

  // Data
  final List<FamilyMember> members = List.of(MockData.members);
  final List<MedicalRecord> records = List.of(MockData.records);
  final List<OpinionCase> cases = List.of(MockData.opinionCases);
  final List<Medicine> medicines = List.of(MockData.medicines);
  final List<Appointment> appointments = List.of(MockData.appointments);
  final List<AshaPerson> ashaPeople = List.of(MockData.ashaPeople);
  final Set<String> takenDoses = {}; // medId@HH:mm@yyyy-mm-dd
  final Set<String> dismissedAlerts = {};
  final Map<String, List<String>> customQuestions = {}; // caseId → questions
  final Map<String, Set<int>> unselectedQuestions = {}; // caseId → indexes
  final Set<String> askedQuestions = {}; // "caseId#text"
  final Set<String> visitNotes = {}; // free questions added from records
  final Set<DateTime> periodDays = {};
  DateTime? lmp; // last menstrual period for pregnancy tracking
  final Set<int> ancDone = {};

  AppState() {
    _seedHistory();
  }

  // Seeds believable dose history + cycle data so stats aren't empty.
  void _seedHistory() {
    final today = DateUtils.dateOnly(DateTime.now());
    for (var d = 1; d <= 6; d++) {
      final day = today.subtract(Duration(days: d));
      for (final m in medicines) {
        for (final t in m.times.where((t) => t != 'SOS')) {
          if ((d + m.id.hashCode) % 5 != 0) takenDoses.add(doseKey(m.id, t, day));
        }
      }
    }
    final start = today.subtract(const Duration(days: 3));
    for (var i = 0; i < 5; i++) {
      periodDays.add(start.add(Duration(days: i)));
    }
    final prev = start.subtract(const Duration(days: 41));
    for (var i = 0; i < 5; i++) {
      periodDays.add(prev.add(Duration(days: i)));
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    lang = p.getString('lang') ?? lang;
    onboarded = p.getBool('onboarded') ?? false;
    vaultPin = p.getString('pin') ?? vaultPin;
    userName = p.getString('name') ?? userName;
    userPhone = p.getString('phone') ?? userPhone;
    userCity = p.getString('city') ?? userCity;
    ashaMode = p.getBool('asha') ?? false;
    abhaLinked = p.getBool('abha') ?? false;
    abhaNumber = p.getString('abhaNo') ?? '';
    remindersOn = p.getBool('reminders') ?? true;
    takenDoses.addAll(p.getStringList('doses') ?? const []);
    dismissedAlerts.addAll(p.getStringList('dismissed') ?? const []);
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString('lang', lang);
    p.setBool('onboarded', onboarded);
    p.setString('pin', vaultPin);
    p.setString('name', userName);
    p.setString('phone', userPhone);
    p.setString('city', userCity);
    p.setBool('asha', ashaMode);
    p.setBool('abha', abhaLinked);
    p.setString('abhaNo', abhaNumber);
    p.setBool('reminders', remindersOn);
    p.setStringList('doses', takenDoses.toList());
    p.setStringList('dismissed', dismissedAlerts.toList());
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  // ───────── Getters ─────────
  bool get hi => lang == 'hi';
  FamilyMember get activeMember =>
      members.firstWhere((m) => m.id == activeMemberId, orElse: () => members.first);
  FamilyMember member(String id) =>
      members.firstWhere((m) => m.id == id, orElse: () => members.first);
  MedicalRecord? record(String id) {
    for (final r in records) {
      if (r.id == id) return r;
    }
    return null;
  }

  OpinionCase? caseById(String id) {
    for (final c in cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<MedicalRecord> recordsFor(String memberId, {bool includePrivate = false}) =>
      records
          .where((r) => r.memberId == memberId && (includePrivate || !r.isPrivate))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Medicine> medsFor(String memberId) =>
      medicines.where((m) => m.memberId == memberId).toList();

  List<Trend> trendsFor(String memberId) =>
      MockData.trends.where((t) => t.memberId == memberId).toList();

  List<Appointment> upcoming({String? memberId}) {
    final now = DateTime.now().subtract(const Duration(hours: 2));
    return appointments
        .where((a) => a.when.isAfter(now) && (memberId == null || a.memberId == memberId))
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
  }

  List<OpinionCase> casesFor(String memberId) =>
      cases.where((c) => c.memberId == memberId).toList();

  /// Alerts are derived from data (not stored), exactly like the backend
  /// edge function will produce them.
  List<HealthAlert> get alerts =>
      Engine.alerts(this).where((a) => !dismissedAlerts.contains(a.id)).toList();

  // ───────── Doses ─────────
  static String doseKey(String medId, String time, DateTime day) =>
      '$medId@$time@${day.year}-${day.month}-${day.day}';

  bool isTaken(String medId, String time, [DateTime? day]) =>
      takenDoses.contains(doseKey(medId, time, day ?? DateTime.now()));

  void toggleDose(String medId, String time) {
    final k = doseKey(medId, time, DateTime.now());
    takenDoses.contains(k) ? takenDoses.remove(k) : takenDoses.add(k);
    _changed();
  }

  /// Fraction of scheduled doses taken over the last [days] days (excl. today).
  double adherence(String memberId, {int days = 7}) {
    var due = 0, done = 0;
    final today = DateUtils.dateOnly(DateTime.now());
    for (var d = 1; d <= days; d++) {
      final day = today.subtract(Duration(days: d));
      for (final m in medsFor(memberId)) {
        for (final t in m.times.where((t) => t != 'SOS')) {
          due++;
          if (takenDoses.contains(doseKey(m.id, t, day))) done++;
        }
      }
    }
    return due == 0 ? 1 : done / due;
  }

  // ───────── Mutations ─────────
  void setLang(String l) {
    lang = l;
    _changed();
  }

  void finishOnboarding() {
    onboarded = true;
    _changed();
  }

  void resetOnboarding() {
    onboarded = false;
    _changed();
  }

  void setMember(String id) {
    activeMemberId = id;
    notifyListeners();
  }

  void updateProfile({String? name, String? phone, String? city}) {
    userName = name ?? userName;
    userPhone = phone ?? userPhone;
    userCity = city ?? userCity;
    final i = members.indexWhere((m) => m.relation == 'Self');
    if (i >= 0 && name != null) members[i] = members[i].copyWith(name: name);
    _changed();
  }

  void toggleAsha(bool v) {
    ashaMode = v;
    _changed();
  }

  void setReminders(bool v) {
    remindersOn = v;
    _changed();
  }

  bool unlockVault(String pin) {
    vaultUnlocked = pin == vaultPin;
    notifyListeners();
    return vaultUnlocked;
  }

  void lockVault() {
    vaultUnlocked = false;
    notifyListeners();
  }

  void changePin(String pin) {
    vaultPin = pin;
    _changed();
  }

  void linkAbha(String number) {
    abhaLinked = true;
    abhaNumber = number;
    _changed();
  }

  void unlinkAbha() {
    abhaLinked = false;
    abhaNumber = '';
    _changed();
  }

  // Members
  FamilyMember addMember({
    required String name,
    required String relation,
    required int age,
    required String gender,
    required String bloodGroup,
    List<String> allergies = const [],
    List<String> conditions = const [],
    String emergencyContact = '',
  }) {
    final m = FamilyMember(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      relation: relation,
      age: age,
      gender: gender,
      bloodGroup: bloodGroup,
      color: MockData.memberPalette[members.length % MockData.memberPalette.length],
      allergies: allergies,
      conditions: conditions,
      emergencyContact: emergencyContact,
    );
    members.add(m);
    activeMemberId = m.id;
    _changed();
    return m;
  }

  void updateMember(FamilyMember m) {
    final i = members.indexWhere((x) => x.id == m.id);
    if (i >= 0) members[i] = m;
    _changed();
  }

  void removeMember(String id) {
    if (members.length <= 1) return;
    members.removeWhere((m) => m.id == id);
    records.removeWhere((r) => r.memberId == id);
    medicines.removeWhere((m) => m.memberId == id);
    appointments.removeWhere((a) => a.memberId == id);
    cases.removeWhere((c) => c.memberId == id);
    if (activeMemberId == id) activeMemberId = members.first.id;
    _changed();
  }

  // Records
  void addRecord(MedicalRecord r) {
    records.insert(0, r);
    _changed();
  }

  void updateRecord(MedicalRecord r) {
    final i = records.indexWhere((x) => x.id == r.id);
    if (i >= 0) records[i] = r;
    _changed();
  }

  void deleteRecord(String id) {
    records.removeWhere((r) => r.id == id);
    _changed();
  }

  // Cases & questions
  void addCase(OpinionCase c) {
    cases.insert(0, c);
    _changed();
  }

  void deleteCase(String id) {
    cases.removeWhere((c) => c.id == id);
    _changed();
  }

  List<String> questionsFor(String caseId) {
    final c = caseById(caseId);
    return [...?c?.questions, ...?customQuestions[caseId]];
  }

  bool isQuestionSelected(String caseId, int i) =>
      !(unselectedQuestions[caseId]?.contains(i) ?? false);

  void toggleQuestion(String caseId, int i) {
    final s = unselectedQuestions.putIfAbsent(caseId, () => {});
    s.contains(i) ? s.remove(i) : s.add(i);
    notifyListeners();
  }

  void addQuestion(String caseId, String q) {
    customQuestions.putIfAbsent(caseId, () => []).add(q);
    notifyListeners();
  }

  void markAsked(String caseId, String q) {
    final k = '$caseId#$q';
    askedQuestions.contains(k) ? askedQuestions.remove(k) : askedQuestions.add(k);
    notifyListeners();
  }

  void addVisitNote(String q) {
    visitNotes.add(q);
    notifyListeners();
  }

  void removeVisitNote(String q) {
    visitNotes.remove(q);
    notifyListeners();
  }

  // Medicines
  void addMedicine(Medicine m) {
    medicines.add(m);
    _changed();
  }

  void deleteMedicine(String id) {
    medicines.removeWhere((m) => m.id == id);
    _changed();
  }

  // Appointments
  void addAppointment(Appointment a) {
    appointments.add(a);
    _changed();
  }

  void deleteAppointment(String id) {
    appointments.removeWhere((a) => a.id == id);
    _changed();
  }

  // Alerts
  void dismissAlert(String id) {
    dismissedAlerts.add(id);
    _changed();
  }

  void restoreAlerts() {
    dismissedAlerts.clear();
    _changed();
  }

  // Women's health
  void togglePeriodDay(DateTime d) {
    final day = DateUtils.dateOnly(d);
    periodDays.contains(day) ? periodDays.remove(day) : periodDays.add(day);
    notifyListeners();
  }

  void setLmp(DateTime? d) {
    lmp = d;
    if (d == null) ancDone.clear();
    notifyListeners();
  }

  void toggleAnc(int i) {
    ancDone.contains(i) ? ancDone.remove(i) : ancDone.add(i);
    notifyListeners();
  }

  // ASHA
  void addAshaPerson(AshaPerson p) {
    ashaPeople.insert(0, p);
    notifyListeners();
  }

  void updateAshaPerson(AshaPerson p) {
    final i = ashaPeople.indexWhere((x) => x.id == p.id);
    if (i >= 0) ashaPeople[i] = p;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

const _strings = <String, Map<String, String>>{
  'home': {'en': 'Home', 'hi': 'होम'},
  'records': {'en': 'Records', 'hi': 'रिकॉर्ड'},
  'compare': {'en': 'Compare', 'hi': 'तुलना'},
  'timeline': {'en': 'Journey', 'hi': 'सफ़र'},
  'profile': {'en': 'Profile', 'hi': 'प्रोफ़ाइल'},
  'greet': {'en': 'Namaste', 'hi': 'नमस्ते'},
  'family_health': {'en': 'Your family\'s health', 'hi': 'आपके परिवार की सेहत'},
  'needs_attention': {'en': 'Needs attention', 'hi': 'ध्यान दें'},
  'all_clear': {'en': 'All clear — nothing needs attention', 'hi': 'सब ठीक है — कुछ ज़रूरी नहीं'},
  'quick': {'en': 'What would you like to do?', 'hi': 'आप क्या करना चाहेंगे?'},
  'today_meds': {'en': 'Today\'s medicines', 'hi': 'आज की दवाइयाँ'},
  'upcoming': {'en': 'Upcoming visits', 'hi': 'आगामी मुलाक़ातें'},
  'add_record': {'en': 'Add a record', 'hi': 'रिकॉर्ड जोड़ें'},
  'simplified': {'en': 'In simple words', 'hi': 'आसान भाषा में'},
  'original': {'en': 'Original', 'hi': 'मूल'},
  'listen': {'en': 'Listen', 'hi': 'सुनें'},
  'stop': {'en': 'Stop', 'hi': 'रोकें'},
  'ask': {'en': 'Ask MedVerse', 'hi': 'MedVerse से पूछें'},
  'what_means': {'en': 'What this means', 'hi': 'इसका मतलब'},
  'each_value': {'en': 'Each value, explained', 'hi': 'हर जाँच का मतलब'},
  'see_original': {'en': 'See in original', 'hi': 'मूल में देखें'},
  'compare_opinions': {'en': 'Compare\nopinions', 'hi': 'राय की\nतुलना'},
  'lab_trends': {'en': 'Lab\ntrends', 'hi': 'जाँच का\nरुझान'},
  'medicines': {'en': 'Medicines', 'hi': 'दवाइयाँ'},
  'health_card': {'en': 'Health\ncard', 'hi': 'हेल्थ\nकार्ड'},
  'ask_hindi': {'en': 'Ask by\nvoice', 'hi': 'बोलकर\nपूछें'},
  'womens': {'en': 'Women\'s\nhealth', 'hi': 'महिला\nस्वास्थ्य'},
  'visits': {'en': 'Visits', 'hi': 'मुलाक़ातें'},
  'emergency': {'en': 'Emergency', 'hi': 'आपातकाल'},
  'disclaimer': {
    'en': 'MedVerse explains — it does not diagnose. Always confirm with your doctor.',
    'hi': 'MedVerse समझाता है — निदान नहीं करता। हमेशा अपने डॉक्टर से पुष्टि करें।'
  },
};

extension Tr on BuildContext {
  String tr(String key) {
    final s = AppScope.of(this);
    return _strings[key]?[s.lang] ?? _strings[key]?['en'] ?? key;
  }
}
