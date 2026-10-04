import '../data/models.dart';
import '../state/app_state.dart';

/// On-device logic that mirrors the planned Supabase edge functions:
///   alerts()   → `process-record` alert rules
///   extract()  → OCR + LLM extraction (static templates for now)
///   compare()  → `compare-opinions`
///   answer()   → `ask` (grounded in the user's own records)
class Engine {
  // ───────────────────────── Alerts ─────────────────────────
  static List<HealthAlert> alerts(AppState s) {
    final out = <HealthAlert>[];
    final now = DateTime.now();

    for (final r in s.records.where((r) => !r.isPrivate)) {
      for (final p in r.params.where((p) => p.status == ParamStatus.critical)) {
        out.add(HealthAlert(
          id: 'crit-${r.id}-${p.name}',
          memberId: r.memberId,
          kind: AlertKind.critical,
          title: '${p.name} is very ${p.numeric > p.high ? 'high' : 'low'} (${p.value})',
          body: 'This level should be seen by a doctor today. Tap to see the report.',
          cta: 'View report',
          recordId: r.id,
        ));
      }
    }

    // Duplicate tests: a prescription orders a test already done in last 90 days.
    for (final rx in s.records.where((r) => r.type == RecordType.prescription)) {
      final orders = [
        ...rx.originalLines
            .where((l) => l.toLowerCase().startsWith('inv'))
            .map((l) => l.substring(l.indexOf(':') + 1).trim()),
        ...rx.orderedTests,
      ];
      for (final o in orders) {
        final earlier = s.records.where((e) =>
            e.memberId == rx.memberId &&
            e.id != rx.id &&
            !e.date.isAfter(rx.date) &&
            rx.date.difference(e.date).inDays <= 90 &&
            _similar(o, e.title));
        if (earlier.isNotEmpty) {
          final e = earlier.first;
          out.add(HealthAlert(
            id: 'dup-${rx.id}-${e.id}',
            memberId: rx.memberId,
            kind: AlertKind.duplicateTest,
            title: '${e.title.split('(').first.trim()} already done on ${_d(e.date)}',
            body:
                '${rx.doctor} ordered "$o". Show the earlier report first — it may save money and a trip.',
            cta: 'Show earlier report',
            recordId: e.id,
          ));
        }
      }
    }

    for (final t in s.trendsForAll) {
      final last = t.points.last.value;
      final first = t.points.first.value;
      final outside = last < t.low || last > t.high;
      final worsening = (last < t.low && last < first) || (last > t.high && last > first);
      if (outside && worsening && t.points.length >= 3) {
        out.add(HealthAlert(
          id: 'trend-${t.memberId}-${t.name}',
          memberId: t.memberId,
          kind: AlertKind.trend,
          title: '${t.name} ${last < first ? 'falling' : 'rising'} for ${_months(t.points.first.date, t.points.last.date)} months',
          body: '$first → $last ${t.unit} across ${t.points.map((p) => p.lab).toSet().length} labs. Worth raising at your next visit.',
          cta: 'See trend',
        ));
      }
    }

    for (final m in s.members) {
      final byClass = <String, List<Medicine>>{};
      for (final med in s.medsFor(m.id).where((x) => x.drugClass.isNotEmpty)) {
        byClass.putIfAbsent(med.drugClass, () => []).add(med);
      }
      byClass.forEach((cls, list) {
        if (list.length >= 2) {
          out.add(HealthAlert(
            id: 'overlap-${m.id}-$cls',
            memberId: m.id,
            kind: AlertKind.drugOverlap,
            title: 'Two $cls medicines from different doctors',
            body:
                '${list.map((x) => '${x.name.split(' ').first} (${x.prescribedBy})').join(' and ')}. Ask a doctor which one to keep.',
            cta: 'See medicines',
          ));
        }
      });
      for (final med in s.medsFor(m.id).where((x) => x.daysLeft <= 5)) {
        out.add(HealthAlert(
          id: 'refill-${med.id}',
          memberId: m.id,
          kind: AlertKind.refill,
          title: '${med.name} runs out in ${med.daysLeft} days',
          body: 'Get a refill or ask ${med.prescribedBy.split('&').first.trim()} whether to continue.',
          cta: 'See medicines',
        ));
      }
    }

    for (final a in s.upcoming()) {
      final days = a.when.difference(now).inHours / 24;
      if (days <= 3) {
        out.add(HealthAlert(
          id: 'visit-${a.id}',
          memberId: a.memberId,
          kind: AlertKind.visit,
          title: 'Visit ${days < 1 ? 'today' : days < 2 ? 'tomorrow' : 'in ${days.ceil()} days'}: ${a.doctor}',
          body: '${a.purpose} · ${a.place}',
          cta: 'Prepare for visit',
        ));
      }
    }

    const order = {
      AlertKind.critical: 0,
      AlertKind.visit: 1,
      AlertKind.drugOverlap: 2,
      AlertKind.duplicateTest: 3,
      AlertKind.trend: 4,
      AlertKind.refill: 5,
    };
    out.sort((a, b) => order[a.kind]!.compareTo(order[b.kind]!));
    return out;
  }

  static bool _similar(String a, String b) {
    const stop = {'both', 'the', 'and', 'of', 'standing', 'ap', 'lat', 'lateral', 'test'};
    Set<String> words(String s) => s
        .toLowerCase()
        .replaceAll('x-ray', 'xray')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(' ')
        .map((w) => w.endsWith('s') ? w.substring(0, w.length - 1) : w)
        .where((w) => w.length > 2 && !stop.contains(w))
        .toSet();
    return words(a).intersection(words(b)).length >= 2;
  }

  static int _months(DateTime a, DateTime b) =>
      ((b.difference(a).inDays) / 30).round().clamp(1, 120);

  static String _d(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  // ───────────────────────── Extraction ─────────────────────────
  /// Returns what the OCR + AI step would extract. Static per type for the
  /// prototype; replaced by the `process-record` edge function.
  static ExtractDraft extract(RecordType type) {
    switch (type) {
      case RecordType.report:
        return ExtractDraft(
          title: 'Vitamin D & B12',
          doctor: 'Dr. Anjali Verma',
          hospital: 'City Diagnostics, Pratapgarh',
          summary:
              'Vitamin D is low — very common in India, especially in women who spend most time indoors. Vitamin B12 is normal.',
          summaryHi:
              'विटामिन D कम है — भारत में बहुत आम है, खासकर घर के अंदर रहने वाली महिलाओं में। विटामिन B12 सामान्य है।',
          tags: ['Vitamins'],
          lines: [
            'CITY DIAGNOSTICS - BIOCHEMISTRY',
            '25-OH Vitamin D   14.2  ng/mL  30 - 100',
            'Vitamin B12       410   pg/mL  211 - 911',
          ],
          params: const [
            LabParam(
                name: 'Vitamin D',
                value: '14.2',
                numeric: 14.2,
                unit: 'ng/mL',
                low: 30,
                high: 100,
                status: ParamStatus.low,
                simple: 'Needed for strong bones and immunity. Your level is low.',
                simpleHi: 'हड्डियों और रोग प्रतिरोधक क्षमता के लिए ज़रूरी। आपका स्तर कम है।',
                sourceLine: '25-OH Vitamin D   14.2  ng/mL  30 - 100'),
            LabParam(
                name: 'Vitamin B12',
                value: '410',
                numeric: 410,
                unit: 'pg/mL',
                low: 211,
                high: 911,
                status: ParamStatus.normal,
                simple: 'Important for nerves and blood. Normal.',
                simpleHi: 'नसों और खून के लिए ज़रूरी। सामान्य।',
                sourceLine: 'Vitamin B12       410   pg/mL  211 - 911',
                confidence: 0.81),
          ],
        );
      case RecordType.prescription:
        return ExtractDraft(
          title: 'Prescription — General Physician',
          doctor: 'Dr. Anjali Verma',
          hospital: 'City Clinic, Pratapgarh',
          summary:
              'Prescribed a weekly Vitamin D sachet for 8 weeks and advised 20 minutes of morning sunlight. Repeat Vitamin D test after 3 months.',
          summaryHi:
              '8 हफ़्तों तक हर हफ़्ते विटामिन D सैशे और सुबह 20 मिनट धूप लेने की सलाह। 3 महीने बाद विटामिन D जाँच दोबारा।',
          tags: ['Vitamin D'],
          lines: [
            'Rx',
            '1. Sachet Cholecalciferol 60000 IU  once weekly x 8 wks (with milk)',
            'Adv: Morning sunlight 20 min daily.',
            'Inv: Vitamin D after 3 months',
          ],
        );
      case RecordType.scan:
        return ExtractDraft(
          title: 'Ultrasound Whole Abdomen',
          doctor: 'Dr. P. Chouhan (Radiologist)',
          hospital: 'Govt. District Hospital, Pratapgarh',
          summary:
              'The ultrasound looks normal. Liver shows mild fatty change (Grade 1), which is common and usually improves with diet and exercise.',
          summaryHi:
              'अल्ट्रासाउंड सामान्य है। लिवर में हल्का फैटी बदलाव (ग्रेड 1) है, जो आम है और खान-पान व व्यायाम से अक्सर ठीक हो जाता है।',
          tags: ['Ultrasound', 'Liver'],
          lines: [
            'USG WHOLE ABDOMEN',
            'Liver: normal size, increased echogenicity - Grade I fatty liver.',
            'GB, CBD, pancreas, spleen: normal.',
            'Kidneys: normal size and echotexture. No calculus.',
            'Impression: Grade I fatty liver. Otherwise normal study.',
          ],
        );
      case RecordType.discharge:
        return ExtractDraft(
          title: 'Discharge Summary — Dengue fever',
          doctor: 'Dr. N. Bhatt',
          hospital: 'Shree Hospital, Udaipur',
          summary:
              'Admitted for 4 days with dengue fever. Platelets dropped to 62,000 and recovered to 1.4 lakh before discharge. Advised fluids, rest and a platelet test after 5 days.',
          summaryHi:
              'डेंगू बुखार के कारण 4 दिन भर्ती रहे। प्लेटलेट्स 62,000 तक गिरे और छुट्टी से पहले 1.4 लाख तक ठीक हुए। तरल पदार्थ, आराम और 5 दिन बाद प्लेटलेट जाँच की सलाह।',
          tags: ['Dengue', 'Hospital stay'],
          lines: [
            'DISCHARGE SUMMARY',
            'Diagnosis: Dengue fever (NS1 positive), thrombocytopenia.',
            'Lowest platelet: 62,000/cumm. At discharge: 1.4 lakh/cumm.',
            'Adv: Oral fluids 3L/day, rest. Paracetamol SOS. Avoid NSAIDs.',
            'Inv: Platelet count after 5 days.',
          ],
        );
    }
  }

  // ───────────────────────── Compare ─────────────────────────
  static OpinionCase compare(AppState s, MedicalRecord a, MedicalRecord b, String condition) {
    final pair = {a.id, b.id};
    for (final c in s.cases) {
      if (c.recordA != null && {c.recordA, c.recordB}.containsAll(pair)) return c;
    }
    // Order chronologically: A = earlier consultation.
    if (b.date.isBefore(a.date)) {
      final t = a;
      a = b;
      b = t;
    }

    Map<String, String> meds(MedicalRecord r) {
      final out = <String, String>{};
      for (final l in r.originalLines) {
        final m = RegExp(r'(Tab|Cap|Syp|Sachet|Inj)\.?\s+([A-Za-z+ ]+?)(\s+\d|$)',
                caseSensitive: false)
            .firstMatch(l);
        if (m != null) out[m.group(2)!.trim().toLowerCase()] = l.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
      }
      return out;
    }

    String line(MedicalRecord r, String prefix) => r.originalLines
        .where((l) => l.toLowerCase().startsWith(prefix))
        .map((l) => l.substring(l.indexOf(':') + 1).trim())
        .join(' ');

    final points = <DiffPoint>[];
    points.add(DiffPoint(
      topic: 'Overall advice',
      tag: DiffTag.differs,
      doctorA: a.summary,
      doctorB: b.summary,
      plain: 'Read both summaries side by side. The points below break the differences down.',
    ));

    final ma = meds(a), mb = meds(b);
    for (final k in {...ma.keys, ...mb.keys}) {
      final inA = ma.containsKey(k), inB = mb.containsKey(k);
      final name = k.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
      points.add(DiffPoint(
        topic: 'Medicine: $name',
        tag: inA && inB ? DiffTag.agree : inA ? DiffTag.onlyA : DiffTag.onlyB,
        doctorA: ma[k] ?? '—',
        doctorB: mb[k] ?? '—',
        plain: inA && inB
            ? 'Both prescribed this — you only need to take it once.'
            : 'Only one doctor prescribed $name. Ask whether you still need it.',
      ));
    }

    final advA = line(a, 'adv'), advB = line(b, 'adv');
    if (advA.isNotEmpty || advB.isNotEmpty) {
      points.add(DiffPoint(
        topic: 'Advice',
        tag: advA.isEmpty ? DiffTag.onlyB : advB.isEmpty ? DiffTag.onlyA : DiffTag.differs,
        doctorA: advA.isEmpty ? '—' : advA,
        doctorB: advB.isEmpty ? '—' : advB,
        plain: 'Lifestyle or procedure advice from each doctor.',
      ));
    }
    final invA = line(a, 'inv'), invB = line(b, 'inv');
    if (invA.isNotEmpty || invB.isNotEmpty) {
      points.add(DiffPoint(
        topic: 'Tests ordered',
        tag: invA.isEmpty ? DiffTag.onlyB : invB.isEmpty ? DiffTag.onlyA : DiffTag.differs,
        doctorA: invA.isEmpty ? '—' : invA,
        doctorB: invB.isEmpty ? '—' : invB,
        plain: 'Check your records before repeating any test.',
      ));
    }

    final questions = <String>[
      '${a.doctor} and ${b.doctor} advised differently — which approach suits my situation, and why?',
      for (final p in points.where((p) => p.tag == DiffTag.onlyA || p.tag == DiffTag.onlyB))
        if (p.topic.startsWith('Medicine'))
          'Do I need to continue ${p.topic.replaceFirst('Medicine: ', '')}, which only one doctor prescribed?',
      'What signs should make me come back sooner?',
      'Are there any tests I have already done that can be reused?',
    ];

    return OpinionCase(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      memberId: a.memberId,
      condition: condition,
      recordA: a.id,
      recordB: b.id,
      doctorAName: a.doctor,
      doctorASpec: a.type.label,
      doctorAHospital: a.hospital,
      doctorADate: a.date,
      doctorBName: b.doctor,
      doctorBSpec: b.type.label,
      doctorBHospital: b.hospital,
      doctorBDate: b.date,
      points: points,
      whyDiffer: const [
        'Different information — each doctor may have seen different reports or asked different questions.',
        'Different approaches — some doctors prefer to watch and wait, others to treat early.',
        'Timing — your condition may have changed between the two visits.',
      ],
      questions: questions,
      autoGenerated: true,
    );
  }

  // ───────────────────────── Ask ─────────────────────────
  static final _topics = <String, List<String>>{
    'Haemoglobin': ['haemoglobin', 'hemoglobin', 'hb', 'anaemia', 'anemia', 'खून', 'हीमोग्लोबिन', 'एनीमिया'],
    'Potassium': ['potassium', 'पोटैशियम'],
    'TSH': ['tsh', 'thyroid', 'थायरॉइड', 'थायराइड'],
    'HbA1c': ['sugar', 'hba1c', 'diabetes', 'शुगर', 'मधुमेह'],
    'Creatinine': ['creatinine', 'kidney', 'किडनी', 'गुर्दे'],
    'Vitamin D': ['vitamin d', 'विटामिन'],
  };

  static String answer(AppState s, String q) {
    final low = q.toLowerCase();
    final hi = s.hi || RegExp(r'[ऀ-ॿ]').hasMatch(q);
    bool has(List<String> ks) => ks.any(low.contains);

    for (final e in _topics.entries) {
      if (!has(e.value)) continue;
      for (final r in s.records.where((r) => !r.isPrivate)) {
        for (final p in r.params.where((p) => p.name == e.key)) {
          final who = s.member(r.memberId);
          final whose = who.relation == 'Self' ? (hi ? 'आपका' : 'Your') : (hi ? '${who.name.split(' ').first} का' : "${who.name.split(' ').first}'s");
          if (p.status == ParamStatus.critical) {
            return hi
                ? '$whose ${p.name} ${p.value} ${p.unit} है, जो सुरक्षित सीमा (${_n(p.low)}–${_n(p.high)}) से बाहर है। कृपया आज ही डॉक्टर से संपर्क करें। ज़रूरी मानों पर MedVerse सलाह नहीं देता।'
                : '$whose ${p.name} is ${p.value} ${p.unit}, outside the safe range (${_n(p.low)}–${_n(p.high)}). Please contact a doctor today. MedVerse does not give advice on urgent values.';
          }
          final st = hi
              ? {ParamStatus.normal: 'सामान्य है', ParamStatus.low: 'सामान्य से कम है', ParamStatus.high: 'सामान्य से ज़्यादा है'}[p.status]
              : {ParamStatus.normal: 'normal', ParamStatus.low: 'lower than normal', ParamStatus.high: 'higher than normal'}[p.status];
          return hi
              ? '$whose ${p.name} ${p.value} ${p.unit} है (सामान्य ${_n(p.low)}–${_n(p.high)}), यानी $st। ${p.simpleHi}\n\nस्रोत: ${r.title}, ${r.hospital}, ${_d(r.date)}। इलाज के लिए डॉक्टर से पूछें।'
              : '$whose ${p.name} is ${p.value} ${p.unit} (normal ${_n(p.low)}–${_n(p.high)}), which is $st. ${p.simple}\n\nSource: ${r.title}, ${r.hospital}, ${_d(r.date)}. Ask your doctor about treatment.';
        }
      }
    }

    if (has(['surgery', 'knee', 'operation', 'घुटन', 'ऑपरेशन', 'सर्जरी'])) {
      final c = s.caseById('c1');
      if (c != null) {
        return hi
            ? 'दोनों डॉक्टर मानते हैं कि घुटनों में ऑस्टियोआर्थराइटिस है। ${c.doctorAName} जल्द घुटना बदलने की सलाह देते हैं, जबकि ${c.doctorBName} पहले 12 हफ़्ते फिज़ियोथेरेपी की। कौन सही है, यह MedVerse नहीं बताता — "तुलना" में जाकर दोनों डॉक्टरों से पूछने के सवाल देखें।'
            : 'Both doctors agree it is osteoarthritis of the knees. ${c.doctorAName} suggests knee replacement soon; ${c.doctorBName} suggests 12 weeks of physiotherapy first. MedVerse does not say who is right — open Compare to see every difference and questions to ask both.';
      }
    }

    if (has(['medicine', 'tablet', 'dawai', 'दवा', 'गोली'])) {
      final meds = s.medsFor(s.activeMemberId);
      if (meds.isEmpty) return hi ? 'अभी कोई दवा दर्ज नहीं है।' : 'No medicines recorded right now.';
      final list = meds.map((m) => '• ${m.name} — ${m.times.join(', ')} (${m.food})').join('\n');
      return hi ? '${s.activeMember.name.split(' ').first} की दवाइयाँ:\n$list' : "${s.activeMember.name.split(' ').first}'s medicines:\n$list";
    }

    if (has(['appointment', 'visit', 'next doctor', 'मुलाक़ात', 'अपॉइंटमेंट', 'डॉक्टर कब'])) {
      final up = s.upcoming();
      if (up.isEmpty) return hi ? 'कोई आगामी मुलाक़ात नहीं है।' : 'No upcoming visits.';
      final a = up.first;
      return hi
          ? 'अगली मुलाक़ात: ${a.doctor}, ${_d(a.when)} को, ${a.place} में — ${a.purpose}।'
          : 'Next visit: ${a.doctor} on ${_d(a.when)} at ${a.place} — ${a.purpose}.';
    }

    if (has(['repeat', 'again', 'duplicate', 'दोबारा'])) {
      final d = alerts(s).where((a) => a.kind == AlertKind.duplicateTest).toList();
      if (d.isNotEmpty) return d.map((a) => '${a.title}. ${a.body}').join('\n\n');
    }

    return hi
        ? 'मैं आपके रिकॉर्ड से हीमोग्लोबिन, थायरॉइड, शुगर, किडनी, पोटैशियम, दवाइयों, घुटने की सर्जरी की राय और अगली मुलाक़ात के बारे में बता सकता हूँ। कोई निर्णय लेने से पहले डॉक्टर से ज़रूर पूछें।'
        : 'I can answer from your records about haemoglobin, thyroid, sugar, kidney, potassium, medicines, the knee-surgery opinions and your next visit. Try asking one of those — and always confirm decisions with your doctor.';
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class ExtractDraft {
  final String title, doctor, hospital, summary, summaryHi;
  final List<String> tags, lines;
  final List<LabParam> params;
  final RecordType? type;
  final DateTime? date;
  final List<DraftMed> medicines;
  final List<String> orderedTests;
  final bool ai;
  const ExtractDraft({
    required this.title,
    required this.doctor,
    required this.hospital,
    required this.summary,
    this.summaryHi = '',
    this.tags = const [],
    this.lines = const [],
    this.params = const [],
    this.type,
    this.date,
    this.medicines = const [],
    this.orderedTests = const [],
    this.ai = false,
  });
}

class DraftMed {
  final String name, generic, drugClass, dose, food, purpose;
  final List<String> times;
  final int days;
  const DraftMed({
    required this.name,
    this.generic = '',
    this.drugClass = '',
    this.dose = '1 tablet',
    this.times = const ['09:00'],
    this.food = 'After food',
    this.purpose = '',
    this.days = 30,
  });
}

extension on AppState {
  List<Trend> get trendsForAll => [for (final m in members) ...trendsFor(m.id)];
}
