import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color _levelColor(int l) => [AppColors.good, AppColors.warn, AppColors.bad][l.clamp(0, 2)];
const _levelName = ['Up to date', 'Follow-up', 'Urgent'];

class AshaScreen extends StatefulWidget {
  const AshaScreen({super.key});
  @override
  State<AshaScreen> createState() => _AshaScreenState();
}

class _AshaScreenState extends State<AshaScreen> {
  String _filter = 'All';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = s.ashaPeople;
    final list = all.where((p) {
      final f = switch (_filter) {
        'Urgent' => p.level == 2,
        'Follow-up' => p.level == 1,
        'Pregnant' => p.pregnant,
        _ => true,
      };
      final q = _q.toLowerCase();
      return f && (q.isEmpty || p.name.toLowerCase().contains(q) || p.village.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.level.compareTo(a.level));

    return Scaffold(
      appBar: AppBar(title: const Text('ASHA mode')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addPerson(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Register person'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          const Text(
              'Keep simple health records for people in your area who don\'t have a smartphone.',
              style: TextStyle(color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 14),
          Row(children: [
            _stat('${all.length}', 'people'),
            const SizedBox(width: 10),
            _stat('${all.where((p) => p.level > 0).length}', 'need follow-up', color: AppColors.warn),
            const SizedBox(width: 10),
            _stat('${all.where((p) => p.pregnant).length}', 'pregnant', color: AppColors.accent),
          ]),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Search name or village', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in ['All', 'Urgent', 'Follow-up', 'Pregnant'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const EmptyState(
                icon: Icons.people_outline, anim: Anim.searchBacteria, title: 'No one here', body: 'Try another filter.'),
          for (final p in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaperCard(
                onTap: () => push(context, AshaPersonScreen(personId: p.id)),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: _levelColor(p.level).withValues(alpha: .12),
                    child: Text(p.name[0], style: TextStyle(color: _levelColor(p.level), fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${p.village} · ${p.age} yrs · ${p.gender}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill(p.status, color: _levelColor(p.level)),
                        if (p.pregnant) const Pill('Pregnant', color: AppColors.accent),
                      ]),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String n, String l, {Color color = AppColors.text}) => Expanded(
        child: PaperCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: serif(24, w: FontWeight.w700, c: color)),
            Text(l, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      );

  void _addPerson(BuildContext context) {
    final s = AppScope.read(context);
    final name = TextEditingController();
    final village = TextEditingController();
    final age = TextEditingController();
    final phone = TextEditingController();
    var gender = 'Female';
    var pregnant = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SheetHandle(),
              Text('Register a person', style: serif(22)),
              const FieldLabel('Name'),
              TextField(controller: name, textCapitalization: TextCapitalization.words),
              const FieldLabel('Village'),
              TextField(controller: village, textCapitalization: TextCapitalization.words),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Age'),
                    TextField(controller: age, keyboardType: TextInputType.number),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Phone (optional)'),
                    TextField(controller: phone, keyboardType: TextInputType.phone),
                  ]),
                ),
              ]),
              const FieldLabel('Gender'),
              ChoiceRow(options: const ['Female', 'Male', 'Other'], value: gender, onChanged: (v) => set(() => gender = v)),
              if (gender == 'Female')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Currently pregnant'),
                  value: pregnant,
                  onChanged: (v) => set(() => pregnant = v),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty || village.text.trim().isEmpty) {
                      toast(ctx, 'Name and village are needed');
                      return;
                    }
                    s.addAshaPerson(AshaPerson(
                      id: 'p${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text.trim(),
                      village: village.text.trim(),
                      age: int.tryParse(age.text) ?? 0,
                      gender: gender,
                      phone: phone.text.trim(),
                      status: pregnant ? 'Register for ANC' : 'New — first visit pending',
                      level: 1,
                      pregnant: pregnant,
                    ));
                    Navigator.pop(ctx);
                    toast(context, '${name.text.trim()} registered');
                  },
                  child: const Text('Register'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class AshaPersonScreen extends StatelessWidget {
  final String personId;
  const AshaPersonScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.ashaPeople.firstWhere((x) => x.id == personId);
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => _addNote(context, p),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Add visit note'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          PaperCard(
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _levelColor(p.level).withValues(alpha: .12),
                child: Text(p.name[0], style: serif(22, c: _levelColor(p.level))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: serif(20)),
                  Text('${p.village} · ${p.age} yrs · ${p.gender}', style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    Pill(_levelName[p.level], color: _levelColor(p.level)),
                    if (p.pregnant) const Pill('Pregnant', color: AppColors.accent),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          PaperCard(
            color: _levelColor(p.level).withValues(alpha: .08),
            borderColor: Colors.transparent,
            child: Row(children: [
              Icon(Icons.flag_outlined, color: _levelColor(p.level)),
              const SizedBox(width: 10),
              Expanded(child: Text(p.status, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            if (p.phone.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Exporter.call(p.phone),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
            if (p.phone.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Exporter.call('108'),
                icon: const Icon(Icons.local_hospital_outlined),
                label: const Text('108'),
              ),
            ),
          ]),
          const SectionTitle('Visit notes'),
          if (p.notes.isEmpty) const Text('No notes yet.', style: TextStyle(color: AppColors.muted)),
          for (final n in p.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PaperCard(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes_rounded, size: 18, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(n, style: const TextStyle(height: 1.4))),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _addNote(BuildContext context, AshaPerson p) {
    final s = AppScope.read(context);
    final note = TextEditingController();
    final status = TextEditingController(text: p.status);
    var level = p.level;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            Text('Visit note', style: serif(22)),
            const FieldLabel('What did you find?'),
            TextField(
                controller: note,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g. BP 140/90, gave iron tablets')),
            const FieldLabel('Status'),
            TextField(controller: status),
            const FieldLabel('Priority'),
            ChoiceRow(
                options: _levelName,
                value: _levelName[level],
                onChanged: (v) => set(() => level = _levelName.indexOf(v))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (note.text.trim().isEmpty) return;
                  final d = DateTime.now();
                  s.updateAshaPerson(p.withNote('${fmtShort(d)}: ${note.text.trim()}',
                      status: status.text.trim().isEmpty ? p.status : status.text.trim(), level: level));
                  Navigator.pop(ctx);
                },
                child: const Text('Save note'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
