import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'compare_screen.dart';
import 'record_detail_screen.dart';
import 'records_screen.dart';
import 'visits_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});
  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.activeMember;
    final events = <TimelineEvent>[
      for (final r in s.recordsFor(me.id))
        TimelineEvent(
          r.date,
          r.title,
          '${r.doctor} · ${r.hospital}',
          r.type.icon,
          r.hasCritical
              ? AppColors.bad
              : r.type == RecordType.prescription
                  ? AppColors.accent
                  : AppColors.primary,
          recordId: r.id,
          kind: r.type == RecordType.prescription ? 'Prescriptions' : 'Tests',
        ),
      for (final a in s.appointments.where((a) => a.memberId == me.id))
        TimelineEvent(a.when, 'Visit: ${a.doctor}', '${a.purpose} · ${a.place}',
            Icons.event_note_outlined, AppColors.info,
            recordId: a.id, kind: 'Visits'),
      for (final c in s.casesFor(me.id))
        TimelineEvent(c.doctorBDate, 'Compared: ${c.condition}',
            '${c.doctorAName} vs ${c.doctorBName}', Icons.compare_arrows_rounded, AppColors.onlyB,
            recordId: c.id, kind: 'Comparisons'),
    ]
        .where((e) => _filter == 'All' || e.kind == _filter)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final groups = <String, List<TimelineEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(fmtMonth(e.date), () => []).add(e);
    }
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text('${me.name.split(' ').first}\'s journey'), actions: const [MemberButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          const Text('Every visit, test and prescription in order — so you never lose the thread.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in ['All', 'Tests', 'Prescriptions', 'Visits', 'Comparisons'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                ),
            ]),
          ),
          if (events.isEmpty)
            const EmptyState(icon: Icons.timeline_outlined, title: 'Nothing here yet', body: 'Records and visits will appear here.'),
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Text(g.key, style: serif(17, c: AppColors.primary)),
            ),
            for (var i = 0; i < g.value.length; i++)
              _Row(e: g.value[i], last: i == g.value.length - 1, future: g.value[i].date.isAfter(now)),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final TimelineEvent e;
  final bool last;
  final bool future;
  const _Row({required this.e, required this.last, required this.future});

  void _open(BuildContext context) {
    final id = e.recordId;
    if (id == null) return;
    switch (e.kind) {
      case 'Visits':
        push(context, VisitDetailScreen(appointmentId: id));
      case 'Comparisons':
        push(context, OpinionDiffScreen(caseId: id));
      default:
        push(context, RecordDetailScreen(recordId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 44,
          child: Column(children: [
            Text('${e.date.day}', style: serif(18)),
            const SizedBox(height: 4),
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: future ? Colors.transparent : e.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: future ? e.color : AppColors.bg, width: 2))),
            if (!last) Expanded(child: Container(width: 2, color: AppColors.border)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PaperCard(
              onTap: () => _open(context),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(e.icon, color: e.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(e.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                if (future) const Pill('Upcoming', color: AppColors.info),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
