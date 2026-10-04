import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'family_screens.dart';
import 'records_screen.dart';

class HealthCardScreen extends StatefulWidget {
  const HealthCardScreen({super.key});
  @override
  State<HealthCardScreen> createState() => _HealthCardScreenState();
}

class _HealthCardScreenState extends State<HealthCardScreen> {
  DateTime _expires = DateTime.now().add(const Duration(hours: 24));
  int _nonce = DateTime.now().millisecondsSinceEpoch % 100000;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.activeMember;
    final meds = s.medsFor(m.id);
    final link = 'https://medverse.app/c/${m.id.hashCode.toRadixString(16)}-${_nonce.toRadixString(36)}';
    final hoursLeft = _expires.difference(DateTime.now()).inHours;
    return Scaffold(
      appBar: AppBar(title: const Text('Health card'), actions: const [MemberButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          const Text(
              'Show this at any clinic or in an emergency. The doctor scans it to see a one-page summary — no app or login needed.',
              style: TextStyle(color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(children: [
                  Avatar(m, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, style: serif(20, c: Colors.white)),
                      Text('${m.age} yrs · ${m.gender}', style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(m.bloodGroup, style: serif(18, c: AppColors.accent, w: FontWeight.w800)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: QrImageView(
                  data: link,
                  size: 190,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.text),
                  dataModuleStyle:
                      const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.text),
                ),
              ),
              Text('Link valid for $hoursLeft more hours',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _row('Allergies', m.allergies.isEmpty ? 'None known' : m.allergies.join(', '),
                      color: m.allergies.isEmpty ? null : AppColors.bad),
                  _row('Conditions', m.conditions.isEmpty ? '—' : m.conditions.join(', ')),
                  _row('Current meds', meds.isEmpty ? '—' : meds.map((x) => x.name).join(', ')),
                  _row('Emergency', m.emergencyContact.isEmpty ? 'Not set' : m.emergencyContact),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bytes = await withLoading(context, Anim.medicalReport, 'Preparing health card…', () => Exporter.healthCardPdf(m, meds, link));
                  await Exporter.sharePdf(bytes, 'HealthCard_${m.name.split(' ').first}.pdf');
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF / print'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Exporter.shareText(
                    '${m.name}\'s MedVerse health card (valid 24 h): $link',
                    subject: 'Health card'),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Share link'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              onPressed: () => setState(() {
                _nonce = DateTime.now().millisecondsSinceEpoch % 100000;
                _expires = DateTime.now().add(const Duration(hours: 24));
                toast(context, 'Old link stopped working. New QR created.');
              }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Make new link'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => push(context, MemberFormScreen(member: m)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit info'),
            ),
          ]),
          const SizedBox(height: 4),
          const Center(
            child: Text('Private-vault records are never included.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Expanded(child: Text(v, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
        ]),
      );
}
