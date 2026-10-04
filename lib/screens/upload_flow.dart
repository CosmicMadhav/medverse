import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models.dart';
import '../services/ai.dart';
import '../services/doc_parser.dart';
import '../services/engine.dart';
import '../services/ocr.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_detail_screen.dart';

final _picker = ImagePicker();

void showUploadSheet(BuildContext context) {
  final s = AppScope.read(context);
  Future<void> go(Future<List<String>> Function() pick, {RecordType? type}) async {
    Navigator.pop(context);
    final paths = await pick();
    if (!context.mounted) return;
    if (paths.isEmpty && type == null) return; // user cancelled the picker
    push(context, AddRecordScreen(imagePaths: paths, presetType: type));
  }

  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          Text('Add a record', style: serif(22)),
          Text('For ${s.activeMember.name.split(' ').first} (${s.activeMember.relation}) — you can change this next',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          _option(Icons.photo_camera_outlined, 'Take a photo', 'Report, prescription or discharge paper',
              () => go(() async {
                    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2200);
                    return x == null ? <String>[] : [x.path];
                  })),
          _option(Icons.photo_library_outlined, 'Choose from gallery', 'Pick one or several pages',
              () => go(() async {
                    final xs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2200);
                    return xs.map((x) => x.path).toList();
                  })),
          _option(Icons.keyboard_alt_outlined, 'Enter without a photo', 'Type in a doctor visit or result',
              () => go(() async => <String>[], type: RecordType.prescription)),
          _option(Icons.account_balance_outlined, 'Import from ABHA',
              s.abhaLinked ? 'Fetch records from linked hospitals' : 'Link ABHA in Profile first', () {
            if (!s.abhaLinked) {
              Navigator.pop(ctx);
              toast(context, 'Link your ABHA number in Profile first');
              return;
            }
            go(() async => <String>[], type: RecordType.discharge);
          }),
        ]),
      ),
    ),
  );
}

Widget _option(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PaperCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );

/// Three-step flow: choose type/person → processing → review & save.
class AddRecordScreen extends StatefulWidget {
  final List<String> imagePaths;
  final RecordType? presetType;
  const AddRecordScreen({super.key, required this.imagePaths, this.presetType});
  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  int _stage = 0; // 0 setup, 1 processing, 2 review
  late RecordType _type = widget.presetType ?? RecordType.report;
  late String _memberId = AppScope.read(context).activeMemberId;
  late final List<String> _images = List.of(widget.imagePaths);
  int _step = 0;
  ExtractDraft? _draft;
  List<bool> _medPick = [];

  final _title = TextEditingController();
  final _doctor = TextEditingController();
  final _hospital = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _private = false;

  static const _steps = [
    ('Reading the document', 'Scanning text from your photo'),
    ('Finding the details', 'Tests, medicines, doctor and date'),
    ('Writing it simply', 'Plain English and Hindi'),
    ('Checking history', 'Repeat tests and medicine overlaps'),
  ];

