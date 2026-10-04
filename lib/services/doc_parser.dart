import '../data/models.dart';
import 'engine.dart' show ExtractDraft;
import 'ocr.dart';

/// Turns raw OCR rows into a structured record draft: type, doctor, hospital,
/// date, lab values (with status against the printed range), medicines and a
/// plain-language summary. Rule-based on purpose — status and critical flags
/// are decided by code, never by an AI model.
class DocParser {
  // name pattern → (display name, English meaning, Hindi meaning, critical low, critical high)
  static final _known = <(RegExp, String, String, String, double?, double?)>[
    (RegExp(r'^(haemoglobin|hemoglobin|hb|hgb)\b', caseSensitive: false), 'Haemoglobin',
      'Haemoglobin carries oxygen in your blood. Low levels can cause tiredness, weakness and breathlessness.',
      'हीमोग्लोबिन खून में ऑक्सीजन ले जाता है। कमी से थकान, कमजोरी और सांस फूलना हो सकता है।', 7, null),
    (RegExp(r'^(total )?rbc', caseSensitive: false), 'RBC Count', 'Number of red blood cells.', 'लाल रक्त कोशिकाओं की संख्या।', null, null),
    (RegExp(r'^(total )?(wbc|tlc)', caseSensitive: false), 'WBC Count', 'White blood cells fight infection.', 'सफेद रक्त कोशिकाएँ संक्रमण से लड़ती हैं।', null, null),
    (RegExp(r'^platelet', caseSensitive: false), 'Platelets', 'Platelets help blood clot.', 'प्लेटलेट्स खून का थक्का बनाने में मदद करते हैं।', null, null),
    (RegExp(r'^mcv\b', caseSensitive: false), 'MCV', 'Size of red blood cells. Small cells often point to iron deficiency.', 'लाल रक्त कोशिकाओं का आकार। छोटी कोशिकाएँ अक्सर आयरन की कमी दर्शाती हैं।', null, null),
    (RegExp(r'^tsh\b', caseSensitive: false), 'TSH', 'The signal your brain sends to the thyroid. High means the thyroid may be under-active.', 'दिमाग का थायरॉइड को भेजा संकेत। ज़्यादा मान का मतलब थायरॉइड धीमा हो सकता है।', null, null),
    (RegExp(r'^(t3|triiodothyronine)', caseSensitive: false), 'T3', 'A thyroid hormone.', 'थायरॉइड हार्मोन।', null, null),
    (RegExp(r'^(t4|thyroxine)', caseSensitive: false), 'T4', 'A thyroid hormone.', 'थायरॉइड हार्मोन।', null, null),
    (RegExp(r'^(hba1c|glycosylated|glycated)', caseSensitive: false), 'HbA1c', 'Average blood sugar over the last 3 months.', 'पिछले 3 महीनों की औसत शुगर।', null, null),
    (RegExp(r'^(fasting|random|post ?prandial|pp)?\s*(blood )?(glucose|sugar)', caseSensitive: false), 'Blood Sugar', 'Sugar level in your blood.', 'खून में शुगर का स्तर।', 40, 400),
    (RegExp(r'^creatinine', caseSensitive: false), 'Creatinine', 'Shows how well kidneys filter waste.', 'किडनी कितनी अच्छी तरह कचरा छानती है।', null, null),
    (RegExp(r'^(blood )?urea', caseSensitive: false), 'Urea', 'A waste product removed by the kidneys.', 'किडनी द्वारा निकाला जाने वाला अपशिष्ट।', null, null),
    (RegExp(r'^potassium', caseSensitive: false), 'Potassium', 'Potassium controls heart rhythm and muscles.', 'पोटैशियम दिल की धड़कन और मांसपेशियों को नियंत्रित करता है।', 2.8, 6.0),
    (RegExp(r'^sodium', caseSensitive: false), 'Sodium', 'Salt balance in the body.', 'शरीर में नमक का संतुलन।', 120, 160),
    (RegExp(r'^(total )?cholesterol', caseSensitive: false), 'Cholesterol', 'Fat in the blood. High levels raise heart risk over time.', 'खून में चर्बी। ज़्यादा स्तर से समय के साथ दिल का खतरा बढ़ता है।', null, null),
    (RegExp(r'^triglyceride', caseSensitive: false), 'Triglycerides', 'A type of blood fat.', 'खून की चर्बी का एक प्रकार।', null, null),
    (RegExp(r'^hdl', caseSensitive: false), 'HDL (good cholesterol)', 'The "good" cholesterol — higher is better.', '"अच्छा" कोलेस्ट्रॉल — ज़्यादा होना बेहतर है।', null, null),
    (RegExp(r'^ldl', caseSensitive: false), 'LDL (bad cholesterol)', 'The "bad" cholesterol — lower is better.', '"खराब" कोलेस्ट्रॉल — कम होना बेहतर है।', null, null),
    (RegExp(r'^(sgpt|alt)\b', caseSensitive: false), 'SGPT (ALT)', 'A liver enzyme. High values can mean liver irritation.', 'लिवर का एंजाइम। ज़्यादा मान लिवर में सूजन दर्शा सकता है।', null, null),
    (RegExp(r'^(sgot|ast)\b', caseSensitive: false), 'SGOT (AST)', 'A liver and muscle enzyme.', 'लिवर और मांसपेशियों का एंजाइम।', null, null),
    (RegExp(r'^bilirubin', caseSensitive: false), 'Bilirubin', 'A yellow pigment processed by the liver.', 'लिवर द्वारा संसाधित पीला रंग।', null, null),
    (RegExp(r'^uric acid', caseSensitive: false), 'Uric Acid', 'High levels can cause gout and joint pain.', 'ज़्यादा स्तर से गाउट और जोड़ों में दर्द हो सकता है।', null, null),
    (RegExp(r'^calcium', caseSensitive: false), 'Calcium', 'Needed for strong bones and muscles.', 'मज़बूत हड्डियों और मांसपेशियों के लिए ज़रूरी।', null, null),
    (RegExp(r'^(25.?oh\s*)?vitamin ?d', caseSensitive: false), 'Vitamin D', 'Needed for strong bones and immunity.', 'हड्डियों और रोग प्रतिरोधक क्षमता के लिए ज़रूरी।', null, null),
    (RegExp(r'^vitamin ?b ?12', caseSensitive: false), 'Vitamin B12', 'Important for nerves and blood.', 'नसों और खून के लिए ज़रूरी।', null, null),
    (RegExp(r'^ferritin', caseSensitive: false), 'Ferritin', 'Shows your body\'s iron stores.', 'शरीर में आयरन का भंडार दर्शाता है।', null, null),
    (RegExp(r'^esr\b', caseSensitive: false), 'ESR', 'A general marker of inflammation.', 'सूजन का सामान्य संकेतक।', null, null),
  ];

