import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String fmtMonth(DateTime d) => '${_months[d.month - 1]} ${d.year}';
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: serif(18))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const PaperCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.color,
      this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor ?? AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final ParamStatus status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ParamStatus.normal =>
        const Pill('Normal', color: AppColors.good, bg: AppColors.goodSoft),
      ParamStatus.low =>
        const Pill('Low', color: AppColors.warn, bg: AppColors.warnSoft),
      ParamStatus.high =>
        const Pill('High', color: AppColors.warn, bg: AppColors.warnSoft),
      ParamStatus.critical => const Pill('See doctor today',
          color: AppColors.bad,
          bg: AppColors.badSoft,
          icon: Icons.priority_high_rounded),
    };
  }
}

/// Horizontal range bar showing where a value sits against the normal band.
class RangeBar extends StatelessWidget {
  final LabParam p;
  const RangeBar(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final span = (p.high - p.low);
    final min = p.low - span * 0.6;
    final max = p.high + span * 0.6;
    double pos(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0);
    final color = p.status == ParamStatus.normal
        ? AppColors.good
        : p.status == ParamStatus.critical
            ? AppColors.bad
            : AppColors.warn;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 30,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Container(
                height: 6,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3))),
          ),
          Positioned(
            top: 10,
            left: w * pos(p.low),
            width: w * (pos(p.high) - pos(p.low)),
            child: Container(
                height: 6,
                decoration: BoxDecoration(
                    color: AppColors.goodSoft,
                    border: Border.all(color: AppColors.good.withValues(alpha: .4)),
                    borderRadius: BorderRadius.circular(3))),
          ),
          Positioned(
            top: 5,
            left: (w * pos(p.numeric) - 8).clamp(0, w - 16),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: .3), blurRadius: 4)
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: w * pos(p.low) - 10,
            child: Text(_n(p.low),
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
          Positioned(
            top: 20,
            left: w * pos(p.high) - 10,
            child: Text(_n(p.high),
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
        ]),
      );
    });
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class Avatar extends StatelessWidget {
  final FamilyMember m;
  final double size;
  final bool selected;
  const Avatar(this.m, {super.key, this.size = 40, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? m.color : Colors.transparent, width: 2),
      ),
      child: CircleAvatar(
        backgroundColor: m.color.withValues(alpha: .15),
        child: Text(m.initials,
            style: TextStyle(
                color: m.color,
                fontWeight: FontWeight.w700,
                fontSize: size * .32)),
      ),
    );
  }
}

class DisclaimerNote extends StatelessWidget {
  final String text;
  const DisclaimerNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mustardSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.warn),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, color: AppColors.text))),
      ]),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Hand-drawn style underline accent for headings.
class Squiggle extends StatelessWidget {
  final double width;
  final Color color;
  const Squiggle({super.key, this.width = 60, this.color = AppColors.accent});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, 8), painter: _SquigglePainter(color));
}

class _SquigglePainter extends CustomPainter {
  final Color color;
  _SquigglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(0, size.height * .6);
    const seg = 10.0;
    for (double x = 0; x < size.width; x += seg) {
      path.quadraticBezierTo(x + seg / 4, size.height * (x % 20 == 0 ? .1 : .9),
          x + seg / 2, size.height * .5);
      path.quadraticBezierTo(x + seg * .75, size.height * (x % 20 == 0 ? .9 : .1),
          x + seg, size.height * .5);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));

Future<bool> confirm(BuildContext context, String title, String body,
    {String ok = 'Delete', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: serif(20)),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: danger ? AppColors.bad : AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
      );
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final Anim? anim;
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.body, this.action, this.anim});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(children: [
          if (anim != null) AnimView(anim!, size: 170) else Icon(icon, size: 52, color: AppColors.border),
          const SizedBox(height: 12),
          Text(title, style: serif(18), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Simple choice row of chips used in forms.
class ChoiceRow extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const ChoiceRow(
      {super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: value == o,
            onSelected: (_) => onChanged(o),
          ),
      ]);
}

String relDay(DateTime d) {
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = DateUtils.dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return 'In $diff days';
  return fmtDate(d);
}
/// The team's Lottie animations in assets/animations/.
enum Anim { labTechnician, searchBacteria, medicalPill, ambulance, medicalReport, ringingPhone, healthShield }

class AnimView extends StatelessWidget {
  final Anim anim;
  final double size;
  final bool repeat;
  const AnimView(this.anim, {super.key, this.size = 180, this.repeat = true});

  static const _files = {
    Anim.labTechnician: 'assets/animations/lab_technician.json',
    Anim.searchBacteria: 'assets/animations/search_bacteria.json',
    Anim.medicalPill: 'assets/animations/medical_pill.json',
    Anim.ambulance: 'assets/animations/ambulance.json',
    Anim.medicalReport: 'assets/animations/medical_report.json',
    Anim.ringingPhone: 'assets/animations/ringing_phone.json',
    Anim.healthShield: 'assets/animations/health_shield.json',
  };

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(_files[anim]!, repeat: repeat, fit: BoxFit.contain),
      );
}
/// Full-screen loading state: the animation sits directly on the page colour
/// (no card behind it) while [task] runs. Shows for at least [minMs].
Future<T> withLoading<T>(BuildContext context, Anim anim, String message, Future<T> Function() task,
    {int minMs = 900}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.bg.withValues(alpha: .96),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => PopScope(
      canPop: false,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimView(anim, size: 220),
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: Text(message, textAlign: TextAlign.center, style: serif(18)),
          ),
        ]),
      ),
    ),
  );
  final sw = Stopwatch()..start();
  try {
    final r = await task();
    final left = minMs - sw.elapsedMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    return r;
  } finally {
    nav.pop();
  }
}