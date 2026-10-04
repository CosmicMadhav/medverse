import 'package:flutter_test/flutter_test.dart';
import 'package:medverse_app/data/models.dart';
import 'package:medverse_app/services/doc_parser.dart';
import 'package:medverse_app/services/ocr.dart';

OcrResult r(List<String> l) => OcrResult([for (final x in l) OcrLine(x, .96)]);

void main() {
  test('lab report: values, ranges, critical, metadata', () {
    final d = DocParser.parse(r([
      'CITY DIAGNOSTICS - HAEMATOLOGY',
      'Patient: PREETI M Ref By: Dr. ANJALI VERMA Date: 18/09/2026',
      'Haemoglobin (Hb) 9.8 g/dL 12.0 - 15.5',
      'Total RBC Count 3.9 mill/cmm 4.0 - 5.2',
      'Potassium 6.3 mmol/L 3.5 - 5.1',
      'Total WBC Count 7200 /cumm 4000 - 11000',
    ]));
    expect(d.type, RecordType.report);
    expect(d.params.length, 4);
    final byName = {for (final p in d.params) p.name: p};
    expect(byName['Haemoglobin']!.status, ParamStatus.low);
    expect(byName['Potassium']!.status, ParamStatus.critical);
    expect(byName['WBC Count']!.status, ParamStatus.normal);
    expect(d.doctor, startsWith('Dr. ANJALI VERMA'));
    expect(d.hospital, contains('CITY DIAGNOSTICS'));
    expect(d.date, DateTime(2026, 9, 18));
    expect(d.summary, contains('contact a doctor today'));
  });

  test('prescription: medicines + type', () {
    final d = DocParser.parse(r([
      'Dr. Meera Sharma AIIMS OPD',
      'Rx',
      '1. Tab Paracetamol 650mg SOS',
      '2. Tab Calcium + D3 0-1-0 x 30 days',
    ]));
    expect(d.type, RecordType.prescription);
    expect(d.params, isEmpty);
    expect(d.summary, contains('2 medicines'));
  });

  test('scan: impression line', () {
    final d = DocParser.parse(r([
      'USG WHOLE ABDOMEN',
      'Impression: Grade I fatty liver.',
    ]));
    expect(d.type, RecordType.scan);
    expect(d.summary, contains('fatty liver'));
  });
}
