import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'compare_screen.dart';
import 'records_screen.dart';

class VisitTile extends StatelessWidget {
  final Appointment a;
  final bool showMember;
  const VisitTile(this.a, {super.key, this.showMember = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final past = a.when.isBefore(DateTime.now());
    return PaperCard(
      onTap: () => push(context, VisitDetailScreen(appointmentId: a.id)),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: past ? AppColors.bg : AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('${a.when.day}', style: serif(20, c: past ? AppColors.muted : AppColors.text)),
            Text(fmtShort(a.when).split(' ').last,
                style: TextStyle(fontSize: 12, color: past ? AppColors.muted : AppColors.primary)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.doctor, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${a.purpose}\n${a.place} · ${fmtTime(a.when)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if (!past) ...[
              const SizedBox(height: 6),
              Pill(relDay(a.when), color: AppColors.primary),
            ],
          ]),
        ),
        if (showMember) Avatar(s.member(a.memberId), size: 32),
      ]),
    );
  }
}

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});
  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  bool _everyone = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final list = s.appointments.where((a) => _everyone || a.memberId == s.activeMemberId).toList();
    final up = list.where((a) => a.when.isAfter(now)).toList()..sort((a, b) => a.when.compareTo(b.when));
    final past = list.where((a) => !a.when.isAfter(now)).toList()..sort((a, b) => b.when.compareTo(a.when));
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor visits'), actions: const [MemberButton()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => push(context, const VisitFormScreen()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add visit'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show whole family'),
            value: _everyone,
            onChanged: (v) => setState(() => _everyone = v),
          ),
          const SectionTitle('Upcoming'),
          if (up.isEmpty)
            const EmptyState(
                icon: Icons.event_busy_outlined,
                anim: Anim.ringingPhone,
                title: 'No upcoming visits',
                body: 'Add a visit and MedVerse will remind you and get your questions ready.')
          else
            for (final a in up)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: VisitTile(a, showMember: _everyone)),
          if (past.isNotEmpty) ...[
            const SectionTitle('Past'),
            for (final a in past)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: VisitTile(a, showMember: _everyone)),
          ],
        ],
      ),
    );
  }
}

class VisitDetailScreen extends StatelessWidget {
  final String appointmentId;
  const VisitDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.appointments.where((x) => x.id == appointmentId).firstOrNull;
    if (a == null) return const Scaffold(body: SizedBox());
    final m = s.member(a.memberId);
    final c = a.caseId == null ? null : s.caseById(a.caseId!);
    final caseQs = c == null
        ? <String>[]
        : [
            for (final (i, q) in s.questionsFor(c.id).indexed)
              if (s.isQuestionSelected(c.id, i)) q
          ];
    final notes = s.visitNotes.toList();
    final recent = s.recordsFor(m.id).take(3).toList();

