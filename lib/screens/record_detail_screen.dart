import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/exporter.dart';
import '../services/voice.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ask_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  final String recordId;
  const RecordDetailScreen({super.key, required this.recordId});
  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String? _highlight;

  @override
  void dispose() {
    Voice.instance.stop();
    _tabs.dispose();
    super.dispose();
  }

  void _showSource(String line) {
    setState(() => _highlight = line);
    _tabs.animateTo(1);
  }

  String _speechText(MedicalRecord r, bool hi) {
    final b = StringBuffer(hi && r.summaryHi.isNotEmpty ? r.summaryHi : r.summary);
    for (final p in r.params.where((p) => p.status != ParamStatus.normal)) {
      b.write(' ${p.name}: ${p.value} ${p.unit}. ${hi ? p.simpleHi : p.simple}');
    }
    return b.toString();
  }

  String _shareText(MedicalRecord r, FamilyMember m, bool hi) {
    final b = StringBuffer('${r.title} — ${m.name}\n${r.hospital} · ${r.doctor} · ${fmtDate(r.date)}\n\n');
    b.writeln(hi && r.summaryHi.isNotEmpty ? r.summaryHi : r.summary);
    if (r.params.isNotEmpty) {
      b.writeln();
      for (final p in r.params) {
        b.writeln('• ${p.name}: ${p.value} ${p.unit} (normal ${p.low}–${p.high}) — ${p.status.name}');
      }
    }
    b.writeln('\nShared from MedVerse. Not a diagnosis — please confirm with a doctor.');
    return b.toString();
  }

  void _menu(MedicalRecord r) {
    final s = AppScope.read(context);
    final m = s.member(r.memberId);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Share as message'),
              subtitle: const Text('WhatsApp, SMS, email…'),
              onTap: () {
                Navigator.pop(ctx);
                Exporter.shareText(_shareText(r, m, s.hi), subject: r.title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Share as PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await withLoading(context, Anim.medicalReport, 'Preparing your PDF…', () => Exporter.recordPdf(r, m, hindi: s.hi));
                await Exporter.sharePdf(bytes, '${r.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await withLoading(context, Anim.medicalReport, 'Preparing to print…', () => Exporter.recordPdf(r, m, hindi: s.hi));
                await Exporter.printPdf(bytes, r.title);
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit details'),
              onTap: () {
                Navigator.pop(ctx);
                _edit(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Move to another family member'),
              onTap: () {
                Navigator.pop(ctx);
                _move(r);
              },
            ),
            ListTile(
              leading: Icon(r.isPrivate ? Icons.lock_open_rounded : Icons.lock_outline_rounded),
              title: Text(r.isPrivate ? 'Remove from private vault' : 'Move to private vault'),
              onTap: () {
                Navigator.pop(ctx);
                s.updateRecord(r.copyWith(isPrivate: !r.isPrivate));
                toast(context, r.isPrivate ? 'Now visible in records' : 'Moved to private vault');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.bad),
              title: const Text('Delete record', style: TextStyle(color: AppColors.bad)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirm(context, 'Delete this record?',
                    '“${r.title}” and its explanation will be removed.');
                if (!ok || !mounted) return;
                Navigator.pop(context);
                s.deleteRecord(r.id);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _edit(MedicalRecord r) {
    final s = AppScope.read(context);
    final title = TextEditingController(text: r.title);
    final doctor = TextEditingController(text: r.doctor);
    final hospital = TextEditingController(text: r.hospital);
    final note = TextEditingController(text: r.note);
    var date = r.date;
    var type = r.type;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const SheetHandle(),
              Text('Edit details', style: serif(22)),
              const FieldLabel('Title'),
              TextField(controller: title),
              const FieldLabel('Type'),
              ChoiceRow(
                options: [for (final t in RecordType.values) t.label],
                value: type.label,
                onChanged: (v) => set(() => type = RecordType.values.firstWhere((t) => t.label == v)),
              ),
              const FieldLabel('Doctor'),
              TextField(controller: doctor),
              const FieldLabel('Hospital / lab'),
              TextField(controller: hospital),
              const FieldLabel('Date'),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (d != null) set(() => date = d);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(fmtDate(date)),
              ),
              const FieldLabel('My note'),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(hintText: 'Anything you want to remember')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    s.updateRecord(r.copyWith(
                      title: title.text.trim().isEmpty ? r.title : title.text.trim(),
                      doctor: doctor.text.trim(),
                      hospital: hospital.text.trim(),
                      date: date,
                      type: type,
                      note: note.text.trim(),
                    ));
                    Navigator.pop(ctx);
                    toast(context, 'Saved');
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _move(MedicalRecord r) {
    final s = AppScope.read(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            Text('Whose record is this?', style: serif(20)),
            const SizedBox(height: 8),
            for (final m in s.members)
              ListTile(
                leading: Avatar(m, size: 40),
                title: Text(m.name),
                trailing: m.id == r.memberId ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () {
                  s.updateRecord(r.copyWith(memberId: m.id));
                  Navigator.pop(ctx);
                  toast(context, 'Moved to ${m.name.split(' ').first}');
                },
              ),
          ]),
        ),
      ),
    );
  }

  void _askDoctor(MedicalRecord r) {
    final s = AppScope.read(context);
    final c = TextEditingController(
        text: r.params.where((p) => p.status != ParamStatus.normal).isNotEmpty
            ? 'My ${r.params.firstWhere((p) => p.status != ParamStatus.normal).name} is ${r.params.firstWhere((p) => p.status != ParamStatus.normal).value} — what does this mean for me and what should I do?'
            : 'About my ${r.title} (${fmtDate(r.date)}): ');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          Text('Question for the doctor', style: serif(22)),
          const SizedBox(height: 4),
          const Text('Saved to your next visit\'s question list.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          TextField(controller: c, maxLines: 3, autofocus: true),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (c.text.trim().isEmpty) return;
                s.addVisitNote(c.text.trim());
                Navigator.pop(ctx);
                toast(context, 'Added to questions for your next visit');
              },
              child: const Text('Save question'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.record(widget.recordId);
    if (r == null) return const Scaffold(body: SizedBox());
    final m = s.member(r.memberId);
    final critical = r.params.where((p) => p.status == ParamStatus.critical);
    final speechId = 'rec-${r.id}-${s.lang}';

    return Scaffold(
      appBar: AppBar(
        title: Text(r.type.label),
        actions: [
          IconButton(
              tooltip: 'Share',
              onPressed: () => Exporter.shareText(_shareText(r, m, s.hi), subject: r.title),
              icon: const Icon(Icons.ios_share_rounded)),
          IconButton(onPressed: () => _menu(r), icon: const Icon(Icons.more_vert_rounded)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          tabs: [Tab(text: context.tr('simplified')), Tab(text: context.tr('original'))],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(r.title, style: serif(24, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${m.name.split(' ').first} · ${r.hospital}\n${r.doctor} · ${fmtDate(r.date)}',
                style: const TextStyle(color: AppColors.muted)),
            if (r.isPrivate) ...[
              const SizedBox(height: 8),
              const Pill('Private vault', color: AppColors.muted, icon: Icons.lock_outline_rounded),
            ],
            const SizedBox(height: 16),
            if (critical.isNotEmpty) ...[
              _CriticalBanner(params: critical.toList(), member: m),
              const SizedBox(height: 14),
            ],
            PaperCard(
              color: AppColors.primarySoft,
              borderColor: AppColors.primarySoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(context.tr('what_means'), style: serif(16, c: AppColors.primary)),
                ]),
                const SizedBox(height: 8),
                Text(s.hi && r.summaryHi.isNotEmpty ? r.summaryHi : r.summary,
                    style: const TextStyle(fontSize: 15, height: 1.5)),
                if (s.hi && r.summaryHi.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Hindi version not available for this record yet.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: Voice.instance.speaking,
                    builder: (_, id, _) {
                      final on = id == speechId;
                      return FilledButton.icon(
                        onPressed: () => Voice.instance.speak(speechId, _speechText(r, s.hi), hindi: s.hi),
                        icon: Icon(on ? Icons.stop_rounded : Icons.volume_up_rounded),
                        label: Text(on
                            ? context.tr('stop')
                            : '${context.tr('listen')} ${s.hi ? '(हिंदी)' : '(EN)'}'),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                      onPressed: () {
                        Voice.instance.stop();
                        s.setLang(s.hi ? 'en' : 'hi');
                      },
                      child: Text(s.hi ? 'English' : 'हिंदी में')),
                ]),
              ]),
            ),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              PaperCard(
                color: AppColors.mustardSoft,
                borderColor: Colors.transparent,
                onTap: () => _edit(r),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.sticky_note_2_outlined, color: AppColors.warn, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.note)),
                ]),
              ),
            ],
            if (r.params.isNotEmpty) ...[
              SectionTitle(context.tr('each_value')),
              for (final p in r.params) ...[
                _ParamCard(
                  p: p,
                  hi: s.hi,
                  speechId: 'p-${r.id}-${p.name}',
                  onSource: () => _showSource(p.sourceLine),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => push(context, AskScreen(aboutRecordId: r.id)),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Ask about this'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _askDoctor(r),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Ask doctor'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            DisclaimerNote(context.tr('disclaimer')),
          ],
        ),
        _OriginalView(record: r, highlight: _highlight),
      ]),
    );
  }
}

