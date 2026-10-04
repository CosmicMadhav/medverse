import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';

/// Sharing, PDF generation and phone calls.
class Exporter {
  static const _teal = PdfColor.fromInt(0xFF1F5C57);
  static const _muted = PdfColor.fromInt(0xFF6F6A61);
  static const _line = PdfColor.fromInt(0xFFE6DFD3);

  static Future<void> shareText(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));

  static Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  static Future<bool> call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    return launchUrl(uri);
  }

  static Future<pw.ThemeData> _theme() async {
    // Noto fonts so Hindi (Devanagari) text renders in PDFs.
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final deva = await PdfGoogleFonts.notoSansDevanagariRegular();
    return pw.ThemeData.withFont(base: base, bold: bold, fontFallback: [deva]);
  }

  static pw.Widget _header(String title, String sub) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(
                width: 18,
                height: 18,
                decoration: const pw.BoxDecoration(
                    color: _teal, borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)))),
            pw.SizedBox(width: 8),
            pw.Text('MedVerse',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _teal)),
          ]),
          pw.SizedBox(height: 16),
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(sub, style: const pw.TextStyle(color: _muted)),
          pw.SizedBox(height: 10),
          pw.Divider(color: _line),
        ],
      );

  static pw.Widget _footer() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16),
        child: pw.Text(
            'Prepared with MedVerse. MedVerse explains medical information; it does not diagnose or prescribe.',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      );

  static Future<Uint8List> questionsPdf(String title, String patient, List<String> qs) async {
    final doc = pw.Document(theme: await _theme());
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        _header('Questions for my doctor', '$title · $patient'),
        for (var i = 0; i < qs.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(
                width: 12,
                height: 12,
                margin: const pw.EdgeInsets.only(top: 2, right: 10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: _teal)),
              ),
              pw.Expanded(child: pw.Text('${i + 1}. ${qs[i]}')),
            ]),
          ),
        pw.SizedBox(height: 18),
        pw.Text('Doctor\'s answers / notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        for (var i = 0; i < 6; i++)
          pw.Container(
              height: 26,
              decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _line)))),
        _footer(),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> recordPdf(MedicalRecord r, FamilyMember m, {required bool hindi}) async {
    final doc = pw.Document(theme: await _theme());
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        _header(r.title, '${m.name} · ${r.hospital} · ${r.doctor} · ${r.date.day}/${r.date.month}/${r.date.year}'),
        pw.Text('In simple words', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _teal)),
        pw.SizedBox(height: 4),
        pw.Text(hindi && r.summaryHi.isNotEmpty ? r.summaryHi : r.summary),
        if (r.params.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _teal),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['Test', 'Value', 'Normal', 'Status', 'Meaning'],
            data: [
              for (final p in r.params)
                [p.name, '${p.value} ${p.unit}', '${p.low} – ${p.high}', p.status.name, hindi ? p.simpleHi : p.simple]
            ],
          ),
        ],
        if (r.originalLines.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('Original text', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _teal)),
          for (final l in r.originalLines)
            pw.Text(l, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9)),
        ],
        _footer(),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> healthCardPdf(FamilyMember m, List<Medicine> meds, String link) async {
    final doc = pw.Document(theme: await _theme());
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header('Health card', '${m.name} · ${m.age} yrs · ${m.gender} · Blood ${m.bloodGroup}'),
        pw.Center(
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: link, width: 130, height: 130),
        ),
        pw.SizedBox(height: 14),
        _kv('Allergies', m.allergies.isEmpty ? 'None known' : m.allergies.join(', ')),
        _kv('Conditions', m.conditions.isEmpty ? '—' : m.conditions.join(', ')),
        _kv('Current medicines', meds.isEmpty ? '—' : meds.map((x) => x.name).join(', ')),
        _kv('Emergency contact', m.emergencyContact.isEmpty ? '—' : m.emergencyContact),
        pw.Spacer(),
        _footer(),
      ]),
    ));
    return doc.save();
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 110, child: pw.Text(k, style: const pw.TextStyle(color: _muted))),
          pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static Future<void> sharePdf(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  static Future<void> printPdf(Uint8List bytes, String name) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
}
