import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_detail_screen.dart';

/// Bottom sheet to switch the family member being viewed.
void pickMember(BuildContext context) {
  final s = AppScope.read(context);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          for (final m in s.members)
            ListTile(
              leading: Avatar(m, size: 40, selected: m.id == s.activeMemberId),
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(m.relation),
              trailing: m.id == s.activeMemberId
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                s.setMember(m.id);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    ),
  );
}

class MemberButton extends StatelessWidget {
  const MemberButton({super.key});
  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).activeMember;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => pickMember(context),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            Avatar(me, size: 34),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _filter = 'All';
  String _query = '';
  bool _oldestFirst = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.activeMember;
    final privateMode = _filter == 'Private';
    if (privateMode && !s.vaultUnlocked) _filter = 'All';
    var list = privateMode && s.vaultUnlocked
        ? s.recordsFor(me.id, includePrivate: true).where((r) => r.isPrivate).toList()
        : s.recordsFor(me.id);
    list = list.where((r) {
      final matchFilter = switch (_filter) {
        'Reports' => r.type == RecordType.report,
        'Prescriptions' => r.type == RecordType.prescription,
        'Scans' => r.type == RecordType.scan,
        'Hospital stays' => r.type == RecordType.discharge,
        _ => true,
      };
      final q = _query.toLowerCase();
      final matchQuery = q.isEmpty ||
          r.title.toLowerCase().contains(q) ||
          r.hospital.toLowerCase().contains(q) ||
          r.doctor.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q)) ||
          r.params.any((p) => p.name.toLowerCase().contains(q));
      return matchFilter && matchQuery;
    }).toList();
    if (_oldestFirst) list = list.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${me.name.split(' ').first}\'s records'),
        actions: [
          IconButton(
            tooltip: _oldestFirst ? 'Oldest first' : 'Newest first',
            onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
            icon: Icon(_oldestFirst ? Icons.north_rounded : Icons.south_rounded),
          ),
          const MemberButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search tests, doctors, hospitals…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in ['All', 'Reports', 'Prescriptions', 'Scans', 'Hospital stays', 'Private'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: f == 'Private'
                        ? Icon(s.vaultUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            size: 16)
                        : null,
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) async {
                      if (f == 'Private' && !s.vaultUnlocked) {
                        final ok = await push<bool>(context, const PinScreen());
                        if (ok != true) return;
                      }
                      setState(() => _filter = f);
                    },
                  ),
                ),
            ]),
          ),
          if (privateMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                    child: Text('Private vault — hidden from home, alerts and shared cards.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted))),
                TextButton(
                    onPressed: () {
                      s.lockVault();
                      setState(() => _filter = 'All');
                    },
                    child: const Text('Lock')),
              ]),
            ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            EmptyState(
              icon: Icons.folder_open_rounded,
              anim: _query.isNotEmpty ? Anim.searchBacteria : Anim.medicalReport,
              title: _query.isNotEmpty ? 'No matches' : 'Nothing here yet',
              body: _query.isNotEmpty
                  ? 'Try another word, like a test or doctor name.'
                  : 'Tap “Add a record” to scan a report.',
            ),
          for (final r in list)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: RecordTile(r)),
        ],
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  final MedicalRecord r;
  const RecordTile(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final abnormal = r.params.where((p) => p.status != ParamStatus.normal).length;
    return PaperCard(
      onTap: () => push(context, RecordDetailScreen(recordId: r.id)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4)),
          ),
          child: Icon(r.type.icon, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${r.hospital}\n${r.doctor} · ${fmtDate(r.date)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(r.type.label, color: AppColors.primary),
              if (r.hasCritical)
                const Pill('Urgent',
                    color: AppColors.bad, bg: AppColors.badSoft, icon: Icons.priority_high_rounded)
              else if (abnormal > 0)
                Pill('$abnormal outside range', color: AppColors.warn, bg: AppColors.warnSoft),
              if (r.imagePaths.isNotEmpty)
                Pill('${r.imagePaths.length} photo${r.imagePaths.length > 1 ? 's' : ''}',
                    color: AppColors.muted, icon: Icons.image_outlined),
              if (r.isPrivate)
                const Pill('Private', color: AppColors.muted, icon: Icons.lock_outline_rounded),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }
}

/// PIN pad. In [setMode] the user chooses a new 4-digit PIN (entered twice).
class PinScreen extends StatefulWidget {
  final bool setMode;
  const PinScreen({super.key, this.setMode = false});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String? _first;
  String? _error;

  void _tap(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < 4) return;
    final s = AppScope.read(context);
    if (widget.setMode) {
      if (_first == null) {
        setState(() {
          _first = _pin;
          _pin = '';
        });
      } else if (_first == _pin) {
        s.changePin(_pin);
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'PINs did not match — start again';
          _first = null;
          _pin = '';
        });
      }
      return;
    }
    if (s.unlockVault(_pin)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Wrong PIN, try again';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.setMode ? (_first == null ? 'Choose a new PIN' : 'Enter it again') : 'Private vault';
    final sub = widget.setMode
        ? '4 digits you\'ll remember'
        : 'Enter your 4-digit PIN (default 1234)';
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 20),
          const AnimView(Anim.healthShield, size: 150),
          Text(title, style: serif(26)),
          const SizedBox(height: 6),
          Text(_error ?? sub,
              style: TextStyle(color: _error != null ? AppColors.bad : AppColors.muted)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const Spacer(),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '<']
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 76,
                      height: 64,
                      child: k.isEmpty
                          ? null
                          : TextButton(
                              style: TextButton.styleFrom(
                                  backgroundColor: AppColors.card,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(color: AppColors.border))),
                              onPressed: () => k == '<'
                                  ? setState(() => _pin =
                                      _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1))
                                  : _tap(k),
                              child: k == '<'
                                  ? const Icon(Icons.backspace_outlined)
                                  : Text(k, style: serif(24)),
                            ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
