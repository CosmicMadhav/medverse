import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'records_screen.dart';

class LabTrendsScreen extends StatefulWidget {
  const LabTrendsScreen({super.key});
  @override
  State<LabTrendsScreen> createState() => _LabTrendsScreenState();
}

class _LabTrendsScreenState extends State<LabTrendsScreen> {
  int _i = 0;
  int? _touched;
  static const _chartLeft = 36.0;

  @override
  void dispose() {
    Voice.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final trends = s.trendsFor(s.activeMemberId);
    if (_i >= trends.length) _i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Lab trends'), actions: const [MemberButton()]),
      body: trends.isEmpty
          ? EmptyState(
              icon: Icons.show_chart_rounded,
              anim: Anim.labTechnician,
              title: 'No trends yet for ${s.activeMember.name.split(' ').first}',
              body: 'Trends appear once the same test has been done at least twice.')
          : _body(trends[_i], trends),
    );
  }

  Widget _body(Trend t, List<Trend> trends) {
    final s = AppScope.of(context);
    final latest = t.points.last;
    final first = t.points.first;
    final labs = t.points.map((p) => p.lab).toSet().toList();
    final status = latest.value < t.low
        ? ('Below normal', AppColors.warn)
        : latest.value > t.high
            ? ('Above normal', AppColors.warn)
            : ('In normal range', AppColors.good);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < trends.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(trends[i].name),
                  selected: _i == i,
                  onSelected: (_) => setState(() {
                    _i = i;
                    _touched = null;
                  }),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(latest.value.toString(), style: serif(40, w: FontWeight.w700)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(t.unit, style: const TextStyle(color: AppColors.muted)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pill(status.$1, color: status.$2),
          ),
        ]),
        Text(
            'Normal ${t.low} – ${t.high} ${t.unit} · ${latest.value >= first.value ? '▲' : '▼'} ${(latest.value - first.value).abs().toStringAsFixed(1)} since ${fmtMonth(first.date)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 14),
        PaperCard(
          padding: const EdgeInsets.fromLTRB(8, 18, 16, 10),
          child: Column(children: [
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth - _chartLeft;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final n = t.points.length;
                  final x = (d.localPosition.dx - _chartLeft).clamp(0, w);
                  setState(() => _touched = n == 1 ? 0 : ((x / w) * (n - 1)).round());
                },
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: CustomPaint(painter: _TrendPainter(t, labs, _touched)),
                ),
              );
            }),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (var i = 0; i < labs.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _labColor(i), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(labs[i], style: const TextStyle(fontSize: 12)),
                ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 10, color: AppColors.goodSoft),
                const SizedBox(width: 5),
                const Text('Normal', style: TextStyle(fontSize: 12)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        if (_touched != null)
          PaperCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.place_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      '${t.points[_touched!].value} ${t.unit} on ${fmtDate(t.points[_touched!].date)}\n${t.points[_touched!].lab}')),
            ]),
          )
        else
          const Text('Tap the chart to see each result.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 14),
        PaperCard(
          color: AppColors.primarySoft,
          borderColor: Colors.transparent,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.insights_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(t.insight, style: const TextStyle(height: 1.45))),
            ValueListenableBuilder<String?>(
              valueListenable: Voice.instance.speaking,
              builder: (_, id, _) => IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Voice.instance.speak('trend-${t.name}', t.insight, hindi: false),
                icon: Icon(id == 'trend-${t.name}' ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    color: AppColors.primary),
              ),
            ),
          ]),
        ),
        const SectionTitle('All results'),
        PaperCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final p in t.points.reversed)
              ListTile(
                dense: true,
                title: Text('${p.value} ${t.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(p.lab),
                trailing: Text(fmtDate(p.date), style: const TextStyle(color: AppColors.muted)),
                leading: Icon(
                    p.value < t.low || p.value > t.high ? Icons.error_outline : Icons.check_circle_outline,
                    color: p.value < t.low || p.value > t.high ? AppColors.warn : AppColors.good),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(
            'Values from different labs are converted to the same unit so ${s.activeMember.name.split(' ').first} can compare them fairly.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

Color _labColor(int i) => [AppColors.primary, AppColors.accent, AppColors.info, AppColors.mustard][i % 4];

class _TrendPainter extends CustomPainter {
  final Trend t;
  final List<String> labs;
  final int? touched;
  _TrendPainter(this.t, this.labs, this.touched);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    final w = size.width - left;
    final h = size.height - 24;
    final vals = [...t.points.map((p) => p.value), t.low, t.high];
    var minV = vals.reduce((a, b) => a < b ? a : b);
    var maxV = vals.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) * .15;
    minV -= pad;
    maxV += pad;
    double y(double v) => h - (v - minV) / (maxV - minV) * h;
    double x(int i) => left + (t.points.length == 1 ? w / 2 : w * i / (t.points.length - 1));

    canvas.drawRect(Rect.fromLTRB(left, y(t.high), size.width, y(t.low)), Paint()..color = AppColors.goodSoft);
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final v = minV + (maxV - minV) * k / 4;
      final yy = y(v);
      canvas.drawLine(Offset(left, yy), Offset(size.width, yy), grid);
      _text(canvas, v.toStringAsFixed(1), Offset(0, yy - 7), 10, AppColors.muted);
    }
    if (touched != null) {
      final tx = x(touched!);
      canvas.drawLine(Offset(tx, 0), Offset(tx, h), Paint()
        ..color = AppColors.muted.withValues(alpha: .4)
        ..strokeWidth = 1);
    }
    final path = Path();
    for (var i = 0; i < t.points.length; i++) {
      final p = Offset(x(i), y(t.points[i].value));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.text
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < t.points.length; i++) {
      final p = Offset(x(i), y(t.points[i].value));
      final c = _labColor(labs.indexOf(t.points[i].lab));
      if (touched == i) canvas.drawCircle(p, 11, Paint()..color = c.withValues(alpha: .2));
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4.5, Paint()..color = c);
      _text(canvas, fmtShort(t.points[i].date), Offset(p.dx - 16, h + 8), 10, AppColors.muted);
    }
  }

  void _text(Canvas c, String s, Offset o, double size, Color color) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.t != t || old.touched != touched;
}
