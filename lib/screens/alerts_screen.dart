import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'medicines_screen.dart';
import 'record_detail_screen.dart';
import 'trends_screen.dart';
import 'visits_screen.dart';

(Color, Color, IconData) alertStyle(AlertKind k) => switch (k) {
      AlertKind.critical => (AppColors.bad, AppColors.badSoft, Icons.priority_high_rounded),
      AlertKind.duplicateTest => (AppColors.warn, AppColors.warnSoft, Icons.content_copy_rounded),
      AlertKind.trend => (AppColors.info, AppColors.infoSoft, Icons.trending_down_rounded),
      AlertKind.drugOverlap => (AppColors.accent, AppColors.accentSoft, Icons.medication_liquid_outlined),
      AlertKind.refill => (AppColors.good, AppColors.goodSoft, Icons.inventory_2_outlined),
      AlertKind.visit => (AppColors.primary, AppColors.primarySoft, Icons.event_available_outlined),
    };

/// Routes an alert's call-to-action to the right screen for the right member.
void openAlert(BuildContext context, HealthAlert a) {
  final s = AppScope.read(context);
  s.setMember(a.memberId);
  switch (a.kind) {
    case AlertKind.critical:
    case AlertKind.duplicateTest:
      if (a.recordId != null && s.record(a.recordId!) != null) {
        push(context, RecordDetailScreen(recordId: a.recordId!));
      }
    case AlertKind.trend:
      push(context, const LabTrendsScreen());
    case AlertKind.drugOverlap:
    case AlertKind.refill:
      push(context, const MedicinesScreen());
    case AlertKind.visit:
      push(context, VisitDetailScreen(appointmentId: a.id.replaceFirst('visit-', '')));
  }
}

class AlertCard extends StatelessWidget {
  final HealthAlert a;
  final bool showDismiss;
  const AlertCard(this.a, {super.key, this.showDismiss = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final (color, soft, icon) = alertStyle(a.kind);
    final m = s.member(a.memberId);
    return PaperCard(
      onTap: () => openAlert(context, a),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m.name.split(' ').first} · ${m.relation}'.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    const SizedBox(height: 3),
                    Text(a.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(a.body,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('${a.cta} →',
                        style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (showDismiss && a.kind != AlertKind.critical)
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => s.dismissAlert(a.id),
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.alerts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (s.dismissedAlerts.isNotEmpty)
            TextButton(
                onPressed: () {
                  s.restoreAlerts();
                  toast(context, 'Dismissed alerts restored');
                },
                child: const Text('Restore')),
        ],
      ),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.verified_outlined,
              title: 'All clear',
              body: 'Nothing needs your attention right now.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => i == 0
                  ? const Text(
                      'Found automatically from your family\'s records. Urgent alerts can\'t be dismissed.',
                      style: TextStyle(color: AppColors.muted))
                  : AlertCard(list[i - 1], showDismiss: true),
            ),
    );
  }
}
