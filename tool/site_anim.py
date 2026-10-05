"""Adds Lottie animations + an Emergency (SOS) section to site/. Idempotent."""
import json, re

SITE = 'site'


def rd(p): return open(p, encoding='utf-8').read()
def wr(p, c): open(p, 'w', encoding='utf-8', newline='\n').write(c)


# ───────── strings ─────────
sp = f'{SITE}/assets/js/strings.js'
s = rd(sp)
i = s.index('var data = ') + len('var data = ')
d = 0
for k, ch in enumerate(s[i:], i):
    d += (ch == '{') - (ch == '}')
    if d == 0:
        j = k + 1
        break
data = json.loads(s[i:j])
new = {
    'navSos': ('Emergency', 'आपातकाल'),
    'sosEyebrow': ('IN AN EMERGENCY', 'आपातकाल में'),
    'sosH': ('One hold. Help is on the way.', 'एक बार दबाकर रखें। मदद चल पड़ती है।'),
    'sosP': ('SOS is built so it can’t be pressed by accident, and can’t be missed when it matters.',
             'SOS ऐसा बना है कि गलती से दब न जाए, और ज़रूरत पर चूके नहीं।'),
    'sos1': ('Press and hold SOS for 1.5 seconds. A quick tap only shows a hint.',
             'SOS को 1.5 सेकंड दबाकर रखें। हल्का टैप करने पर सिर्फ़ संकेत दिखता है।'),
    'sos2': ('A 5-second countdown starts with a loud siren and a big Cancel button, so a slip of the thumb never calls anyone.',
             'तेज़ सायरन के साथ 5 सेकंड की उलटी गिनती शुरू होती है और एक बड़ा रद्द करें बटन दिखता है, ताकि अँगूठा फिसलने से कोई कॉल न जाए।'),
    'sos3': ('If you don’t cancel, your phone’s dialer opens with 108 ready, and MedVerse shows blood group, allergies, conditions and medicines to read out.',
             'रद्द न करें तो फ़ोन के डायलर में 108 तैयार खुल जाता है, और MedVerse ब्लड ग्रुप, एलर्जी, बीमारियाँ और दवाइयाँ पढ़कर बताने के लिए दिखाता है।'),
    'sosTry': ('Try it on the phone above: hold SOS.', 'ऊपर वाले फ़ोन पर आज़माएँ: SOS को दबाकर रखें।'),
    'logoAria': ('MedVerse — Understand, Organise, Compare', 'MedVerse — समझें, संभालें, तुलना करें'),
}
for k, (en, hi) in new.items():
    data['en'][k], data['hi'][k] = en, hi
wr(sp, s[:i] + json.dumps(data, ensure_ascii=False, indent=2) + s[j:])

# ───────── HTML ─────────
h = rd(f'{SITE}/index.html')


def lottie(name, cls, loop='true', label=None):
    aria = f' role="img" aria-label="{label}"' if label else ' aria-hidden="true"'
    return f'<div class="lottie {cls}" data-anim="{name}" data-loop="{loop}"{aria}></div>'


# steps
for key, anim, nxt in (('s1Title', 'lab_technician', 'demo'), ('s2Title', 'medical_report', 'card'), ('s3Title', 'search_bacteria', 'demo')):
    if f'data-anim="{anim}"' in h:
        continue
    pat = re.compile(r'(<h3 data-i18n="%s">.*?)(\n\s*</div>\n\s*<div class="%s")' % (key, nxt), re.S)
    h, n = pat.subn(lambda m: m.group(1) + '\n            ' + lottie(anim, 'lottie-step') + m.group(2), h, count=1)
    assert n == 1, key

# safety header
if 'data-anim="health_shield"' not in h:
    pat = re.compile(r'(<p class="eyebrow" data-i18n="safeEyebrow">[^<]*</p>\s*<h2 class="h2" id="safety-h"[^>]*>[^<]*</h2>)')
    h, n = pat.subn(lambda m: '<div class="safety-head"><div class="stack" style="gap:.75rem">' + m.group(1) + '</div>' + lottie('health_shield', 'lottie-shield') + '</div>', h, count=1)
    assert n == 1, 'safety'

# nav link
if 'href="#sos"' not in h:
    h = h.replace('<a href="#safety" data-i18n="navSafety">', '<a href="#sos" data-i18n="navSos">Emergency</a>\n      <a href="#safety" data-i18n="navSafety">', 1)