  @override
  void dispose() {
    for (final c in [_title, _doctor, _hospital, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _process() async {
    setState(() {
      _stage = 1;
      _step = 0;
    });
    final ExtractDraft draft;
    String? failure;
    if (_images.isNotEmpty) {
      // Real OCR: animate the first steps while Google Vision reads the photos.
      final ocr = Ocr.readImages(_images).then<OcrResult?>((r) => r).catchError((Object e) {
        failure = e.toString();
        return null;
      });
      for (var i = 0; i < 2; i++) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() => _step = i + 1);
      }
      final result = await ocr;
      if (!mounted) return;
      if (result == null || result.isEmpty) {
        setState(() => _stage = 0);
        toast(context,
            failure ?? 'Could not read any text. Retake the photo in good light, flat and fully in frame.');
        return;
      }
      setState(() => _step = 2);
      draft = await Ai.enrich(DocParser.parse(result, chosen: _type), result);
      if (!mounted) return;
      setState(() => _step = 3);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _step = 4);
    } else {
      for (var i = 0; i < _steps.length; i++) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() => _step = i + 1);
      }
      draft = Engine.extract(_type);
    }
    _title.text = draft.title;
    _doctor.text = draft.doctor;
    _hospital.text = draft.hospital;
    if (draft.type != null) _type = draft.type!;
    if (draft.date != null) _date = DateUtils.dateOnly(draft.date!);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _medPick = List.filled(draft.medicines.length, true);
      _stage = 2;
    });
  }

  Future<void> _addPhoto() async {
    final xs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2200);
    if (xs.isNotEmpty) setState(() => _images.addAll(xs.map((x) => x.path)));
  }

  void _save() {
    final s = AppScope.read(context);
    final d = _draft!;
    final r = MedicalRecord(
      id: 'r${DateTime.now().microsecondsSinceEpoch}',
      memberId: _memberId,
      title: _title.text.trim().isEmpty ? d.title : _title.text.trim(),
      type: _type,
      hospital: _hospital.text.trim(),
      doctor: _doctor.text.trim(),
      date: _date,
      summary: d.summary,
      summaryHi: d.summaryHi,
      params: d.params,
      originalLines: d.lines,
      tags: d.tags,
      imagePaths: _images,
      isPrivate: _private,
      note: _note.text.trim(),
      orderedTests: d.orderedTests,
    );
    s.addRecord(r);
    for (var i = 0; i < d.medicines.length; i++) {
      if (!_medPick[i]) continue;
      final m = d.medicines[i];
      s.addMedicine(Medicine(
        id: 'md${DateTime.now().microsecondsSinceEpoch}$i',
        memberId: _memberId,
        name: m.name,
        generic: m.generic.isEmpty ? m.name : m.generic,
        drugClass: m.drugClass,
        dose: m.dose,
        times: m.times,
        prescribedBy: _doctor.text.trim().isEmpty ? 'Self-added' : _doctor.text.trim(),
        purpose: m.purpose.isEmpty ? '—' : m.purpose,
        food: m.food,
        daysLeft: m.days,
      ));
    }
    s.setMember(_memberId);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RecordDetailScreen(recordId: r.id)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != 1,
      child: Scaffold(
        appBar: AppBar(title: Text(['Add record', 'Reading…', 'Check & save'][_stage])),
        body: switch (_stage) {
          0 => _setup(),
          1 => _processing(),
          _ => _review(),
        },
      ),
    );
  }

  Widget _thumbs({bool canAdd = true}) => SizedBox(
        height: 104,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < _images.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(_images[i]), width: 78, height: 104, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(i)),
                    child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          if (canAdd)
            GestureDetector(
              onTap: _addPhoto,
              child: Container(
                width: 78,
                height: 104,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5)),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.muted),
                  SizedBox(height: 4),
                  Text('Add page', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
              ),
            ),
        ]),
      );

  Widget _setup() {
    final s = AppScope.of(context);
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          _thumbs(),
          const FieldLabel('What is this?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in RecordType.values)
              ChoiceChip(
                avatar: Icon(t.icon, size: 18),
                label: Text(t.label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ]),
          const FieldLabel('Whose record?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in s.members)
              ChoiceChip(
                avatar: CircleAvatar(
                    backgroundColor: m.color.withValues(alpha: .15),
                    child: Text(m.initials, style: TextStyle(fontSize: 9, color: m.color))),
                label: Text('${m.name.split(' ').first} · ${m.relation}'),
                selected: _memberId == m.id,
                onSelected: (_) => setState(() => _memberId = m.id),
              ),
          ]),
          const SizedBox(height: 18),
          DisclaimerNote(_images.isEmpty
              ? 'No photo added: sample results are used for this document type. Add a photo to read your real document.'
              : 'MedVerse reads the text with Google Vision (needs internet). Tests and ranges are matched by rules; always check the result against the paper.'),
        ]),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _process,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(_images.isEmpty ? 'Continue' : 'Read ${_images.length} page${_images.length > 1 ? 's' : ''}'),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _processing() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: AnimView(Anim.labTechnician, size: 200)),
        if (_images.isNotEmpty)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              height: 64,
              width: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
              child: Stack(fit: StackFit.expand, children: [
                Image.file(File(_images.first), fit: BoxFit.cover),
                const _ScanLine(),
              ]),
            ),
          ),
        const SizedBox(height: 26),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              SizedBox(
                width: 24,
                height: 24,
                child: i < _step
                    ? const Icon(Icons.check_circle, color: AppColors.good)
                    : i == _step
                        ? const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)
                        : const Icon(Icons.circle_outlined, color: AppColors.border),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_steps[i].$1,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i <= _step ? AppColors.text : AppColors.muted)),
                  Text(_steps[i].$2, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _review() {
    final d = _draft!;
    final flagged = d.params.where((p) => p.status != ParamStatus.normal).length;
    final unclear = d.params.where((p) => p.confidence < .85).length;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          PaperCard(
            color: AppColors.goodSoft,
            borderColor: Colors.transparent,
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.good),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    'Read ${d.lines.length} lines',
                    if (d.params.isNotEmpty) '${d.params.length} test values',
                    if (flagged > 0) '$flagged outside normal range',
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
              'Read with ${Ocr.lastEngine == 'google' ? 'Google Vision' : 'Groq vision'}${d.ai ? ' · explained by AI' : ' · rule-based explanation'}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          if (unclear > 0) ...[
            const SizedBox(height: 8),
            PaperCard(
              color: AppColors.warnSoft,
              borderColor: Colors.transparent,
              child: Text('$unclear value${unclear > 1 ? 's were' : ' was'} hard to read. Please check against the paper after saving.',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 6),
          const Text('Check these details — fix anything that looks wrong.', style: TextStyle(color: AppColors.muted)),
          const FieldLabel('Type'),
          ChoiceRow(
            options: [for (final t in RecordType.values) t.label],
            value: _type.label,
            onChanged: (v) => setState(() => _type = RecordType.values.firstWhere((t) => t.label == v)),
          ),
          const FieldLabel('Title'),
          TextField(controller: _title),
          const FieldLabel('Doctor'),
          TextField(controller: _doctor),
          const FieldLabel('Hospital / lab'),
          TextField(controller: _hospital),
          const FieldLabel('Date on the document'),
          OutlinedButton.icon(
            onPressed: () async {
              final x = await showDatePicker(
                  context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (x != null) setState(() => _date = x);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(fmtDate(_date)),
          ),
          if (d.medicines.isNotEmpty) ...[
            const FieldLabel('Medicines found — add to Medicines?'),
            PaperCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (var i = 0; i < d.medicines.length; i++)
                  CheckboxListTile(
                    dense: true,
                    activeColor: AppColors.primary,
                    value: _medPick.length > i && _medPick[i],
                    onChanged: (v) => setState(() => _medPick[i] = v ?? false),
                    title: Text(d.medicines[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${d.medicines[i].dose} · ${d.medicines[i].times.join(', ')} · ${d.medicines[i].food}'
                        '${d.medicines[i].drugClass.isEmpty ? '' : ' · ${d.medicines[i].drugClass}'}'),
                  ),
              ]),
            ),
          ],
          if (d.orderedTests.isNotEmpty) ...[
            const FieldLabel('Tests the doctor asked for'),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in d.orderedTests) Pill(t, color: AppColors.info)]),
          ],
          const FieldLabel('In simple words (preview)'),
          PaperCard(
            color: AppColors.primarySoft,
            borderColor: Colors.transparent,
            child: Text(d.summary, style: const TextStyle(height: 1.45)),
          ),
          const FieldLabel('My note (optional)'),
          TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(hintText: 'e.g. fasting sample')),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _private,
            onChanged: (v) => setState(() => _private = v),
            title: const Text('Keep in private vault'),
            subtitle: const Text('Hidden from home, alerts and shared cards'),
          ),
          if (_images.isNotEmpty) ...[const FieldLabel('Pages'), _thumbs(canAdd: false)],
        ]),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Save record'))),
        ),
      ),
    ]);
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Align(
          alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
          child: Container(height: 2, color: AppColors.accent),
        ),
      );
}
