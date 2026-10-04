import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'health_card_screen.dart';
import 'records_screen.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.activeMember;
    final meds = s.medsFor(m.id);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('emergency')), actions: const [MemberButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          const Center(child: AnimView(Anim.ambulance, size: 200)),
          _BigButton(
            color: AppColors.bad,
            icon: Icons.local_hospital_rounded,
            title: 'Call ambulance · 108',
            sub: 'Free government ambulance',
            onTap: () => withLoading(context, Anim.ambulance, 'Calling ambulance 108…', () => Exporter.call('108'), minMs: 1200),
          ),
          const SizedBox(height: 10),
          if (m.emergencyContact.isNotEmpty)
            _BigButton(
              color: AppColors.accent,
              icon: Icons.person_rounded,
              title: 'Call family',
              sub: m.emergencyContact,
              onTap: () => Exporter.call(m.emergencyContact),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _SmallButton(Icons.local_police_outlined, 'Police 112', () => Exporter.call('112')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallButton(Icons.woman_outlined, 'Women 181', () => Exporter.call('181')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallButton(Icons.map_outlined, 'Hospitals', () => launchUrl(
                  Uri.parse('https://www.google.com/maps/search/hospital+near+me'),
                  mode: LaunchMode.externalApplication)),
            ),
          ]),
          const SectionTitle('Show this to the doctor'),
          PaperCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: serif(22, w: FontWeight.w700)),
              Text('${m.age} yrs · ${m.gender}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              _big('Blood group', m.bloodGroup, AppColors.accent),
              _big('Allergies', m.allergies.isEmpty ? 'None known' : m.allergies.join(', '),
                  m.allergies.isEmpty ? AppColors.text : AppColors.bad),
              _big('Conditions', m.conditions.isEmpty ? '—' : m.conditions.join(', '), AppColors.text),
              _big('Medicines', meds.isEmpty ? '—' : meds.map((x) => x.name).join(', '), AppColors.text),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => push(context, const HealthCardScreen()),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Open QR health card'),
          ),
        ],
      ),
    );
  }

  static Widget _big(String k, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.toUpperCase(),
              style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.muted, fontWeight: FontWeight.w700)),
          Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
        ]),
      );
}

class _BigButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _BigButton({required this.color, required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: serif(21, c: Colors.white)),
                  Text(sub, style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const Icon(Icons.call_rounded, color: Colors.white),
            ]),
          ),
        ),
      );
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallButton(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => PaperCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5), textAlign: TextAlign.center),
        ]),
      );
}
