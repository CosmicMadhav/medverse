import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _left = false;

  void _next() {
    if (_left || !mounted) return;
    _left = true;
    final done = AppScope.read(context).onboarded;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, a, _) => FadeTransition(
          opacity: a,
          child: done ? const MainShell() : const OnboardingScreen()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // The logo animation carries its own deep-teal background; the scaffold
    // uses the same colour so it fills the whole screen edge to edge.
    return Scaffold(
      backgroundColor: const Color(0xFF043B42),
      body: SizedBox.expand(
        child: Center(
          child: Lottie.asset(
            'assets/animations/medverse_logo.json',
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.fitWidth,
            repeat: false,
            onLoaded: (comp) => Future.delayed(
                comp.duration + const Duration(milliseconds: 300), _next),
          ),
        ),
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.description_outlined,
            color: Colors.white, size: size * .5),
        Positioned(
          right: size * .14,
          bottom: size * .14,
          child: Container(
            width: size * .26,
            height: size * .26,
            decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2)),
            child: Icon(Icons.favorite, color: Colors.white, size: size * .13),
          ),
        ),
      ]),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.folder_copy_outlined,
      'All your reports,\nfinally in one place',
      'Prescriptions from one hospital, tests from another, old files in a drawer — keep them together for your whole family.',
      AppColors.primarySoft,
      AppColors.primary,
    ),
    (
      Icons.translate_rounded,
      'Medical words,\nmade simple',
      'Understand every report in plain English or Hindi — read it or listen to it. Every line links back to the original.',
      AppColors.mustardSoft,
      AppColors.warn,
    ),
    (
      Icons.compare_arrows_rounded,
      'Two doctors,\ntwo opinions?',
      'See exactly where they agree and differ, and walk into your next visit with the right questions.',
      AppColors.accentSoft,
      AppColors.accent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(children: [
              const LogoMark(size: 32),
              const SizedBox(width: 10),
              Text('MedVerse', style: serif(18)),
              const Spacer(),
              if (!last)
                TextButton(
                    onPressed: () => _pc.animateToPage(_pages.length,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut),
                    child: const Text('Skip')),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final p in _pages)
                  _IntroPage(
                      icon: p.$1,
                      title: p.$2,
                      body: p.$3,
                      soft: p.$4,
                      strong: p.$5,
                      anim: const [Anim.medicalReport, Anim.labTechnician, Anim.searchBacteria][_pages.indexOf(p)]),
                const _LanguagePage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(children: [
              Row(
                children: List.generate(
                  _pages.length + 1,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (last) {
                    AppScope.read(context).finishOnboarding();
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => const MainShell()));
                  } else {
                    _pc.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut);
                  }
                },
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color soft;
  final Color strong;
  final Anim? anim;
  const _IntroPage(
      {required this.icon,
      required this.title,
      required this.body,
      required this.soft,
      required this.strong,
      this.anim});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: anim != null
                ? AnimView(anim!, size: 260)
                : Icon(icon, size: 84, color: strong),
          ),
          const SizedBox(height: 20),
          Text(title, style: serif(30, w: FontWeight.w700)),
          const SizedBox(height: 10),
          const Squiggle(width: 54),
          const SizedBox(height: 16),
          Text(body,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.muted, height: 1.5)),
        ],
      ),
    );
  }
}

class _LanguagePage extends StatelessWidget {
  const _LanguagePage();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget tile(String code, String title, String sub) {
      final sel = s.lang == code;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PaperCard(
          onTap: () => s.setLang(code),
          color: sel ? AppColors.primarySoft : null,
          borderColor: sel ? AppColors.primary : null,
          child: Row(children: [
            Text(title, style: serif(22)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(sub,
                    style: const TextStyle(color: AppColors.muted))),
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel ? AppColors.primary : AppColors.muted),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose your language', style: serif(28, w: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('अपनी भाषा चुनें',
              style: TextStyle(fontSize: 18, color: AppColors.muted)),
          const SizedBox(height: 28),
          tile('en', 'English', 'Explanations in English'),
          tile('hi', 'हिन्दी', 'सरल हिंदी में समझें'),
          const SizedBox(height: 4),
          const Text('You can change this anytime in Profile.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