  static final _num = RegExp(r'^[<>]?\d+(\.\d+)?$');
  static final _rangeRe = RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|–|—|to)\s*(\d+(?:\.\d+)?)');
  static final _lessRe = RegExp(r'[<≤]\s*=?\s*(\d+(?:\.\d+)?)');
  static final _moreRe = RegExp(r'[>≥]\s*=?\s*(\d+(?:\.\d+)?)');

  static ExtractDraft parse(OcrResult ocr, {RecordType? chosen}) {
    final lines = ocr.lines;
    final text = ocr.fullText;
    final lower = text.toLowerCase();

    final params = <LabParam>[];
    final seen = <String>{};
    for (final l in lines) {
      final p = _labRow(l);
      if (p != null && seen.add(p.name)) params.add(p);
    }

    final meds = <String>[];
    for (final l in lines) {
      final m = RegExp(r'\b(tab|tablet|cap|capsule|syp|syrup|inj|sachet|oint)\.?\s+([A-Za-z][A-Za-z0-9+\- ]{2,40})', caseSensitive: false)
          .firstMatch(l.text);
      if (m != null) meds.add(l.text.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim());
    }

    final type = _type(lower, params, meds, chosen);
    final doctor = _doctor(lines);
    final hospital = _hospital(lines);
    final title = _title(type, lines, params, doctor);

    final abnormal = params.where((p) => p.status != ParamStatus.normal).toList();
    final critical = params.where((p) => p.status == ParamStatus.critical).toList();

    String en, hi;
    if (params.isNotEmpty) {
      final b = StringBuffer(
          '${abnormal.isEmpty ? 'All ${params.length} values are within the normal range.' : '${abnormal.length} of ${params.length} values are outside the normal range.'}');
      for (final p in abnormal.take(4)) {
        b.write(p.status == ParamStatus.critical
            ? ' ${p.name} (${p.value} ${p.unit}) is outside the safe range — please contact a doctor today.'
            : ' ${p.name} is ${p.status == ParamStatus.low ? 'lower' : 'higher'} than normal (${p.value} ${p.unit}).');
      }
      b.write(' Your doctor can tell you what this means for you.');
      en = b.toString();
      final h = StringBuffer(abnormal.isEmpty
          ? 'सभी ${params.length} जाँच सामान्य सीमा में हैं।'
          : '${params.length} में से ${abnormal.length} जाँच सामान्य सीमा से बाहर हैं।');
      for (final p in abnormal.take(4)) {
        h.write(p.status == ParamStatus.critical
            ? ' ${p.name} (${p.value} ${p.unit}) सुरक्षित सीमा से बाहर है — कृपया आज ही डॉक्टर से संपर्क करें।'
            : ' ${p.name} सामान्य से ${p.status == ParamStatus.low ? 'कम' : 'ज़्यादा'} है (${p.value} ${p.unit})।');
      }
      h.write(' इसका मतलब आपके लिए क्या है, यह डॉक्टर बता सकते हैं।');
      hi = h.toString();
    } else if (meds.isNotEmpty) {
      final names = meds.take(5).map((m) => m.split(RegExp(r'\s+(x|for|daily|once|twice)\b', caseSensitive: false)).first).join('; ');
      en = 'This prescription lists ${meds.length} medicine${meds.length > 1 ? 's' : ''}: $names. Check each one against what your doctor told you, and ask if anything is unclear.';
      hi = 'इस पर्चे में ${meds.length} दवा${meds.length > 1 ? 'एँ' : ''} लिखी हैं: $names। हर दवा डॉक्टर की बताई बात से मिला लें, और कुछ साफ़ न हो तो पूछें।';
    } else {
      final impression = lines.where((l) => RegExp(r'impression|conclusion|diagnosis|advice|adv\b', caseSensitive: false).hasMatch(l.text)).map((l) => l.text).take(2).join(' ');
      en = impression.isNotEmpty
          ? 'Key line from this document: $impression. Ask your doctor to explain it in detail.'
          : 'MedVerse read ${lines.length} lines from this document. Open the Original tab to see the text, and ask your doctor about anything unclear.';
      hi = impression.isNotEmpty
          ? 'इस दस्तावेज़ की मुख्य पंक्ति: $impression। डॉक्टर से विस्तार से समझ लें।'
          : 'MedVerse ने इस दस्तावेज़ की ${lines.length} पंक्तियाँ पढ़ीं। मूल टैब में पूरा पाठ देखें और जो साफ़ न हो वह डॉक्टर से पूछें।';
    }

    final tags = <String>[
      if (critical.isNotEmpty) 'Urgent',
      ...abnormal.take(2).map((p) => p.name),
    ];

    return ExtractDraft(
      title: title,
      doctor: doctor,
      hospital: hospital,
      summary: en,
      summaryHi: hi,
      tags: tags,
      lines: [for (final l in lines) l.text],
      params: params,
      type: type,
      date: _date(text),
    );
  }

  // ───────── lab value rows ─────────
  static LabParam? _labRow(OcrLine l) {
    final tokens = l.text.split(' ');
    final vi = tokens.indexWhere((t) => _num.hasMatch(t));
    if (vi <= 0) return null;
    final rawName = tokens.sublist(0, vi).join(' ').replaceAll(RegExp(r'[:\-_]+$'), '').trim();
    if (rawName.length < 2 || !RegExp(r'[A-Za-z]{2}').hasMatch(rawName)) return null;
    final rest = tokens.sublist(vi + 1).join(' ');
    final value = double.tryParse(tokens[vi].replaceAll(RegExp(r'[<>]'), ''));
    if (value == null) return null;

    double? low, high;
    final r = _rangeRe.firstMatch(rest);
    if (r != null) {
      low = double.parse(r.group(1)!);
      high = double.parse(r.group(2)!);
    } else if (_lessRe.hasMatch(rest)) {
      low = 0;
      high = double.parse(_lessRe.firstMatch(rest)!.group(1)!);
    } else if (_moreRe.hasMatch(rest)) {
      low = double.parse(_moreRe.firstMatch(rest)!.group(1)!);
      high = low * 4;
    }
    if (low == null || high == null || high <= low && low != 0) return null;

    final unitMatch = RegExp(r'^([A-Za-zµ%/0-9^.]+(?:/[A-Za-z0-9]+)?)').firstMatch(rest);
    var unit = unitMatch?.group(1) ?? '';
    if (_num.hasMatch(unit)) unit = '';

    String name = rawName;
    String en = 'A measured value from your report.';
    String hi = 'आपकी रिपोर्ट का एक मापा गया मान।';
    double? cLow, cHigh;
    for (final k in _known) {
      if (k.$1.hasMatch(rawName)) {
        name = k.$2;
        en = k.$3;
        hi = k.$4;
        cLow = k.$5;
        cHigh = k.$6;
        break;
      }
    }

    var status = value < low ? ParamStatus.low : value > high ? ParamStatus.high : ParamStatus.normal;
    if ((cLow != null && value < cLow) || (cHigh != null && value > cHigh)) status = ParamStatus.critical;
    final dir = status == ParamStatus.low ? ' Your value is below the normal range.' : status == ParamStatus.high ? ' Your value is above the normal range.' : status == ParamStatus.normal ? ' Your value is normal.' : '';
    final dirHi = status == ParamStatus.low ? ' आपका मान सामान्य से कम है।' : status == ParamStatus.high ? ' आपका मान सामान्य से ज़्यादा है।' : status == ParamStatus.normal ? ' आपका मान सामान्य है।' : '';

    return LabParam(
      name: name,
      value: tokens[vi].replaceAll(RegExp(r'[<>]'), ''),
      numeric: value,
      unit: unit,
      low: low,
      high: high,
      status: status,
      simple: en + dir,
      simpleHi: hi + dirHi,
      sourceLine: l.text,
      confidence: l.confidence,
    );
  }

  // ───────── metadata ─────────
  static RecordType _type(String lower, List<LabParam> params, List<String> meds, RecordType? chosen) {
    if (RegExp(r'discharge summary|date of discharge|admitted').hasMatch(lower)) return RecordType.discharge;
    if (params.length >= 2) return RecordType.report;
    if (RegExp(r'x-?ray|ultrasound|\busg\b|\bmri\b|\bct scan|sonography|impression').hasMatch(lower) && meds.isEmpty) return RecordType.scan;
    if (meds.isNotEmpty || RegExp(r'\brx\b|℞').hasMatch(lower)) return RecordType.prescription;
    return chosen ?? RecordType.report;
  }

  static String _doctor(List<OcrLine> lines) {
    for (final l in lines) {
      final m = RegExp(r'\b(Dr\.?\s*[A-Z][A-Za-z.]*(?:\s+[A-Z][A-Za-z.]*){0,2})').firstMatch(l.text);
      if (m != null) return m.group(1)!.trim();
    }
    return '';
  }

  static String _hospital(List<OcrLine> lines) {
    for (final l in lines.take(12)) {
      if (RegExp(r'hospital|clinic|diagnostic|laborator|\blab\b|centre|center|nursing|medical', caseSensitive: false).hasMatch(l.text) &&
          l.text.length < 70) {
        return l.text;
      }
    }
    return lines.isEmpty ? '' : (lines.first.text.length < 60 ? lines.first.text : '');
  }

  static DateTime? _date(String text) {
    final a = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b').firstMatch(text);
    if (a != null) {
      var y = int.parse(a.group(3)!);
      if (y < 100) y += 2000;
      final d = int.parse(a.group(1)!), m = int.parse(a.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && y > 2000) {
        final dt = DateTime(y, m, d);
        if (!dt.isAfter(DateTime.now().add(const Duration(days: 1)))) return dt;
      }
    }
    const mon = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final b = RegExp(r'\b(\d{1,2})\s*([A-Za-z]{3})[a-z]*[,.]?\s*(\d{4})\b').firstMatch(text);
    if (b != null) {
      final mi = mon.indexOf(b.group(2)!.toLowerCase());
      if (mi >= 0) {
        final dt = DateTime(int.parse(b.group(3)!), mi + 1, int.parse(b.group(1)!));
        if (!dt.isAfter(DateTime.now().add(const Duration(days: 1)))) return dt;
      }
    }
    return null;
  }

  static String _title(RecordType type, List<OcrLine> lines, List<LabParam> params, String doctor) {
    final all = lines.map((l) => l.text.toLowerCase()).join(' ');
    switch (type) {
      case RecordType.report:
        if (all.contains('blood count') || all.contains('cbc')) return 'Complete Blood Count (CBC)';
        if (all.contains('thyroid')) return 'Thyroid Profile';
        if (all.contains('lipid')) return 'Lipid Profile';
        if (all.contains('liver function') || all.contains('lft')) return 'Liver Function Test';
        if (all.contains('kidney') || all.contains('renal')) return 'Kidney Function Test';
        if (params.isNotEmpty) return params.take(3).map((p) => p.name).join(', ');
        return 'Lab Report';
      case RecordType.prescription:
        return doctor.isNotEmpty ? 'Prescription — $doctor' : 'Prescription';
      case RecordType.scan:
        for (final l in lines) {
          if (RegExp(r'x-?ray|ultrasound|usg|mri|ct scan|sonography', caseSensitive: false).hasMatch(l.text) && l.text.length < 60) {
            return l.text;
          }
        }
        return 'Scan Report';
      case RecordType.discharge:
        return 'Discharge Summary';
    }
  }
}
