import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/ai.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'records_screen.dart';

class CompareListScreen extends StatelessWidget {
  const CompareListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.activeMember;
    final mine = s.casesFor(me.id);
    final others = s.cases.where((c) => c.memberId != me.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Compare opinions'), actions: const [MemberButton()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => newComparison(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New comparison'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          const Text(
              'When two doctors say different things, see exactly where they agree and where they differ — side by side.',
              style: TextStyle(color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 16),
          if (mine.isEmpty)
            EmptyState(
              icon: Icons.compare_arrows_rounded,
              anim: Anim.searchBacteria,
              title: 'No comparisons for ${me.name.split(' ').first} yet',
              body: 'Add two prescriptions or reports for the same problem, then compare them.',
            ),
          for (final c in mine) ...[CaseCard(c), const SizedBox(height: 12)],
          if (others.isNotEmpty) ...[
            const SectionTitle('Other family members'),
            for (final c in others) ...[CaseCard(c, showMember: true), const SizedBox(height: 12)],
          ],
        ],
      ),
    );
  }
}

void newComparison(BuildContext context) {
  final s = AppScope.read(context);
  final picks = <String>[];
  final name = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final recs = s.recordsFor(s.activeMemberId, includePrivate: s.vaultUnlocked)
          .where((r) => r.type == RecordType.prescription || r.type == RecordType.discharge || r.type == RecordType.scan)
          .toList();
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (_, sc) => Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            Text('Pick two consultations', style: serif(22)),
            Text('For ${s.activeMember.name.split(' ').first}. Choose the two doctors\' notes about the same problem.',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            Expanded(
              child: recs.length < 2
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Need at least two prescriptions',
                      body: 'Add another doctor\'s prescription first, then come back.')
                  : ListView(controller: sc, children: [
                      for (final r in recs)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: picks.contains(r.id),
                          activeColor: AppColors.primary,
                          onChanged: (v) => set(() {
                            if (v == true) {
                              if (picks.length == 2) picks.removeAt(0);
                              picks.add(r.id);
                            } else {
                              picks.remove(r.id);
                            }
                          }),
                          title: Text(r.doctor, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${r.title}\n${r.hospital} · ${fmtDate(r.date)}'),
                          isThreeLine: true,
                        ),
                    ]),
            ),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What is it about? e.g. Knee pain'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: picks.length == 2
                    ? () async {
                        final a = s.record(picks[0])!, b = s.record(picks[1])!;
                        final title = name.text.trim().isEmpty ? '${a.tags.isNotEmpty ? a.tags.first : 'Treatment'} — ${s.activeMember.name.split(' ').first}' : name.text.trim();
                        Navigator.pop(ctx);
                        final c = await withLoading(context, Anim.searchBacteria, 'Comparing both opinions…', () => Ai.compare(s, a, b, title), minMs: 1500);
                        if (s.caseById(c.id) == null) s.addCase(c);
                        if (context.mounted) push(context, OpinionDiffScreen(caseId: c.id));
                      }
                    : null,
                child: Text(picks.length == 2 ? 'Compare these two' : 'Select ${2 - picks.length} more'),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}

class CaseCard extends StatelessWidget {
  final OpinionCase c;
  final bool showMember;
  const CaseCard(this.c, {super.key, this.showMember = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    int n(DiffTag t) => c.points.where((p) => p.tag == t).length;
    final asked = s.questionsFor(c.id).where((q) => s.askedQuestions.contains('${c.id}#$q')).length;
    return PaperCard(
      onTap: () => push(context, OpinionDiffScreen(caseId: c.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.condition, style: serif(18))),
          if (showMember) Avatar(s.member(c.memberId), size: 30),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _DocChip('A', c.doctorAName, c.doctorASpec, AppColors.onlyA)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('vs', style: TextStyle(color: AppColors.muted)),
          ),
          Expanded(child: _DocChip('B', c.doctorBName, c.doctorBSpec, AppColors.onlyB)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill('${n(DiffTag.agree)} agree', color: AppColors.agree, bg: AppColors.goodSoft),
          Pill('${n(DiffTag.differs)} differ', color: AppColors.differ, bg: AppColors.accentSoft),
          Pill('${n(DiffTag.onlyA) + n(DiffTag.onlyB)} by one doctor', color: AppColors.info, bg: AppColors.infoSoft),
          if (asked > 0) Pill('$asked asked', color: AppColors.good, icon: Icons.check_rounded),
        ]),
      ]),
    );
  }
}

