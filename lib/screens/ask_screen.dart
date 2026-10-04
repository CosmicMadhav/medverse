import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai.dart';
import 'record_detail_screen.dart';
import '../services/voice.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AskScreen extends StatefulWidget {
  final String? aboutRecordId;
  const AskScreen({super.key, this.aboutRecordId});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _Msg {
  final bool me;
  final String text;
  final List<String> sources;
  final bool urgent;
  _Msg(this.me, this.text, {this.sources = const [], this.urgent = false});
}

class _AskScreenState extends State<AskScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _thinking = false;
  String _partial = '';
  bool _autoSpeak = true;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    final r = widget.aboutRecordId == null ? null : s.record(widget.aboutRecordId!);
    _msgs.add(_Msg(
        false,
        r != null
            ? (s.hi
                ? '“${r.title}” के बारे में कुछ भी पूछें। मैं आसान भाषा में समझाऊँगा।'
                : 'Ask me anything about “${r.title}”. I\'ll explain in simple words.')
            : s.hi
                ? 'नमस्ते! अपनी रिपोर्ट, दवाई या डॉक्टर की सलाह के बारे में पूछें — लिखकर या माइक दबाकर बोलकर।'
                : 'Hi! Ask about your reports, medicines or doctor\'s advice — type, or tap the mic and speak.'));
  }

  @override
  void dispose() {
    Voice.instance.stop();
    Voice.instance.stopListening();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final s = AppScope.read(context);
    setState(() {
      _msgs.add(_Msg(true, text.trim()));
      _thinking = true;
      _partial = '';
    });
    _ctrl.clear();
    _toBottom();
    Ai.answer(s, text).then((a) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _msgs.add(_Msg(false, a.text, sources: a.sources, urgent: a.urgent));
      });
      _toBottom();
      if (_autoSpeak) {
        final hindi = s.hi || RegExp(r'[ऀ-ॿ]').hasMatch(text);
        Voice.instance.speak('ask-${_msgs.length - 1}', a.text, hindi: hindi);
      }
    });
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _mic() async {
    final v = Voice.instance;
    if (v.listening.value) {
      await v.stopListening();
      return;
    }
    final s = AppScope.read(context);
    final ok = await v.listen(
      hindi: s.hi,
      onResult: (text, done) {
        if (!mounted) return;
        setState(() => _partial = text);
        if (done && text.trim().isNotEmpty) _send(text);
      },
    );
    if (!ok && mounted) {
      toast(context, 'Microphone not available. Allow mic permission or type your question.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final suggestions = s.hi
        ? ['मेरी रिपोर्ट में खून कम क्यों है?', 'पापा का पोटैशियम ज़्यादा क्यों है?', 'माँ के घुटने की सर्जरी करानी चाहिए?', 'मेरी दवाइयाँ कौन सी हैं?']
        : ['Why is my haemoglobin low?', 'What does potassium 6.3 mean?', 'Should mother get knee surgery?', 'When is my next visit?'];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('ask')),
        actions: [
          IconButton(
            tooltip: _autoSpeak ? 'Auto-read answers: on' : 'Auto-read answers: off',
            onPressed: () {
              setState(() => _autoSpeak = !_autoSpeak);
              if (!_autoSpeak) Voice.instance.stop();
            },
            icon: Icon(_autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_outlined),
          ),
          TextButton(
            onPressed: () => s.setLang(s.hi ? 'en' : 'hi'),
            child: Text(s.hi ? 'EN' : 'हिं'),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(20),
            children: [
              for (var i = 0; i < _msgs.length; i++) _bubble(i, _msgs[i], s),
              if (_thinking)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimView(Anim.searchBacteria, size: 56),
                    SizedBox(width: 6),
                    Text('Reading your records…',
                        style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic)),
                  ]),
                ),
              if (_msgs.length == 1) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final q in suggestions) ActionChip(label: Text(q), onPressed: () => _send(q)),
                ]),
              ],
              const SizedBox(height: 12),
              const DisclaimerNote('Answers come from your own records. MedVerse does not diagnose or prescribe.'),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: Voice.instance.listening,
          builder: (_, on, _) => !on
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
                  child: Column(children: [
                    const _Pulse(),
                    const SizedBox(height: 6),
                    Text(
                        _partial.isNotEmpty ? _partial : (s.hi ? 'सुन रहे हैं… बोलिए' : 'Listening… speak now'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _partial.isNotEmpty ? AppColors.text : AppColors.muted)),
                  ]),
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)), color: AppColors.card),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: _send,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(hintText: s.hi ? 'लिखें या माइक दबाएँ…' : 'Type or tap the mic…'),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: Voice.instance.listening,
                builder: (_, on, _) => IconButton.filled(
                  style: IconButton.styleFrom(
                      backgroundColor: on ? AppColors.bad : AppColors.accent, minimumSize: const Size(48, 48)),
                  onPressed: _mic,
                  icon: Icon(on ? Icons.stop_rounded : Icons.mic_rounded),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _send(_ctrl.text),
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(int i, _Msg m, AppState s) {
    final id = 'ask-$i';
    return Align(
      alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: m.me ? AppColors.primary : AppColors.card,
          border: m.me ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(m.me ? 14 : 4),
            bottomRight: Radius.circular(m.me ? 4 : 14),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.urgent)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Pill('Please contact a doctor today', color: AppColors.bad, bg: AppColors.badSoft, icon: Icons.priority_high_rounded),
            ),
          Text(m.text, style: TextStyle(color: m.me ? Colors.white : AppColors.text, height: 1.45)),
          if (!m.me && m.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in m.sources)
                if (s.record(id) != null)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.description_outlined, size: 14),
                    label: Text('${s.record(id)!.title.length > 22 ? '${s.record(id)!.title.substring(0, 22)}…' : s.record(id)!.title} · ${fmtShort(s.record(id)!.date)}',
                        style: const TextStyle(fontSize: 11.5)),
                    onPressed: () => push(context, RecordDetailScreen(recordId: id)),
                  ),
            ]),
          ],
          if (!m.me && i > 0) ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: Voice.instance.speaking,
              builder: (_, sp, _) => InkWell(
                onTap: () => Voice.instance
                    .speak(id, m.text, hindi: RegExp(r'[ऀ-ॿ]').hasMatch(m.text)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sp == id ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(sp == id ? context.tr('stop') : context.tr('listen'),
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 5,
                height: 10 + 22 * ((_c.value + i * .2) % 1),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
      );
}