class _CriticalBanner extends StatelessWidget {
  final List<LabParam> params;
  final FamilyMember member;
  const _CriticalBanner({required this.params, required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.badSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bad.withValues(alpha: .4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.local_hospital_rounded, color: AppColors.bad),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Contact a doctor today',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.bad)),
            const SizedBox(height: 4),
            Text(
                '${params.map((p) => '${p.name} (${p.value} ${p.unit})').join(', ')} is outside the safe range. MedVerse does not simplify urgent values — please speak to a doctor.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bad,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                onPressed: () => withLoading(context, Anim.ambulance, 'Calling ambulance 108…', () => Exporter.call('108'), minMs: 1200),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call 108'),
              ),
              if (member.emergencyContact.isNotEmpty)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bad,
                      side: const BorderSide(color: AppColors.bad),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  onPressed: () => Exporter.call(member.emergencyContact),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Call family'),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ParamCard extends StatelessWidget {
  final LabParam p;
  final bool hi;
  final String speechId;
  final VoidCallback onSource;
  const _ParamCard({required this.p, required this.hi, required this.speechId, required this.onSource});

  @override
  Widget build(BuildContext context) {
    final critical = p.status == ParamStatus.critical;
    return PaperCard(
      borderColor: critical ? AppColors.bad.withValues(alpha: .5) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          StatusPill(p.status),
        ]),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(p.value, style: serif(26, w: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(p.unit, style: const TextStyle(color: AppColors.muted)),
          const Spacer(),
          if (!critical)
            ValueListenableBuilder<String?>(
              valueListenable: Voice.instance.speaking,
              builder: (_, id, _) => IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Listen',
                onPressed: () => Voice.instance
                    .speak(speechId, '${p.name}, ${p.value} ${p.unit}. ${hi ? p.simpleHi : p.simple}', hindi: hi),
                icon: Icon(id == speechId ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    color: AppColors.primary),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        RangeBar(p),
        const SizedBox(height: 8),
        Text(
            critical
                ? (hi
                    ? 'यह मान सुरक्षित सीमा से बाहर है। कृपया आज ही डॉक्टर से बात करें।'
                    : 'This value is outside the safe range. Please talk to a doctor today.')
                : (hi ? p.simpleHi : p.simple),
            style: const TextStyle(height: 1.45)),
        const SizedBox(height: 10),
        Row(children: [
          InkWell(
            onTap: onSource,
            child: Row(children: [
              const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(context.tr('see_original'),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
          const Spacer(),
          if (p.confidence < 0.85)
            const Flexible(
              child: Pill('Unclear scan — please verify',
                  color: AppColors.warn, bg: AppColors.warnSoft, icon: Icons.visibility_outlined),
            )
          else
            Text('Read clearly · ${(p.confidence * 100).round()}%',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}

class _OriginalView extends StatelessWidget {
  final MedicalRecord record;
  final String? highlight;
  const _OriginalView({required this.record, this.highlight});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (record.imagePaths.isNotEmpty) ...[
          Text('Your photos', style: serif(17)),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: record.imagePaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => push(context, _PhotoView(path: record.imagePaths[i])),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(record.imagePaths[i]),
                      width: 110, height: 150, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                          width: 110, color: AppColors.border, child: const Icon(Icons.broken_image_outlined))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        const Text('Text read from your document. Highlighted lines are linked to the simple explanation.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(2, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final line in record.originalLines)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: line == highlight ? AppColors.mustard.withValues(alpha: .35) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4)),
              ),
          ]),
        ),
      ],
    );
  }
}

class _PhotoView extends StatelessWidget {
  final String path;
  const _PhotoView({required this.path});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: InteractiveViewer(child: Center(child: Image.file(File(path)))),
      );
}
