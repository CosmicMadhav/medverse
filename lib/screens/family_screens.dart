import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Add a new family member, or edit an existing one when [member] is given.
class MemberFormScreen extends StatefulWidget {
  final FamilyMember? member;
  const MemberFormScreen({super.key, this.member});
  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _age = TextEditingController(text: widget.member?.age.toString() ?? '');
  late final _phone = TextEditingController(text: widget.member?.emergencyContact ?? '');
  late final _allergy = TextEditingController();
  late final _condition = TextEditingController();
  late String _relation = widget.member?.relation ?? 'Mother';
  late String _gender = widget.member?.gender ?? 'Female';
  late String _blood = widget.member?.bloodGroup ?? 'B+';
  late final List<String> _allergies = List.of(widget.member?.allergies ?? const []);
  late final List<String> _conditions = List.of(widget.member?.conditions ?? const []);

  bool get _editing => widget.member != null;

  @override
  void dispose() {
    for (final c in [_name, _age, _phone, _allergy, _condition]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    final age = int.parse(_age.text.trim());
    if (_editing) {
      s.updateMember(widget.member!.copyWith(
        name: _name.text.trim(),
        relation: _relation,
        age: age,
        gender: _gender,
        bloodGroup: _blood,
        allergies: _allergies,
        conditions: _conditions,
        emergencyContact: _phone.text.trim(),
      ));
      toast(context, 'Saved');
    } else {
      final m = s.addMember(
        name: _name.text.trim(),
        relation: _relation,
        age: age,
        gender: _gender,
        bloodGroup: _blood,
        allergies: _allergies,
        conditions: _conditions,
        emergencyContact: _phone.text.trim(),
      );
      toast(context, '${m.name.split(' ').first} added — now viewing their records');
    }
    Navigator.pop(context);
  }

  Widget _tagInput(String hint, TextEditingController c, List<String> list, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: c,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) {
          if (v.trim().isEmpty) return;
          setState(() => list.add(v.trim()));
          c.clear();
        },
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
            onPressed: () {
              if (c.text.trim().isEmpty) return;
              setState(() => list.add(c.text.trim()));
              c.clear();
            },
          ),
        ),
      ),
      if (list.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in list)
            InputChip(
              label: Text(a),
              labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
              onDeleted: () => setState(() => list.remove(a)),
            ),
        ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit ${widget.member!.name.split(' ').first}' : 'Add family member'),
        actions: [
          if (_editing && s.members.length > 1 && widget.member!.relation != 'Self')
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await confirm(context, 'Remove ${widget.member!.name}?',
                    'All their records, medicines and visits will be deleted from this phone.');
                if (!ok || !context.mounted) return;
                s.removeMember(widget.member!.id);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: _save, child: Text(_editing ? 'Save changes' : 'Add member')),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          children: [
            const FieldLabel('Full name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Sunita Maheshwari'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a name' : null,
            ),
            const FieldLabel('Relation'),
            ChoiceRow(
              options: const ['Self', 'Mother', 'Father', 'Spouse', 'Child', 'Grandparent', 'Other'],
              value: _relation,
              onChanged: (v) => setState(() => _relation = v),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Age'),
                  TextFormField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Years'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 0 || n > 120 ? 'Enter age' : null;
                    },
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Blood group'),
                  DropdownButtonFormField<String>(
                    initialValue: _blood,
                    items: [
                      for (final b in ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'])
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => _blood = v!),
                  ),
                ]),
              ),
            ]),
            const FieldLabel('Gender'),
            ChoiceRow(
              options: const ['Female', 'Male', 'Other'],
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const FieldLabel('Allergies'),
            _tagInput('e.g. Penicillin — tap +', _allergy, _allergies, AppColors.bad),
            const FieldLabel('Long-term conditions'),
            _tagInput('e.g. Diabetes — tap +', _condition, _conditions, AppColors.primary),
            const FieldLabel('Emergency contact number'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+91 …'),
            ),
            const SizedBox(height: 14),
            const Text(
                'Allergies, conditions and the emergency contact appear on this person\'s QR health card.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