# SOS section (before the line that precedes Safety)
if 'id="sos"' not in h:
    sos = f"""  <!-- ============ EMERGENCY ============ -->
  <section id="sos" class="wrap section" aria-labelledby="sos-h">
    <div class="sos-grid">
      {lottie('ambulance', 'lottie-sos')}
      <div class="stack" style="gap:1.125rem">
        <p class="eyebrow" data-i18n="sosEyebrow">IN AN EMERGENCY</p>
        <h2 class="h2" id="sos-h" data-i18n="sosH">One hold. Help is on the way.</h2>
        <p class="body-lg" data-i18n="sosP">SOS is built so it can’t be pressed by accident, and can’t be missed when it matters.</p>
        <ol class="install">
          <li data-i18n="sos1">Press and hold SOS for 1.5 seconds. A quick tap only shows a hint.</li>
          <li data-i18n="sos2">A 5-second countdown starts with a loud siren and a big Cancel button, so a slip of the thumb never calls anyone.</li>
          <li data-i18n="sos3">If you don’t cancel, your phone’s dialer opens with 108 ready, and MedVerse shows blood group, allergies, conditions and medicines to read out.</li>
        </ol>
        <p class="note" data-i18n="sosTry">Try it on the phone above: hold SOS.</p>
      </div>
    </div>
  </section>

"""
    marker = '  <div class="link" aria-hidden="true" style="padding-bottom:0">'
    assert marker in h
    h = h.replace(marker, sos + marker, 1)

# closing brand band
if 'lottie-logo' not in h:
    band = f"""
  <!-- ============ BRAND BAND ============ -->
  <section class="brand-band" aria-hidden="false">
    {lottie('medverse_logo', 'lottie-logo', loop='false', label='MedVerse — Understand, Organise, Compare')}
  </section>
"""
    h = h.replace('</main>', band + '</main>', 1)

# scripts
if 'lottie.min.js' not in h:
    h = h.replace('<script src="assets/js/site.js"></script>',
                  '<script src="assets/js/site.js"></script>\n<script src="assets/js/lottie.min.js" defer></script>\n<script src="assets/js/anim.js" defer></script>', 1)
wr(f'{SITE}/index.html', h)

# ───────── anim.js ─────────
wr(f'{SITE}/assets/js/anim.js', """/* MedVerse: plays the Lottie animations only while they are on screen.
   - Honors prefers-reduced-motion (shows the final frame, no movement).
   - Decorative animations are aria-hidden; the logo band has a text label. */
(function () {
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function init() {
    if (!window.lottie) return;
    [].slice.call(document.querySelectorAll('[data-anim]')).forEach(function (el) {
      var loop = el.getAttribute('data-loop') === 'true';
      var a = window.lottie.loadAnimation({
        container: el,
        renderer: 'svg',
        loop: loop,
        autoplay: false,
        path: 'assets/anim/' + el.getAttribute('data-anim') + '.json',
        rendererSettings: { preserveAspectRatio: 'xMidYMid meet', progressiveLoad: true }
      });
      if (reduce) {
        a.addEventListener('DOMLoaded', function () { a.goToAndStop(Math.max(0, a.totalFrames - 1), true); });
        return;
      }
      if (!('IntersectionObserver' in window)) { a.play(); return; }
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) {
            if (!loop && a.isPaused && a.currentFrame >= a.totalFrames - 1) a.goToAndPlay(0, true);
            else a.play();
          } else {
            a.pause();
          }
        });
      }, { threshold: 0.35 });
      io.observe(el);
    });
  }

  if (document.readyState === 'complete') init();
  else window.addEventListener('load', init);
})();
""")

# ───────── CSS ─────────
c = rd(f'{SITE}/assets/css/site.css')
if '.lottie' not in c:
    c += """
/* Lottie animations */
.lottie { width: 100%; aspect-ratio: 1; }
.lottie svg { display: block; }
.lottie-step { max-width: 11rem; margin-top: .5rem; }
.safety-head { display: flex; align-items: center; justify-content: space-between; gap: 2rem; flex-wrap: wrap; }
.lottie-shield { width: clamp(7rem, 16vw, 10.5rem); flex: 0 0 auto; }
.sos-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(22rem, 100%), 1fr)); gap: 3rem; align-items: center; }
.lottie-sos { max-width: 26rem; margin: 0 auto; aspect-ratio: 4 / 3; }
.brand-band { background: #043B42; display: flex; justify-content: center; }
.lottie-logo { max-width: 34rem; aspect-ratio: 1; }
@media (max-width: 40rem) { .lottie-logo { max-width: 22rem; } }
@media (prefers-reduced-motion: reduce) { .lottie { }
}
"""
wr(f'{SITE}/assets/css/site.css', c)
print('ok')
