import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'records_screen.dart';

class DoseRow extends StatelessWidget {
  final Medicine med;
  final String time;
  const DoseRow({super.key, required this.med, required this.time});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final done = s.isTaken(med.id, time);
    return ListTile(
      onTap: () => s.toggleDose(med.id, time),
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: done ? AppColors.good : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: done ? AppColors.good : AppColors.border, width: 2),
        ),
        child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
      title: Text(med.name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: done ? TextDecoration.lineThrough : null,
              color: done ? AppColors.muted : AppColors.text)),
      subtitle: Text('${med.dose} · ${med.food}', style: const TextStyle(fontSize: 12)),
      trailing: Text(time, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }
}

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.activeMember;
    final meds = s.medsFor(me.id);
    final slots = <String, List<Medicine>>{};
    for (final m in meds) {
      for (final t in m.times) {
        slots.putIfAbsent(t, () => []).add(m);
      }
    }
    final keys = slots.keys.where((k) => k != 'SOS').toList()..sort();
    final overlaps = s.alerts.where((a) => a.memberId == me.id && a.kind == AlertKind.drugOverlap);
    final shared = meds.where((m) => m.prescribedBy.contains('&'));
    final adherence = s.adherence(me.id);

    return Scaffold(
      appBar: AppBar(title: Text('${me.name.split(' ').first}\'s medicines'), actions: const [MemberButton()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => push(context, const MedicineFormScreen()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add medicine'),
      ),
      body: meds.isEmpty
          ? const EmptyState(
              icon: Icons.medication_outlined,
              anim: Anim.medicalPill,
              title: 'No medicines yet',
              body: 'Add a medicine, or save a prescription and MedVerse will list them.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              children: [
                _AdherenceCard(memberId: me.id, value: adherence),
                for (final a in overlaps) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.badSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.bad),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(a.body, style: const TextStyle(fontSize: 13, height: 1.4)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              s.addVisitNote('${a.title}: ${a.body.split('.').first}. Which one should I keep?');
                              toast(context, 'Added to questions for your next visit');
                            },
                            child: const Text('Add to my questions →',
                                style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ],
                for (final m in shared) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.goodSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.merge_type_rounded, color: AppColors.good),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('${m.name} was prescribed by both doctors — take it only once.',
                              style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
                ],
                for (final k in keys) ...[
                  SectionTitle(_slotName(k)),
                  PaperCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final m in slots[k]!)
                        InkWell(
                          onLongPress: () => _details(context, m),
                          child: DoseRow(med: m, time: k),
                        ),
                    ]),
                  ),
                ],
                if (slots['SOS'] != null) ...[
                  const SectionTitle('Only when needed (SOS)'),
                  PaperCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final m in slots['SOS']!)
                        ListTile(
                          onTap: () => _details(context, m),
                          leading: const Icon(Icons.medication_rounded, color: AppColors.muted),
                          title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${m.purpose} · ${m.food}', style: const TextStyle(fontSize: 12)),
                        ),
                    ]),
                  ),
                ],
                const SectionTitle('All medicines'),
                for (final m in meds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PaperCard(
                      onTap: () => _details(context, m),
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.medication_outlined, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${m.purpose}\nBy ${m.prescribedBy}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                        Text('${m.daysLeft}d left',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: m.daysLeft <= 5 ? AppColors.accent : AppColors.muted)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 8),
                const DisclaimerNote('Never stop or change a medicine without asking your doctor.'),
              ],
            ),
    );
  }

  static String _slotName(String t) {
    final h = int.tryParse(t.split(':').first) ?? 0;
    final label = h < 12 ? 'Morning' : h < 17 ? 'Afternoon' : 'Night';
    return '$label · $t';
  }

  static void _details(BuildContext context, Medicine m) {
    final s = AppScope.read(context);
    final howTo =
        '${m.name}. ${m.dose}, ${m.times.contains('SOS') ? 'only when needed' : 'at ${m.times.join(' and ')}'}, ${m.food}. For ${m.purpose}.';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            Text(m.name, style: serif(22)),
            Text(m.generic, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            _kv('Dose', m.dose),
            _kv('When', m.times.join(', ')),
            _kv('Food', m.food),
            _kv('For', m.purpose),
            _kv('Prescribed by', m.prescribedBy),
            if (m.drugClass.isNotEmpty) _kv('Medicine type', m.drugClass),
            _kv('Stock', '${m.daysLeft} days left'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Voice.instance.speak('med-${m.id}', howTo, hindi: false),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('How to take'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bad, side: const BorderSide(color: AppColors.bad)),
                  onPressed: () async {
                    final ok = await confirm(ctx, 'Remove ${m.name}?',
                        'Only remove it if the doctor has stopped this medicine.', ok: 'Remove');
                    if (!ok) return;
                    s.deleteMedicine(m.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _AdherenceCard extends StatelessWidget {
  final String memberId;
  final double value;
  const _AdherenceCard({required this.memberId, required this.value});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final meds = s.medsFor(memberId);
    final days = [for (var d = 6; d >= 0; d--) today.subtract(Duration(days: d))];
    double dayRate(DateTime day) {
      var due = 0, done = 0;
      for (final m in meds) {
        for (final t in m.times.where((t) => t != 'SOS')) {
          due++;
          if (s.isTaken(m.id, t, day)) done++;
        }
      }
      return due == 0 ? 1 : done / due;
    }

    const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return PaperCard(
      child: Row(children: [
        const AnimView(Anim.medicalPill, size: 64),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(value * 100).round()}%', style: serif(32, w: FontWeight.w700, c: AppColors.primary)),
          const Text('doses taken\nlast 7 days', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        const Spacer(),
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Column(children: [
              Container(
                width: 22,
                height: 40,
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
                child: FractionallySizedBox(
                  heightFactor: dayRate(d).clamp(.06, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: dayRate(d) >= .99
                          ? AppColors.good
                          : dayRate(d) > 0
                              ? AppColors.mustard
                              : AppColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(wd[d.weekday - 1],
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: d == today ? FontWeight.w800 : FontWeight.w400,
                      color: d == today ? AppColors.text : AppColors.muted)),
            ]),
          ),
      ]),
    );
  }
}

class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({super.key});
  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _purpose = TextEditingController();
  final _doctor = TextEditingController();
  final _days = TextEditingController(text: '30');
  String _dose = '1 tablet';
  String _food = 'After food';
  String _type = '';
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 9, minute: 0)];
  bool _sos = false;

  @override
  void dispose() {
    for (final c in [_name, _purpose, _doctor, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _save() {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    final newClass = _type;
    s.addMedicine(Medicine(
      id: 'md${DateTime.now().microsecondsSinceEpoch}',
      memberId: s.activeMemberId,
      name: _name.text.trim(),
      generic: _type.isEmpty ? _name.text.trim() : _type,
      drugClass: newClass,
      dose: _dose,
      times: _sos ? ['SOS'] : (_times.map(_fmt).toList()..sort()),
      prescribedBy: _doctor.text.trim().isEmpty ? 'Self-added' : _doctor.text.trim(),
      purpose: _purpose.text.trim().isEmpty ? '—' : _purpose.text.trim(),
      food: _food,
      daysLeft: int.tryParse(_days.text) ?? 30,
    ));
    final clash = s.medsFor(s.activeMemberId).where((m) => newClass.isNotEmpty && m.drugClass == newClass).length > 1;
    toast(context, clash ? 'Added — but another $newClass medicine is already listed. Check with a doctor.' : 'Added');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Add for ${s.activeMember.name.split(' ').first}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: _save, child: const Text('Save medicine')),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
          const FieldLabel('Medicine name & strength'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Paracetamol 650mg'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the medicine name' : null,
          ),
          const FieldLabel('Type (helps catch duplicates)'),
          ChoiceRow(
            options: const ['NSAID', 'Antibiotic', 'Paracetamol', 'Antacid', 'Iron', 'Calcium', 'Vitamin D', 'Other'],
            value: _type,
            onChanged: (v) => setState(() => _type = _type == v ? '' : v),
          ),
          const FieldLabel('Dose'),
          ChoiceRow(
            options: const ['½ tablet', '1 tablet', '2 tablets', '5 ml', '10 ml', '1 sachet weekly'],
            value: _dose,
            onChanged: (v) => setState(() => _dose = v),
          ),
          const FieldLabel('When'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only when needed (SOS)'),
            value: _sos,
            onChanged: (v) => setState(() => _sos = v),
          ),
          if (!_sos)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < _times.length; i++)
                InputChip(
                  avatar: const Icon(Icons.schedule, size: 16),
                  label: Text(_fmt(_times[i])),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _times[i]);
                    if (t != null) setState(() => _times[i] = t);
                  },
                  onDeleted: _times.length > 1 ? () => setState(() => _times.removeAt(i)) : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add time'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
                  if (t != null) setState(() => _times.add(t));
                },
              ),
            ]),
          const FieldLabel('Food'),
          ChoiceRow(
            options: const ['Before food', 'After food', 'With food', 'Empty stomach', 'At bedtime'],
            value: _food,
            onChanged: (v) => setState(() => _food = v),
          ),
          const FieldLabel('What is it for?'),
          TextFormField(controller: _purpose, decoration: const InputDecoration(hintText: 'e.g. Knee pain')),
          const FieldLabel('Prescribed by'),
          TextFormField(controller: _doctor, decoration: const InputDecoration(hintText: 'Doctor\'s name')),
          const FieldLabel('Days of stock left'),
          TextFormField(controller: _days, keyboardType: TextInputType.number),
        ]),
      ),
    );
  }
}