class _DocChip extends StatelessWidget {
  final String letter, name, spec;
  final Color color;
  const _DocChip(this.letter, this.name, this.spec, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: .14),
          child: Text(letter, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(spec,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
        ]),
      ),
    ]);
  }
}

class OpinionDiffScreen extends StatefulWidget {
  final String caseId;
  const OpinionDiffScreen({super.key, required this.caseId});
  @override
  State<OpinionDiffScreen> createState() => _OpinionDiffScreenState();
}

class _OpinionDiffScreenState extends State<OpinionDiffScreen> {
  DiffTag? _filter;

  String _shareText(OpinionCase c) {
    final b = StringBuffer('${c.condition}\nDoctor A: ${c.doctorAName} (${fmtDate(c.doctorADate)})\nDoctor B: ${c.doctorBName} (${fmtDate(c.doctorBDate)})\n\n');
    for (final p in c.points) {
      final tag = switch (p.tag) {
        DiffTag.agree => 'AGREE',
        DiffTag.differs => 'DIFFERENT',
        DiffTag.onlyA => 'ONLY A',
        DiffTag.onlyB => 'ONLY B',
      };
      b.writeln('[$tag] ${p.topic}\n  A: ${p.doctorA}\n  B: ${p.doctorB}\n');
    }
    b.writeln('Shared from MedVerse — this compares advice, it does not say which is right.');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.caseById(widget.caseId);
    if (c == null) return const Scaffold(body: SizedBox());
    final pts = _filter == null ? c.points : c.points.where((p) => p.tag == _filter).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Side by side'),
        actions: [
          IconButton(
              tooltip: 'Share',
              onPressed: () => Exporter.shareText(_shareText(c), subject: c.condition),
              icon: const Icon(Icons.ios_share_rounded)),
          if (c.autoGenerated)
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                final ok = await confirm(context, 'Delete comparison?', 'The two records stay — only this comparison is removed.');
                if (!ok || !context.mounted) return;
                Navigator.pop(context);
                s.deleteCase(c.id);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => push(context, QuestionsScreen(caseId: c.id)),
            icon: const Icon(Icons.help_outline_rounded),
            label: Text('Questions for my doctor (${s.questionsFor(c.id).length})'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Text(c.condition, style: serif(24, w: FontWeight.w700)),
          if (c.autoGenerated) ...[
            const SizedBox(height: 6),
            Pill(c.ai ? 'AI-assisted — check against the documents' : 'Basic comparison (AI unavailable)',
                color: AppColors.warn, bg: AppColors.warnSoft),
          ],
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _DocHeader('A', c.doctorAName, c.doctorASpec, c.doctorAHospital, c.doctorADate, AppColors.onlyA)),
            const SizedBox(width: 10),
            Expanded(child: _DocHeader('B', c.doctorBName, c.doctorBSpec, c.doctorBHospital, c.doctorBDate, AppColors.onlyB)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chip('All (${c.points.length})', null),
              _chip('Agree', DiffTag.agree),
              _chip('Differ', DiffTag.differs),
              _chip('Only A', DiffTag.onlyA),
              _chip('Only B', DiffTag.onlyB),
            ]),
          ),
          const SizedBox(height: 12),
          if (pts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nothing in this group.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final p in pts) ...[_DiffCard(p), const SizedBox(height: 10)],
          const SizedBox(height: 6),
          _WhyDiffer(c.whyDiffer),
          const SizedBox(height: 14),
          const DisclaimerNote(
              'MedVerse does not say which doctor is right. It helps you see the differences clearly so you can discuss them.'),
        ],
      ),
    );
  }

  Widget _chip(String label, DiffTag? t) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: _filter == t, onSelected: (_) => setState(() => _filter = t)),
      );
}

class _DocHeader extends StatelessWidget {
  final String letter, name, spec, hospital;
  final DateTime date;
  final Color color;
  const _DocHeader(this.letter, this.name, this.spec, this.hospital, this.date, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DOCTOR $letter',
            style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('$spec\n$hospital\n${fmtDate(date)}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      ]),
    );
  }
}

class _DiffCard extends StatefulWidget {
  final DiffPoint p;
  const _DiffCard(this.p);
  @override
  State<_DiffCard> createState() => _DiffCardState();
}

