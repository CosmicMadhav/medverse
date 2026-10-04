import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_detail_screen.dart';
import 'records_screen.dart';

class WomensHealthScreen extends StatefulWidget {
  const WomensHealthScreen({super.key});
  @override
  State<WomensHealthScreen> createState() => _WomensHealthScreenState();
}

class _WomensHealthScreenState extends State<WomensHealthScreen> {
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.activeMember;
    return Scaffold(
      appBar: AppBar(title: const Text('Women\'s health'), actions: const [MemberButton()]),
      body: me.gender != 'Female'
          ? EmptyState(
              icon: Icons.female_rounded,
              title: 'For women in your family',
              body: 'Switch to a female family member to use cycle and pregnancy tracking.',
              action: OutlinedButton(onPressed: () => pickMember(context), child: const Text('Switch member')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.primarySoft),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('My health')),
                    ButtonSegment(value: 1, label: Text('Cycle')),
                    ButtonSegment(value: 2, label: Text('Pregnancy')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
                const SizedBox(height: 16),
                ...switch (_tab) {
                  0 => _myHealth(s, me),
                  1 => _cycle(s),
                  _ => _pregnancy(s),
                },
                const SizedBox(height: 16),
                const Row(children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.muted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Cycle and pregnancy data stay on this phone and are never on shared cards.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ),
                ]),
              ],
            ),
    );
  }

  // ───────── My health: built from this member's own records ─────────
  List<Widget> _myHealth(AppState s, FamilyMember me) {
    final recs = s.recordsFor(me.id, includePrivate: s.vaultUnlocked);
    LabParam? find(String name) {
      for (final r in recs) {
        for (final p in r.params) {
          if (p.name == name) return p;
        }
      }
      return null;
    }

    String? recordWith(String name) =>
        recs.where((r) => r.params.any((p) => p.name == name)).firstOrNull?.id;

    final hb = find('Haemoglobin');
    final tsh = find('TSH');
    final vitD = find('Vitamin D');
    final pcos = me.conditions.any((c) => c.toLowerCase().contains('pcos'));
    return [
      Text('Things to keep an eye on', style: serif(19)),
      const SizedBox(height: 4),
      const Text('Common health issues for Indian women, checked against your records.',
          style: TextStyle(color: AppColors.muted, fontSize: 13)),
      const SizedBox(height: 12),
      _topic(
        Icons.bloodtype_outlined,
        AppColors.bad,
        'Anaemia (low haemoglobin)',
        hb == null ? 'Not tested yet' : 'Hb ${hb.value} g/dL — ${hb.status == ParamStatus.normal ? 'normal' : 'below normal'}',
        'About half of Indian women have anaemia. Iron-rich food (jaggery, spinach, chana, dates) and the iron tablet from your doctor help. Take iron with lemon or amla, not with tea.',
        hb == null ? null : recordWith('Haemoglobin'),
        ok: hb != null && hb.status == ParamStatus.normal,
      ),
      _topic(
        Icons.water_drop_outlined,
        AppColors.info,
        'Thyroid',
        tsh == null ? 'Not tested yet' : 'TSH ${tsh.value} — ${tsh.status == ParamStatus.normal ? 'normal' : 'mildly high'}',
        'Thyroid problems are common in women and can cause tiredness, weight change and irregular periods. A repeat test is usually advised after 6–8 weeks.',
        tsh == null ? null : recordWith('TSH'),
        ok: tsh != null && tsh.status == ParamStatus.normal,
      ),
      _topic(
        Icons.spa_outlined,
        AppColors.onlyB,
        'PCOS',
        pcos ? 'Diagnosed — on your conditions list' : 'No diagnosis recorded',
        'PCOS can cause irregular or long cycles. Regular exercise and a balanced diet are the first steps; your cycle log helps your gynaecologist.',
        null,
        ok: !pcos,
      ),
      _topic(
        Icons.wb_sunny_outlined,
        AppColors.warn,
        'Vitamin D',
        vitD == null ? 'Not tested yet — ask your doctor' : 'Vitamin D ${vitD.value} ng/mL',
        'Very common deficiency in women who spend most time indoors. 15–20 minutes of morning sun helps.',
        vitD == null ? null : recordWith('Vitamin D'),
        ok: vitD != null && vitD.status == ParamStatus.normal,
      ),
      _topic(
        Icons.health_and_safety_outlined,
        AppColors.primary,
        'Cervical & breast screening',
        me.age >= 30 ? 'Recommended for your age' : 'From age 30',
        'Free screening for cervical and breast cancer is available at government health & wellness centres for women 30+.',
        null,
        ok: me.age < 30,
      ),
    ];
  }

  Widget _topic(IconData i, Color c, String title, String status, String body, String? recordId, {bool ok = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PaperCard(
          onTap: recordId == null ? null : () => push(context, RecordDetailScreen(recordId: recordId)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
              child: Icon(i, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (ok) const Icon(Icons.check_circle_outline, color: AppColors.good, size: 18),
                ]),
                Text(status, style: TextStyle(color: ok ? AppColors.good : c, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
                if (recordId != null) ...[
                  const SizedBox(height: 6),
                  const Text('See report →',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ]),
            ),
          ]),
        ),
      );

  // ───────── Cycle ─────────
  List<DateTime> _periodStarts(Set<DateTime> days) {
    final sorted = days.toList()..sort();
    final starts = <DateTime>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i == 0 || sorted[i].difference(sorted[i - 1]).inDays > 1) starts.add(sorted[i]);
    }
    return starts;
  }

  List<Widget> _cycle(AppState s) {
    final starts = _periodStarts(s.periodDays);
    final gaps = [for (var i = 1; i < starts.length; i++) starts[i].difference(starts[i - 1]).inDays];
    final avg = gaps.isEmpty ? 28 : (gaps.reduce((a, b) => a + b) / gaps.length).round();
    final next = starts.isEmpty ? null : starts.last.add(Duration(days: avg));
    final today = DateUtils.dateOnly(DateTime.now());
    final dayOfCycle = starts.isEmpty ? null : today.difference(starts.last).inDays + 1;
    final fertileStart = next?.subtract(const Duration(days: 18));
    final fertileEnd = next?.subtract(const Duration(days: 12));

    final first = _month;
    final daysInMonth = DateUtils.getDaysInMonth(first.year, first.month);
    final lead = first.weekday - 1;
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return [
      Row(children: [
        Expanded(child: _stat(dayOfCycle == null ? '—' : 'Day $dayOfCycle', 'of cycle')),
        const SizedBox(width: 10),
        Expanded(child: _stat('$avg days', 'average cycle')),
        const SizedBox(width: 10),
        Expanded(child: _stat(next == null ? '—' : fmtShort(next), 'next period')),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(child: Center(child: Text('${monthNames[first.month - 1]} ${first.year}', style: serif(18)))),
        IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      Row(children: [
        for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
              child: Center(
                  child: Text(d, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)))),
      ]),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        children: [
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var d = 1; d <= daysInMonth; d++)
            Builder(builder: (_) {
              final day = DateTime(first.year, first.month, d);
              final period = s.periodDays.contains(day);
              final predicted = next != null && !day.isBefore(next) && day.isBefore(next.add(const Duration(days: 5)));
              final fertile = fertileStart != null && !day.isBefore(fertileStart) && !day.isAfter(fertileEnd!);
              final isToday = day == today;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: day.isAfter(today) ? null : () => s.togglePeriodDay(day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: period
                        ? AppColors.accent
                        : fertile
                            ? AppColors.mustardSoft
                            : AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? AppColors.text
                          : predicted
                              ? AppColors.accent
                              : AppColors.border,
                      width: isToday || predicted ? 1.6 : 1,
                    ),
                  ),
                  child: Text('$d',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: period
                              ? Colors.white
                              : day.isAfter(today)
                                  ? AppColors.muted
                                  : AppColors.text)),
                ),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      const Wrap(spacing: 12, runSpacing: 6, children: [
        Pill('Period', color: Colors.white, bg: AppColors.accent),
        Pill('Predicted', color: AppColors.accent, bg: AppColors.accentSoft),
        Pill('Likely fertile', color: AppColors.warn, bg: AppColors.mustardSoft),
      ]),
      const SizedBox(height: 8),
      const Text('Tap a past day to mark or unmark a period day.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 14),
      PaperCard(
        child: Text(
          gaps.isEmpty
              ? 'Log at least two periods to see your cycle length.'
              : avg > 35
                  ? 'Your cycles average $avg days — longer than the usual 21–35. This can happen with PCOS or thyroid issues. Bring this log to your gynaecologist.'
                  : 'Your cycles average $avg days, within the usual 21–35 day range.',
          style: const TextStyle(height: 1.45),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          final b = StringBuffer('Period log — ${s.activeMember.name}\n');
          for (final st in starts) {
            b.writeln('• ${fmtDate(st)}');
          }
          b.writeln('Average cycle: $avg days');
          Exporter.shareText(b.toString(), subject: 'Period log');
        },
        icon: const Icon(Icons.ios_share_rounded),
        label: const Text('Share log with doctor'),
      ),
    ];
  }

  Widget _stat(String v, String l) => PaperCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: serif(17, w: FontWeight.w700)),
          Text(l, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      );

  // ───────── Pregnancy ─────────
  static const _anc = [
    ('First check-up & registration', 'Before 12 weeks', 12),
    ('Second check-up', '14–26 weeks', 26),
    ('Third check-up', '28–34 weeks', 34),
    ('Fourth check-up', '36 weeks – delivery', 40),
  ];
  static const _sizes = {
    8: 'a rajma bean', 12: 'a lemon', 16: 'an avocado', 20: 'a banana', 24: 'a corn cob',
    28: 'a brinjal', 32: 'a papaya', 36: 'a lettuce', 40: 'a small watermelon',
  };

  List<Widget> _pregnancy(AppState s) {
    final lmp = s.lmp;
    if (lmp == null) {
      return [
        Text('Track a pregnancy', style: serif(20)),
        const SizedBox(height: 6),
        const Text('Enter the first day of the last period. MedVerse works out the week, the due date and when each check-up is due.',
            style: TextStyle(color: AppColors.muted, height: 1.45)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 60)),
                firstDate: DateTime.now().subtract(const Duration(days: 300)),
                lastDate: DateTime.now(),
                helpText: 'First day of last period');
            if (d != null) s.setLmp(d);
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Set last period date'),
        ),
      ];
    }
    final days = DateTime.now().difference(lmp).inDays;
    final week = (days / 7).floor().clamp(0, 42);
    final dayInWeek = days % 7;
    final edd = lmp.add(const Duration(days: 280));
    final trimester = week < 13 ? 1 : week < 27 ? 2 : 3;
    final size = _sizes.entries.lastWhere((e) => week >= e.key, orElse: () => const MapEntry(0, 'a poppy seed')).value;
    return [
      PaperCard(
        color: AppColors.accentSoft,
        borderColor: Colors.transparent,
        child: Row(children: [
          Text('$week', style: serif(52, c: AppColors.accent, w: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('weeks $dayInWeek days · trimester $trimester\nBaby is about the size of $size.',
                style: const TextStyle(height: 1.45)),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
            value: (days / 280).clamp(0, 1), minHeight: 8, color: AppColors.accent, backgroundColor: AppColors.border),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Text('Due date: ${fmtDate(edd)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final ok = await confirm(context, 'Stop tracking?', 'The pregnancy dates and check-up ticks will be cleared.',
                ok: 'Stop');
            if (ok) s.setLmp(null);
          },
          child: const Text('Stop tracking'),
        ),
      ]),
      const SectionTitle('Antenatal check-ups (ANC)'),
      for (var i = 0; i < _anc.length; i++)
        Builder(builder: (_) {
          final due = lmp.add(Duration(days: _anc[i].$3 * 7));
          final overdue = !s.ancDone.contains(i) && week > _anc[i].$3;
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            value: s.ancDone.contains(i),
            onChanged: (_) => s.toggleAnc(i),
            title: Text(_anc[i].$1, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${_anc[i].$2} · by ${fmtDate(due)}${overdue ? ' · overdue' : ''}',
                style: TextStyle(color: overdue ? AppColors.bad : null)),
          );
        }),
      const SizedBox(height: 6),
      const DisclaimerNote(
          'Free antenatal check-ups are available under PMSMA on the 9th of every month at government hospitals. Take iron-folic acid tablets as advised.'),
      const SectionTitle('Warning signs — go to hospital'),
      for (final w in [
        'Bleeding from the vagina',
        'Severe headache or blurred vision',
        'Swelling of face and hands',
        'Fever, or baby moving less than usual',
        'Water breaking before 37 weeks',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.bad),
            const SizedBox(width: 8),
            Expanded(child: Text(w)),
          ]),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
        onPressed: () => Exporter.call('102'),
        icon: const Icon(Icons.call),
        label: const Text('Call 102 — free pregnancy ambulance'),
      ),
    ];
  }
}
