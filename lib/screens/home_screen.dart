import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alerts_screen.dart';
import 'ask_screen.dart';
import 'emergency_screen.dart';
import 'family_screens.dart';
import 'health_card_screen.dart';
import 'medicines_screen.dart';
import 'shell.dart';
import 'trends_screen.dart';
import 'visits_screen.dart';
import 'womens_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.activeMember;
    final alerts = s.alerts;
    final meds = s.medsFor(me.id);
    final doses = [
      for (final m in meds)
        for (final t in m.times.where((t) => t != 'SOS')) (m, t)
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final taken = doses.where((d) => s.isTaken(d.$1.id, d.$2)).length;
    final visits = s.upcoming(memberId: me.id);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${context.tr('greet')}, ${s.userName.split(' ').first}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(context.tr('family_health'), style: serif(26, w: FontWeight.w700)),
                ]),
              ),
              _RoundIcon(
                icon: Icons.notifications_none_rounded,
                badge: alerts.length,
                onTap: () => push(context, const AlertsScreen()),
              ),
              const SizedBox(width: 8),
              _RoundIcon(
                icon: Icons.sos_rounded,
                color: AppColors.bad,
                onTap: () => push(context, const EmergencyScreen()),
              ),
            ]),
            const SizedBox(height: 18),
            const _MemberSwitcher(),
            const SizedBox(height: 14),
            PaperCard(
              color: AppColors.primary,
              borderColor: AppColors.primary,
              onTap: () => push(context, MemberFormScreen(member: me)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${me.name.split(' ').first} · ${me.relation}',
                        style: serif(19, c: Colors.white)),
                    const SizedBox(height: 4),
                    Text('${me.age} yrs · ${me.gender} · ${me.bloodGroup}',
                        style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                    const SizedBox(height: 12),
                    Row(children: [
                      _stat('${s.recordsFor(me.id).length}', 'records'),
                      const SizedBox(width: 18),
                      _stat('${meds.length}', 'medicines'),
                      const SizedBox(width: 18),
                      _stat('${(s.adherence(me.id) * 100).round()}%', 'doses taken'),
                    ]),
                  ]),
                ),
                const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
              ]),
            ),
            SectionTitle(context.tr('needs_attention'),
                action: alerts.length > 3 ? 'All ${alerts.length}' : null,
                onAction: () => push(context, const AlertsScreen())),
            if (alerts.isEmpty)
              PaperCard(
                color: AppColors.goodSoft,
                borderColor: Colors.transparent,
                child: Row(children: [
                  const Icon(Icons.verified_outlined, color: AppColors.good),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('all_clear'))),
                ]),
              )
            else
              for (final a in alerts.take(3)) ...[
                AlertCard(a),
                const SizedBox(height: 10),
              ],
            SectionTitle(context.tr('quick')),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .95,
              children: [
                _Action(Icons.compare_arrows_rounded, context.tr('compare_opinions'),
                    AppColors.accent, () => MainShell.of(context)?.go(2)),
                _Action(Icons.show_chart_rounded, context.tr('lab_trends'), AppColors.info,
                    () => push(context, const LabTrendsScreen())),
                _Action(Icons.medication_outlined, context.tr('medicines'), AppColors.good,
                    () => push(context, const MedicinesScreen())),
                _Action(Icons.event_note_outlined, context.tr('visits'), AppColors.primary,
                    () => push(context, const VisitsScreen())),
                _Action(Icons.record_voice_over_outlined, context.tr('ask_hindi'),
                    AppColors.warn, () => push(context, const AskScreen())),
                _Action(Icons.qr_code_2_rounded, context.tr('health_card'),
                    AppColors.primaryDark, () => push(context, const HealthCardScreen())),
                if (me.gender == 'Female')
                  _Action(Icons.female_rounded, context.tr('womens'), AppColors.onlyB,
                      () => push(context, const WomensHealthScreen())),
              ],
            ),
            SectionTitle(
                doses.isEmpty
                    ? context.tr('today_meds')
                    : '${context.tr('today_meds')} · $taken/${doses.length}',
                action: 'All',
                onAction: () => push(context, const MedicinesScreen())),
            if (doses.isEmpty)
              PaperCard(
                onTap: () => push(context, const MedicinesScreen()),
                child: const Text('No scheduled medicines. Tap to add one.',
                    style: TextStyle(color: AppColors.muted)),
              )
            else
              PaperCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final d in doses) DoseRow(med: d.$1, time: d.$2),
                ]),
              ),
            SectionTitle(context.tr('upcoming'),
                action: 'All', onAction: () => push(context, const VisitsScreen())),
            if (visits.isEmpty)
              PaperCard(
                onTap: () => push(context, const VisitFormScreen()),
                child: const Row(children: [
                  Icon(Icons.add_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Add a doctor visit',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              for (final a in visits.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: VisitTile(a),
                ),
            const SizedBox(height: 8),
            DisclaimerNote(context.tr('disclaimer')),
          ],
        ),
      ),
    );
  }

  static Widget _stat(String n, String l) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: serif(20, c: Colors.white)),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final Color color;
  final VoidCallback onTap;
  const _RoundIcon(
      {required this.icon, required this.onTap, this.badge = 0, this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: AppColors.accent,
      child: IconButton.outlined(
        style: IconButton.styleFrom(side: const BorderSide(color: AppColors.border)),
        onPressed: onTap,
        icon: Icon(icon, color: color),
      ),
    );
  }
}

class _MemberSwitcher extends StatelessWidget {
  const _MemberSwitcher();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return SizedBox(
      height: 78,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final m in s.members)
          GestureDetector(
            onTap: () => s.setMember(m.id),
            onLongPress: () => push(context, MemberFormScreen(member: m)),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(children: [
                Avatar(m, size: 52, selected: s.activeMemberId == m.id),
                const SizedBox(height: 4),
                Text(m.relation,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            s.activeMemberId == m.id ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        GestureDetector(
          onTap: () => push(context, const MemberFormScreen()),
          child: Column(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5)),
              child: const Icon(Icons.add, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            const Text('Add', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2)),
          ]),
    );
  }
}