    String prep() {
      final b = StringBuffer('Visit: ${a.doctor} (${a.speciality})\n${fmtDate(a.when)} ${fmtTime(a.when)} · ${a.place}\nPatient: ${m.name}, ${m.age} yrs\n\n');
      if (m.allergies.isNotEmpty) b.writeln('Allergies: ${m.allergies.join(', ')}');
      final meds = s.medsFor(m.id);
      if (meds.isNotEmpty) b.writeln('Current medicines: ${meds.map((x) => x.name).join(', ')}');
      final qs = [...caseQs, ...notes];
      if (qs.isNotEmpty) {
        b.writeln('\nQuestions:');
        for (var i = 0; i < qs.length; i++) {
          b.writeln('${i + 1}. ${qs[i]}');
        }
      }
      b.writeln('\n— Prepared with MedVerse');
      return b.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit'),
        actions: [
          IconButton(onPressed: () => Exporter.shareText(prep(), subject: 'Visit with ${a.doctor}'), icon: const Icon(Icons.ios_share_rounded)),
          IconButton(
            onPressed: () async {
              final ok = await confirm(context, 'Delete this visit?', '${a.doctor} on ${fmtDate(a.when)}');
              if (!ok || !context.mounted) return;
              Navigator.pop(context);
              s.deleteAppointment(a.id);
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(a.doctor, style: serif(26, w: FontWeight.w700)),
          Text('${a.speciality} · ${a.place}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Pill('${fmtDate(a.when)} · ${fmtTime(a.when)}', color: AppColors.primary, icon: Icons.event_outlined),
            Pill(relDay(a.when), color: AppColors.accent),
            Pill('${m.name.split(' ').first} · ${m.relation}', color: m.color),
          ]),
          const SizedBox(height: 14),
          PaperCard(
            color: AppColors.primarySoft,
            borderColor: Colors.transparent,
            child: Row(children: [
              const Icon(Icons.flag_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(a.purpose, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
          const SectionTitle('Take with you'),
          PaperCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _check('Health card / ID'),
              for (final r in recent) _check('${r.title} (${fmtShort(r.date)})'),
              if (s.medsFor(m.id).isNotEmpty) _check('Current medicine strips (${s.medsFor(m.id).length})'),
            ]),
          ),
          if (c != null) ...[
            SectionTitle('Questions from “${c.condition}”',
                action: 'Open', onAction: () => push(context, QuestionsScreen(caseId: c.id))),
            for (final q in caseQs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PaperCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => s.markAsked(c.id, q),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                        s.askedQuestions.contains('${c.id}#$q') ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: s.askedQuestions.contains('${c.id}#$q') ? AppColors.good : AppColors.muted,
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(q, style: const TextStyle(height: 1.4))),
                  ]),
                ),
              ),
          ],
          SectionTitle('My saved questions (${notes.length})'),
          if (notes.isEmpty)
            const Text('Tap “Ask doctor” on any report to save a question here.',
                style: TextStyle(color: AppColors.muted))
          else
            for (final q in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PaperCard(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(children: [
                    Expanded(child: Text(q, style: const TextStyle(height: 1.4))),
                    IconButton(
                        onPressed: () => s.removeVisitNote(q),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted)),
                  ]),
                ),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Exporter.shareText(prep(), subject: 'Visit with ${a.doctor}'),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send visit summary to family'),
          ),
        ],
      ),
    );
  }

  static Widget _check(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          const Icon(Icons.check_box_outline_blank_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(t)),
        ]),
      );
}

class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({super.key});
  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _form = GlobalKey<FormState>();
  final _doctor = TextEditingController();
  final _place = TextEditingController();
  final _purpose = TextEditingController();
  String _spec = 'General Physician';
  DateTime _date = DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  String? _caseId;

  @override
  void dispose() {
    for (final c in [_doctor, _place, _purpose]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cases = s.casesFor(s.activeMemberId);
    return Scaffold(
      appBar: AppBar(title: Text('Visit for ${s.activeMember.name.split(' ').first}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              s.addAppointment(Appointment(
                id: 'a${DateTime.now().microsecondsSinceEpoch}',
                memberId: s.activeMemberId,
                doctor: _doctor.text.trim(),
                speciality: _spec,
                place: _place.text.trim(),
                when: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
                purpose: _purpose.text.trim().isEmpty ? 'Consultation' : _purpose.text.trim(),
                caseId: _caseId,
              ));
              toast(context, 'Visit added');
              Navigator.pop(context);
            },
            child: const Text('Save visit'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
          const FieldLabel('Doctor'),
          TextFormField(
            controller: _doctor,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Dr. …'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the doctor\'s name' : null,
          ),
          const FieldLabel('Speciality'),
          ChoiceRow(
            options: const ['General Physician', 'Gynaecologist', 'Orthopaedics', 'Cardiologist', 'Endocrinologist', 'Paediatrician', 'Other'],
            value: _spec,
            onChanged: (v) => setState(() => _spec = v),
          ),
          const FieldLabel('Hospital / clinic'),
          TextFormField(controller: _place, decoration: const InputDecoration(hintText: 'e.g. City Clinic')),
          const FieldLabel('Date & time'),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)));
                  if (d != null) setState(() => _date = d);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(fmtDate(_date)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
                icon: const Icon(Icons.schedule),
                label: Text(_time.format(context)),
              ),
            ),
          ]),
          const FieldLabel('Reason'),
          TextFormField(controller: _purpose, decoration: const InputDecoration(hintText: 'e.g. Follow-up on thyroid')),
          if (cases.isNotEmpty) ...[
            const FieldLabel('Bring questions from a comparison?'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in cases)
                ChoiceChip(
                  label: Text(c.condition),
                  selected: _caseId == c.id,
                  onSelected: (_) => setState(() => _caseId = _caseId == c.id ? null : c.id),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