class _DiffCardState extends State<_DiffCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final (label, color, soft) = switch (p.tag) {
      DiffTag.agree => ('Both agree', AppColors.agree, AppColors.goodSoft),
      DiffTag.differs => ('Different advice', AppColors.differ, AppColors.accentSoft),
      DiffTag.onlyA => ('Only Doctor A', AppColors.onlyA, AppColors.infoSoft),
      DiffTag.onlyB => ('Only Doctor B', AppColors.onlyB, const Color(0xFFEDE6F3)),
    };
    return PaperCard(
      onTap: () => setState(() => _open = !_open),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Expanded(child: Text(p.topic, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            Pill(label, color: color, bg: soft),
          ]),
        ),
        const Divider(),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _side('A', p.doctorA, AppColors.onlyA, p.tag == DiffTag.onlyB)),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: _side('B', p.doctorB, AppColors.onlyB, p.tag == DiffTag.onlyA)),
          ]),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text('Tap to see in simple words', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)),
            child: Text(p.plain, style: const TextStyle(height: 1.45)),
          ),
        ),
      ]),
    );
  }

  Widget _side(String l, String text, Color c, bool dim) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: dim ? AppColors.muted : AppColors.text,
                  fontStyle: dim ? FontStyle.italic : null)),
        ]),
      );
}

class _WhyDiffer extends StatelessWidget {
  final List<String> reasons;
  const _WhyDiffer(this.reasons);
  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.mustardSoft,
      borderColor: AppColors.mustardSoft,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.psychology_alt_outlined, color: AppColors.warn),
          title: Text('Why might doctors differ?', style: serif(16)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w900)),
                  Expanded(child: Text(r, style: const TextStyle(height: 1.45))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class QuestionsScreen extends StatefulWidget {
  final String caseId;
  const QuestionsScreen({super.key, required this.caseId});
  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final _ctrl = TextEditingController();
  bool _visitMode = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<String> _selected(AppState s) {
    final all = s.questionsFor(widget.caseId);
    return [for (var i = 0; i < all.length; i++) if (s.isQuestionSelected(widget.caseId, i)) all[i]];
  }

  String _compose(AppState s, OpinionCase c) {
    final b = StringBuffer('Questions for doctor — ${c.condition}\n\n');
    final sel = _selected(s);
    for (var i = 0; i < sel.length; i++) {
      b.writeln('${i + 1}. ${sel[i]}');
    }
    b.writeln('\n— Prepared with MedVerse');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.caseById(widget.caseId)!;
    final all = s.questionsFor(c.id);
    final selCount = _selected(s).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_visitMode ? 'At the visit' : 'Questions for your visit'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _visitMode = !_visitMode),
            icon: Icon(_visitMode ? Icons.edit_outlined : Icons.local_hospital_outlined, size: 18),
            label: Text(_visitMode ? 'Edit' : 'At visit'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selCount == 0 ? null : () => Exporter.shareText(_compose(s, c), subject: c.condition),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Send'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: selCount == 0
                    ? null
                    : () async {
                        final bytes = await withLoading(context, Anim.medicalReport, 'Preparing your question sheet…',
                            () => Exporter.questionsPdf(c.condition, s.member(c.memberId).name, _selected(s)));
                        await Exporter.sharePdf(bytes, 'MedVerse_questions.pdf');
                      },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ),
          ]),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Text(_visitMode ? 'Tick each one once the doctor answers' : 'Take these to your next appointment',
              style: serif(22, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              _visitMode
                  ? 'Your progress is saved, so you can pick up where you left off.'
                  : 'Made from the differences between both opinions. Untick any you don\'t need — $selCount of ${all.length} selected.',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          for (var i = 0; i < all.length; i++)
            if (!_visitMode || s.isQuestionSelected(c.id, i))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _visitMode ? _visitTile(s, c, all[i]) : _editTile(s, c, i, all[i]),
              ),
          if (!_visitMode) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add your own question…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: () {
                    if (_ctrl.text.trim().isEmpty) return;
                    s.addQuestion(c.id, _ctrl.text.trim());
                    _ctrl.clear();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editTile(AppState s, OpinionCase c, int i, String q) => PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onTap: () => s.toggleQuestion(c.id, i),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: s.isQuestionSelected(c.id, i),
            activeColor: AppColors.primary,
            onChanged: (_) => s.toggleQuestion(c.id, i),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(q, style: const TextStyle(height: 1.4)),
            ),
          ),
          const SizedBox(width: 10),
        ]),
      );

  Widget _visitTile(AppState s, OpinionCase c, String q) {
    final done = s.askedQuestions.contains('${c.id}#$q');
    return PaperCard(
      color: done ? AppColors.goodSoft : null,
      borderColor: done ? Colors.transparent : null,
      onTap: () => s.markAsked(c.id, q),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.good : AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(q,
              style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: done ? AppColors.muted : AppColors.text,
                  decoration: done ? TextDecoration.lineThrough : null)),
        ),
      ]),
    );
  }
}
