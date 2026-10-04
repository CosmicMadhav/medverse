import 'package:flutter/material.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'asha_screen.dart';
import 'family_screens.dart';
import 'medicines_screen.dart';
import 'records_screen.dart';
import 'visits_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final self = s.members.firstWhere((m) => m.relation == 'Self', orElse: () => s.members.first);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          PaperCard(
            onTap: () => _editProfile(context),
            child: Row(children: [
              Avatar(self, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.userName, style: serif(20)),
                  Text('${s.userPhone} · ${s.userCity}', style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.edit_outlined, color: AppColors.muted, size: 20),
            ]),
          ),
          const SizedBox(height: 12),
          PaperCard(
            color: s.abhaLinked ? AppColors.goodSoft : AppColors.mustardSoft,
            borderColor: Colors.transparent,
            onTap: () => s.abhaLinked ? _abhaInfo(context) : _linkAbha(context),
            child: Row(children: [
              Icon(s.abhaLinked ? Icons.verified_rounded : Icons.account_balance_outlined,
                  color: s.abhaLinked ? AppColors.good : AppColors.warn),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.abhaLinked ? 'ABHA linked' : 'Link your ABHA ID', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      s.abhaLinked
                          ? '${s.abhaNumber} · records can be imported from linked hospitals'
                          : 'Bring records from government & partner hospitals automatically',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
          SectionTitle('Family (${s.members.length})',
              action: 'Add', onAction: () => push(context, const MemberFormScreen())),
          PaperCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final m in s.members)
                ListTile(
                  leading: Avatar(m, size: 40),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${m.relation} · ${m.age} yrs · ${m.bloodGroup} · ${s.recordsFor(m.id).length} records'),
                  trailing: s.activeMemberId == m.id
                      ? const Pill('Viewing', color: AppColors.primary)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => push(context, MemberFormScreen(member: m)),
                ),
            ]),
          ),
          const SectionTitle('Preferences'),
          PaperCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Language / भाषा'),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primarySoft, visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'hi', label: Text('हिंदी')),
                  ],
                  selected: {s.lang},
                  onSelectionChanged: (v) => s.setLang(v.first),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_none_rounded),
                title: const Text('Medicine & visit reminders'),
                subtitle: const Text('Shown in the app; phone notifications come with the backend'),
                value: s.remindersOn,
                onChanged: s.setReminders,
              ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.volunteer_activism_outlined),
                title: const Text('ASHA / caregiver mode'),
                subtitle: const Text('Keep records for people without a phone'),
                value: s.ashaMode,
                onChanged: (v) {
                  s.toggleAsha(v);
                  if (v) push(context, const AshaScreen());
                },
              ),
              if (s.ashaMode)
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: Text('Open ASHA register (${s.ashaPeople.length} people)',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  onTap: () => push(context, const AshaScreen()),
                ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Change private-vault PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final verified = await push<bool>(context, const PinScreen());
                  if (verified != true || !context.mounted) return;
                  final set = await push<bool>(context, const PinScreen(setMode: true));
                  if (set == true && context.mounted) toast(context, 'PIN changed');
                },
              ),
            ]),
          ),
          const SectionTitle('Shortcuts'),
          PaperCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: const Text('Medicines'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => push(context, const MedicinesScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Doctor visits'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => push(context, const VisitsScreen()),
              ),
            ]),
          ),
          const SectionTitle('Privacy & trust'),
          PaperCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Who can see my data'),
                subtitle: const Text('Only you. Shared links expire in 24 hours.'),
                onTap: () => _info(context, 'Your data',
                    'Records will be encrypted and stored in India. Nobody — including MedVerse staff — can read them without your permission. You can download or delete everything at any time. Right now in this prototype, everything stays on this phone.',
                    anim: Anim.healthShield),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export a summary of all records'),
                onTap: () => Exporter.shareText(_export(s), subject: 'MedVerse records'),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('How MedVerse uses AI'),
                onTap: () => _info(context, 'Responsible AI',
                    'MedVerse uses AI only to read and explain your documents. It never diagnoses, never prescribes and never says which doctor is right. Every explanation links back to the original line, unclear scans are marked, and urgent values always say “contact a doctor”.'),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.replay_rounded),
                title: const Text('Show onboarding again'),
                onTap: () {
                  s.resetOnboarding();
                  toast(context, 'Onboarding will show next time you open the app');
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(children: [
              Text('MedVerse', style: serif(16, c: AppColors.muted)),
              const Text('v0.2 · prototype · made in Pratapgarh', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ],
      ),
    );
  }

  String _export(AppState s) {
    final b = StringBuffer('MedVerse — family health summary\n\n');
    for (final m in s.members) {
      b.writeln('${m.name} (${m.relation}, ${m.age}, ${m.bloodGroup})');
      if (m.allergies.isNotEmpty) b.writeln('  Allergies: ${m.allergies.join(', ')}');
      if (m.conditions.isNotEmpty) b.writeln('  Conditions: ${m.conditions.join(', ')}');
      for (final r in s.recordsFor(m.id)) {
        b.writeln('  • ${fmtDate(r.date)} — ${r.title} (${r.doctor}, ${r.hospital})');
      }
      final meds = s.medsFor(m.id);
      if (meds.isNotEmpty) b.writeln('  Medicines: ${meds.map((x) => x.name).join(', ')}');
      b.writeln();
    }
    b.writeln('Private-vault records are not included.');
    return b.toString();
  }

  void _info(BuildContext context, String title, String body, {Anim? anim}) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            if (anim != null) Center(child: AnimView(anim, size: 150)),
            Text(title, style: serif(22)),
            const SizedBox(height: 8),
            const Squiggle(),
            const SizedBox(height: 14),
            Text(body, style: const TextStyle(height: 1.55, fontSize: 15)),
          ]),
        ),
      ),
    );
  }

  void _editProfile(BuildContext context) {
    final s = AppScope.read(context);
    final name = TextEditingController(text: s.userName);
    final phone = TextEditingController(text: s.userPhone);
    final city = TextEditingController(text: s.userCity);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          Text('Your profile', style: serif(22)),
          const FieldLabel('Name'),
          TextField(controller: name, textCapitalization: TextCapitalization.words),
          const FieldLabel('Phone'),
          TextField(controller: phone, keyboardType: TextInputType.phone),
          const FieldLabel('City'),
          TextField(controller: city),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                s.updateProfile(name: name.text.trim(), phone: phone.text.trim(), city: city.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }

  void _abhaInfo(BuildContext context) {
    final s = AppScope.read(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            Text('ABHA linked', style: serif(22)),
            const SizedBox(height: 6),
            Text(s.abhaNumber, style: serif(18, c: AppColors.primary)),
            const SizedBox(height: 10),
            const Text('Use “Add a record → Import from ABHA” to bring in records from linked hospitals.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.bad, side: const BorderSide(color: AppColors.bad)),
              onPressed: () {
                s.unlinkAbha();
                Navigator.pop(ctx);
              },
              child: const Text('Unlink ABHA'),
            ),
          ]),
        ),
      ),
    );
  }

  void _linkAbha(BuildContext context) {
    final s = AppScope.read(context);
    final ctrl = TextEditingController();
    final otp = TextEditingController();
    var sent = false;
    String? error;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(22, 14, 22, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            Text('Link ABHA', style: serif(22)),
            const SizedBox(height: 6),
            Text(sent ? 'Enter the 6-digit OTP sent to your Aadhaar-linked mobile (demo: any 6 digits).' : 'Enter your 14-digit ABHA number.',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            if (!sent)
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                maxLength: 14,
                decoration: InputDecoration(hintText: '14 digits', errorText: error),
              )
            else
              TextField(
                controller: otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(hintText: 'OTP', errorText: error),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (!sent) {
                    final d = ctrl.text.replaceAll(RegExp(r'\D'), '');
                    if (d.length != 14) {
                      set(() => error = 'ABHA number has 14 digits');
                      return;
                    }
                    await withLoading(ctx, Anim.ringingPhone, 'Sending OTP to your mobile…', () async {}, minMs: 1600);
                    set(() {
                      sent = true;
                      error = null;
                    });
                  } else {
                    if (otp.text.trim().length != 6) {
                      set(() => error = 'Enter the 6-digit OTP');
                      return;
                    }
                    final d = ctrl.text.replaceAll(RegExp(r'\D'), '');
                    await withLoading(ctx, Anim.healthShield, 'Linking securely…', () async {}, minMs: 1400);
                    if (!ctx.mounted) return;
                    s.linkAbha('${d.substring(0, 2)}-${d.substring(2, 6)}-${d.substring(6, 10)}-${d.substring(10)}');
                    Navigator.pop(ctx);
                    toast(context, 'ABHA linked (demo — real ABDM linking comes with the backend)');
                  }
                },
                child: Text(sent ? 'Verify & link' : 'Send OTP'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
