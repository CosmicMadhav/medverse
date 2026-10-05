"""Corrects and polishes the MedVerse website in site/. Run from the project root.
Idempotent: safe to run more than once."""
import hashlib, html, json, os, re, shutil, filecmp

SITE = 'site'
EMAIL = 'madhavmaheshwari314@gmail.com'   # as listed in the team's IEEE WIE ILS submission
BASE = 'https://cosmicmadhav.github.io/medverse/'


def rd(p):
    return open(p, encoding='utf-8').read()


def wr(p, c):
    open(p, 'w', encoding='utf-8', newline='\n').write(c)


# ───────────────────────── 0. real APK facts ─────────────────────────
apk_src = 'build/app/outputs/flutter-apk/app-release.apk'
apk = f'{SITE}/medverse.apk'
if os.path.exists(apk_src):
    shutil.copy2(apk_src, apk)
size = os.path.getsize(apk)
SIZE = f'{size / 1048576:.1f} MB'
SHA = hashlib.sha256(open(apk, 'rb').read()).hexdigest()
print('APK', SIZE, SHA[:12])

# ───────────────────────── 1. tidy the folder ─────────────────────────
src_dir = 'docs/site-source'
os.makedirs(src_dir, exist_ok=True)
for f in ['SKILL.md', 'preview.html', 'Medverse — Home Screen Redesign.html']:
    if os.path.exists(f'{SITE}/{f}'):
        shutil.move(f'{SITE}/{f}', f'{src_dir}/{f}')
if os.path.isdir(f'{SITE}/animations') and not os.path.isdir(f'{src_dir}/animations'):
    shutil.move(f'{SITE}/animations', f'{src_dir}/animations')   # not used by the site; one is from another product
for f in ['site.css', 'site.js', 'strings.js']:      # byte-identical copies of assets/*
    p = f'{SITE}/{f}'
    sub = {'site.css': 'css', 'site.js': 'js', 'strings.js': 'js'}[f]
    if os.path.exists(p) and filecmp.cmp(p, f'{SITE}/assets/{sub}/{f}', shallow=False):
        os.remove(p)
if os.path.isdir(f'{SITE}/fonts'):
    shutil.rmtree(f'{SITE}/fonts')                    # duplicates of assets/fonts
css_all = rd(f'{SITE}/assets/css/site.css')
for fn in os.listdir(f'{SITE}/assets/fonts'):
    if fn.startswith('font-') and fn not in css_all:  # unreferenced uuid-named fonts
        os.remove(f'{SITE}/assets/fonts/{fn}')
if os.path.exists(f'{SITE}/_harness.html'):
    os.remove(f'{SITE}/_harness.html')

# ───────────────────────── 2. CSS ─────────────────────────
css = css_all
# missing 500-weight files caused 404s: drop those faces (browser uses 400)
css = re.sub(r'@font-face\s*\{[^}]*-500-normal\.woff2[^}]*\}\s*', '', css)
if '.stat .num' not in css:
    css += """
/* survey stats */
.stat .num { font-family: var(--serif); font-size: clamp(2.5rem, 5vw, 3.25rem); line-height: 1; color: var(--brand); letter-spacing: -.01em; }
.stat .of { font-size: .9375rem; color: var(--ink2, #3D5A5E); margin-top: -.25rem; }
.sha { font-size: .8125rem; color: var(--ink2, #3D5A5E); word-break: break-all; margin-top: .75rem; }
.sha code { font-family: ui-monospace, Consolas, monospace; font-size: .75rem; }
.survey-more { max-width: 40rem; margin: .75rem auto 0; text-align: center; font-size: 1rem; line-height: 1.6; }
"""
wr(f'{SITE}/assets/css/site.css', css)

# ───────────────────────── 3. strings (EN + HI) ─────────────────────────
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
EN, HI = data['en'], data['hi']


def put(key, en, hi):
    EN[key] = en
    HI[key] = hi


put('surveyP', 'We surveyed 31 people about how their families handle medical papers. Reports from one lab, prescriptions from another hospital, two doctors saying different things — and no one explaining any of it.',
    'हमने 31 लोगों से पूछा कि उनके परिवार मेडिकल कागज़ात कैसे संभालते हैं। एक लैब की रिपोर्ट, दूसरे अस्पताल का पर्चा, दो डॉक्टरों की अलग-अलग बातें — और समझाने वाला कोई नहीं।')
put('st1', 'had taken opinions from more than one doctor', 'ने एक से ज़्यादा डॉक्टर की राय ली थी')
put('st2', 'got different treatment suggestions from different doctors', 'को अलग-अलग डॉक्टरों से अलग-अलग इलाज की सलाह मिली')
put('st3', 'had repeated the same medical test at another hospital', 'ने दूसरे अस्पताल में वही जाँच दोबारा करवाई')
put('st4', 'found medical reports hard to understand', 'को मेडिकल रिपोर्ट समझने में दिक्कत हुई')
put('sc1', '30 of 31 people', '31 में से 30 लोग')
put('sc2', '26 of 31 people', '31 में से 26 लोग')
put('sc3', '20 of 31 people', '31 में से 20 लोग')
put('sc4', '17 of 31 people', '31 में से 17 लोग')
put('surveyNote', 'Google Form survey, 31 respondents. Percentages rounded to one decimal place.',
    'Google Form सर्वे, 31 लोगों ने जवाब दिया। प्रतिशत एक दशमलव तक।')
put('surveyMore', 'Also: 80.6% called choosing the right treatment a major challenge, 67.7% don’t keep their records digitally, and 61.3% wanted a tool that explains reports and prescriptions.',
    'साथ ही: 80.6% ने सही इलाज चुनना बड़ी चुनौती बताया, 67.7% अपने रिकॉर्ड डिजिटल नहीं रखते, और 61.3% ऐसा ऐप चाहते थे जो रिपोर्ट और पर्चे समझाए।')
put('exampleNote', 'Sample data for illustration.', 'उदाहरण के लिए बनाया गया नमूना डेटा।')
put('p4t', 'Stored in India, visible only to you', 'भारत में रखा जाता है, सिर्फ़ आपको दिखता है')
put('p4x', 'Your records live in a private account on servers in Mumbai. Only you can open them, and sensitive records can be hidden behind a PIN.',
    'आपके रिकॉर्ड मुंबई के सर्वर पर आपके निजी खाते में रहते हैं। उन्हें सिर्फ़ आप खोल सकते हैं, और ज़्यादा निजी रिकॉर्ड PIN के पीछे छिपाए जा सकते हैं।')
put('f9d', 'Keep records for many families from one phone.', 'एक फ़ोन से कई परिवारों के रिकॉर्ड संभालें।')
put('f7d', 'Blood group, allergies, conditions and an emergency contact on one screen.',
    'ब्लड ग्रुप, एलर्जी, बीमारियाँ और आपातकालीन संपर्क — एक ही स्क्रीन पर।')
put('a3', 'Your records are kept in a private account on servers in Mumbai, India. Only you can open them, and sensitive records can be hidden behind a PIN. To explain a report, its photo and text are read by AI services (Google Cloud Vision and Groq). Our privacy policy has the details.',
    'आपके रिकॉर्ड भारत में, मुंबई के सर्वर पर आपके निजी खाते में रखे जाते हैं। उन्हें सिर्फ़ आप खोल सकते हैं, और ज़्यादा निजी रिकॉर्ड PIN के पीछे छिपाए जा सकते हैं। रिपोर्ट समझाने के लिए उसकी फ़ोटो और लिखावट AI सेवाओं (Google Cloud Vision और Groq) से पढ़वाई जाती है। पूरी जानकारी प्राइवेसी पॉलिसी में है।')
put('a4', 'No. MedVerse needs internet to load your records and to read new reports. The SOS button opens your phone’s dialer for 108, which works wherever you have a mobile network.',
    'नहीं। MedVerse को आपके रिकॉर्ड खोलने और नई रिपोर्ट पढ़ने के लिए इंटरनेट चाहिए। SOS बटन आपके फ़ोन के डायलर में 108 खोलता है, जो मोबाइल नेटवर्क होने पर कहीं भी काम करता है।')
put('a6', 'Android phones with Android 7.0 or newer. An iPhone version is not available yet.',
    'Android 7.0 या उससे नए Android फ़ोन पर। iPhone वर्ज़न अभी उपलब्ध नहीं है।')
put('dlP', 'Works on Android 7.0 and newer. MedVerse isn’t on the Play Store yet, so you install it directly — it takes about a minute.',
    'Android 7.0 और उससे नए फ़ोन पर चलता है। MedVerse अभी Play Store पर नहीं है, इसलिए इसे सीधे इंस्टॉल करें — लगभग एक मिनट लगता है।')
put('a7', 'Take a clear photo of your report or prescription with the app. MedVerse reads the text (this needs internet) and explains the medical terms in plain words.',
    'ऐप से अपनी रिपोर्ट या पर्चे की साफ़ फ़ोटो लें। MedVerse लिखावट पढ़ता है (इसके लिए इंटरनेट चाहिए) और मेडिकल शब्द आसान भाषा में समझाता है।')
put('a10', f'Email our team at {EMAIL}.', f'हमारी टीम को {EMAIL} पर ईमेल करें।')
put('p1Bio', 'Ran our survey of 31 people, shaped how the app works for families, and wrote the project documentation.',
    '31 लोगों का सर्वे किया, ऐप को परिवारों के हिसाब से ढाला, और प्रोजेक्ट का दस्तावेज़ तैयार किया।')
put('explained', 'MedVerse explains', 'MedVerse समझाता है')
put('printedNote', 'This is how the lab prints it. Now press “MedVerse explains”.',
    'लैब इसे ऐसे छापती है। अब “MedVerse समझाता है” दबाएँ।')
put('kSentenceOther', 'सामान्य से बहुत ज़्यादा। यह रिपोर्ट आज ही डॉक्टर को दिखाएँ।',
    'Much higher than normal. Show this report to a doctor today.')   # shown in the *other* language
put('dSosTitle', 'Calling ambulance 108', 'एम्बुलेंस 108 को कॉल हो रही है')
put('dSosBody', 'Calling ambulance 108 now', 'एम्बुलेंस 108 को अभी कॉल हो रही है')
for k in ('cta1sub', 'dlBtn'):
    for L in (EN, HI):
        L[k] = re.sub(r'\d+(\.\d+)? MB', SIZE, L[k])

# brand spelling: the app, logo and submission all use MedVerse
for L in (EN, HI):
    for k, v in L.items():
        L[k] = v.replace('Medverse', 'MedVerse')

new_js = s[:i] + json.dumps(data, ensure_ascii=False, indent=2) + s[j:]
wr(sp, new_js)

# ───────────────────────── 4. index.html ─────────────────────────
h = rd(f'{SITE}/index.html')
# real survey numbers
for old, new in (('84%', '96.8%'), ('68%', '83.9%'), ('42%', '64.5%'), ('90%', '54.8%')):
    h = h.replace(f'<span class="num">{old}</span>', f'<span class="num">{new}</span>')
for n in (1, 2, 3, 4):
    if f'data-i18n="sc{n}"' not in h:
        h = h.replace(f'<p data-i18n="st{n}">', f'<p data-i18n="st{n}">', 1)
        h = re.sub(rf'(<p data-i18n="st{n}">[^<]*</p>)', rf'\1<small class="of" data-i18n="sc{n}"></small>', h, count=1)
if 'data-i18n="surveyMore"' not in h:
    h = h.replace('<p class="note" data-i18n="surveyNote">', '<p class="survey-more" data-i18n="surveyMore"></p>\n    <p class="note" data-i18n="surveyNote">', 1)
h = h.replace('<span>Ref: [ID]</span>', '<span>Ref: 20418</span>')
h = h.replace('<li>Android 8.0+</li>', '<li>Android 7.0+</li>')
h = h.replace('mailto:madhavladdha@gmail.com">madhavladdha@gmail.com', f'mailto:{EMAIL}">{EMAIL}')
# local fonts only (no Google Fonts request)
h = re.sub(r'\s*<link rel="preconnect" href="https://fonts\.g[^>]*>', '', h)
h = re.sub(r'\s*<link href="https://fonts\.googleapis\.com[^>]*>', '', h)
# social preview needs a raster image
h = h.replace('assets/img/favicon.svg">\n  <meta property="og:image:width"', 'assets/img/og.png">\n  <meta property="og:image:width"')
h = h.replace('<meta property="og:image" content="https://cosmicmadhav.github.io/medverse/assets/img/favicon.svg">', f'<meta property="og:image" content="{BASE}assets/img/og.png">\n  <meta property="og:image:alt" content="MedVerse — your family’s health, in words you understand">')
if 'twitter:image' not in h:
    h = h.replace('<meta name="twitter:card" content="summary_large_image">',
                  f'<meta name="twitter:card" content="summary_large_image">\n  <meta name="twitter:title" content="MedVerse — your family’s health, in words you understand">\n  <meta name="twitter:image" content="{BASE}assets/img/og.png">')
if 'apple-touch-icon' not in h:
    h = h.replace('<link rel="icon" href="assets/img/favicon.svg" type="image/svg+xml">',
                  '<link rel="icon" href="assets/img/favicon.svg" type="image/svg+xml">\n  <link rel="apple-touch-icon" href="assets/img/apple-touch-icon.png">')
# checksum so people can verify the file
if 'class="sha"' not in h:
    h = h.replace('<li data-i18n="chipFree">Free</li></ul>', f'<li data-i18n="chipFree">Free</li></ul>\n        <p class="sha">SHA-256: <code>{SHA}</code></p>')
h = re.sub(r'(<p class="sha">SHA-256: <code>)[0-9a-f]{64}', rf'\g<1>{SHA}', h)
h = h.replace('Medverse', 'MedVerse')

# sync the no-JS fallback text with the English strings
def sync(m):
    key = m.group(3)
    if key in EN and '{' not in EN[key]:
        return m.group(1) + html.escape(EN[key], quote=False) + m.group(5)
    return m.group(0)

h = re.sub(r'(<(\w+)[^>]*data-i18n="(\w+)"[^>]*>)([^<]*)(</\2>)', sync, h)
wr(f'{SITE}/index.html', h)

# ───────────────────────── 5. privacy policy ─────────────────────────
pv = rd(f'{SITE}/privacy.html')
pv = re.sub(r'\s*<link rel="preconnect" href="https://fonts\.g[^>]*>', '', pv)
pv = re.sub(r'\s*<link href="https://fonts\.googleapis\.com[^>]*>', '', pv)
body = f"""<main class="policy">
  <a class="back" href="index.html">← Back to MedVerse</a>
  <h1>Privacy Policy</h1>
  <p>Last updated: 5 October 2026</p>

  <div class="summary">
    <p>In short: MedVerse keeps your family’s health records in a private account so it can explain, organise and compare them for you. Only you can open them. To read and explain a report, its photo and text are processed by AI services. We never sell your data. You can delete everything from inside the app.</p>
  </div>

  <h2>1. Who we are</h2>
  <p>MedVerse is built by Preeti Maheshwari and Madhav Laddha as a student project at APC Post Graduate College, Pratapgarh, Rajasthan, India, presented at IEEE WIE ILS 2026. It is currently a testing release, not a commercial service. Contact: <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>

  <h2>2. What we collect</h2>
  <ul>
    <li><b>About you and your family:</b> the name, age, gender, blood group, city, emergency contact number, allergies and conditions you type in, for yourself and each family member you add.</li>
    <li><b>Documents:</b> photos you take or choose of reports, prescriptions and scans, and the text read from them.</li>
    <li><b>Health records you create:</b> lab values, medicines and dose schedules (including which doses you ticked), doctor visits, comparisons between doctors’ advice, saved questions, cycle and pregnancy entries, and ASHA register notes if you use that mode.</li>
    <li><b>Settings:</b> language, larger-text choice, and your ABHA number only if you enter it.</li>
  </ul>
  <p>There is no sign-up with e-mail, phone number, OTP or password. The app creates a private account with a random ID the first time you open it and keeps the sign-in key in your phone’s secure storage. We do not use advertising or analytics tools.</p>

  <h2>3. How we use it</h2>
  <ul>
    <li>To show your records, explain lab values and prescriptions in simple English and Hindi, and warn you about things such as repeated tests or two similar medicines.</li>
    <li>To compare two doctors’ advice side by side and prepare questions for your visit.</li>
    <li>To show your emergency health card and call 108 when you use SOS.</li>
  </ul>

  <h2>4. Where it is stored and how it is protected</h2>
  <ul>
    <li>Your data is stored with Supabase in their Mumbai (India) region. It is encrypted in transit (HTTPS) and at rest by the provider.</li>
    <li>Access rules in the database let each account read and write only its own rows. Photos are kept in a private storage folder and shown through short-lived links.</li>
    <li>The optional PIN hides sensitive records inside the app. It protects against someone using your unlocked phone; it is not a separate layer of encryption.</li>
    <li>Records are not end-to-end encrypted. The project team has administrator access to the database. We will not look at your records except to fix a problem you ask us to look into.</li>
  </ul>

  <h2>5. Other companies that handle your data</h2>
  <p>To turn a photo into explained results we use outside services through our own server. We do not sell data or share it with insurers, employers or advertisers.</p>
  <ul>
    <li><b>Google Cloud Vision</b> reads the text in your report photo. The photo is sent as it is, so any name printed on the paper goes with it.</li>
    <li><b>Groq</b> runs the AI models that write plain-language explanations, compare opinions and answer your questions. We send the document text and the values or records needed for the task. We do not send your account details or phone number.</li>
    <li><b>Supabase</b> hosts the database, file storage and the server functions.</li>
    <li><b>Android speech and text-to-speech</b> (provided by your phone, usually by Google) handle voice input and reading aloud.</li>
  </ul>
  <p>These services may process data outside India, under their own privacy policies. If you do not want a document processed this way, do not add it to the app.</p>

  <h2>6. Keeping and deleting your data</h2>
  <ul>
    <li>We keep your data until you delete it. In the app, open Profile and choose “Delete all my data” to remove your records, photos, family members and profile from our database.</li>
    <li>Because there is no password, the sign-in key lives only on your phone. If you uninstall the app or lose the phone without deleting first, you cannot get back in, and the data stays stored but unreachable. Email us and we will delete it on request.</li>
    <li>You can also share a summary of all records from the Profile screen.</li>
  </ul>

  <h2>7. Your rights</h2>
  <p>You can view, correct and delete any record in the app, withdraw consent by deleting your data, and ask us questions or raise a complaint at <a href="mailto:{EMAIL}">{EMAIL}</a>. We aim to follow the principles of India’s Digital Personal Data Protection Act, 2023. If you add a child’s records, you confirm that you are their parent or guardian.</p>

  <h2>8. Medical disclaimer</h2>
  <p>MedVerse explains medical records to help families talk to their doctors. It does not diagnose diseases, recommend or change medicines, or replace professional care. In an emergency call 108 or 112 or go to the nearest hospital.</p>

  <h2>9. Changes to this policy</h2>
  <p>If we change this policy, the new version will appear here with a new date.</p>
</main>"""
pv = re.sub(r'<main class="policy">.*?</main>', lambda m: body, pv, flags=re.S)
pv = pv.replace('Medverse', 'MedVerse')
wr(f'{SITE}/privacy.html', pv)

# ───────────────────────── 6. SEO + 404 ─────────────────────────
wr(f'{SITE}/robots.txt', f'User-agent: *\nAllow: /\nSitemap: {BASE}sitemap.xml\n')
wr(f'{SITE}/sitemap.xml', f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>{BASE}</loc></url>\n  <url><loc>{BASE}privacy.html</loc></url>\n</urlset>\n')
wr(f'{SITE}/404.html', """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Page not found — MedVerse</title><meta name="robots" content="noindex">
<link rel="icon" href="assets/img/favicon.svg" type="image/svg+xml"><link rel="stylesheet" href="assets/css/site.css">
<style>.nf{min-height:80vh;display:grid;place-items:center;text-align:center;padding:2rem}.nf h1{font-family:var(--serif);font-size:clamp(2rem,6vw,3rem);color:var(--brand);margin:1rem 0 .5rem}.nf p{margin-bottom:1.5rem}</style></head>
<body><main class="nf"><div><svg width="48" height="56" viewBox="-6 -6 99 112" fill="none" aria-hidden="true"><path d="M50.8 100 L55.4 92.8 L62.2 86.8 L67.1 79.6 L71.7 71.9 L76.1 63.5 L79.9 55.1 L82.8 46.7 L85 38.3 L86.2 29.9 L86.2 21.6 L84.8 13.2 L81.1 5.1 L73.9 0 L65.5 1.6 L57.7 6.3 L50.5 11.4 L42.1 13.7 L34 9.9 L26.9 4.9 L18.8 .7 L10.4 .6 L4 6.9 L.9 15.3 L0 23.7 L1 32 L3.7 40.4 L7.7 48.8 L12.5 56.3 L18.1 63.5 L24.5 70.1 L31.3 76.4 L38.2 81.7" stroke="#043B42" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/><path d="M23.9 32.9 L32.2 36.7 L39.7 42.1 L46 49.1 L50.4 57.2 L52.8 65.6 L53.1 72 L50.8 100" stroke="#043B42" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/></svg>
<h1>This page doesn’t exist</h1><p>The link may be old or mistyped.</p><a class="btn btn-primary" href="./">Back to MedVerse</a></div></main></body></html>
""")

# ───────────────────────── 7. share image + touch icon ─────────────────────────
from PIL import Image, ImageDraw, ImageFont
OUTER = [[50.8,100],[55.4,92.8],[62.2,86.8],[67.1,79.6],[71.7,71.9],[76.1,63.5],[79.9,55.1],[82.8,46.7],[85,38.3],[86.2,29.9],[86.2,21.6],[84.8,13.2],[81.1,5.1],[73.9,0],[65.5,1.6],[57.7,6.3],[50.5,11.4],[42.1,13.7],[34,9.9],[26.9,4.9],[18.8,.7],[10.4,.6],[4,6.9],[.9,15.3],[0,23.7],[1,32],[3.7,40.4],[7.7,48.8],[12.5,56.3],[18.1,63.5],[24.5,70.1],[31.3,76.4],[38.2,81.7]]
LEAF = [[23.9,32.9],[32.2,36.7],[39.7,42.1],[46,49.1],[50.4,57.2],[52.8,65.6],[53.1,72],[50.8,100]]


def heart(img, x, y, h, color, stroke_units=9, plus=None):
    d = ImageDraw.Draw(img)
    s = h / 100.0
    for pts in (OUTER, LEAF):
        xy = [(x + p[0] * s, y + p[1] * s) for p in pts]
        d.line(xy, fill=color, width=max(2, int(stroke_units * s)), joint='curve')
        for (a, b) in (xy[0], xy[-1]):
            pass
        r = stroke_units * s / 2
        for (a, b) in xy:
            d.ellipse([a - r, b - r, a + r, b + r], fill=color)
    if plus:
        cx, cy, arm = x + 66 * s, y + 29 * s, 7 * s
        d.line([(cx, cy - arm), (cx, cy + arm)], fill=plus, width=int(7 * s))
        d.line([(cx - arm, cy), (cx + arm, cy)], fill=plus, width=int(7 * s))


BRAND, MINT = (4, 59, 66), (178, 228, 222)
ser = ImageFont.truetype('google_fonts/YoungSerif-Regular.ttf', 74)
serS = ImageFont.truetype('google_fonts/YoungSerif-Regular.ttf', 40)
sans = ImageFont.truetype('google_fonts/Figtree-Medium.ttf', 32)
og = Image.new('RGB', (1200, 630), BRAND)
heart(og, 90, 150, 330, MINT, plus=(79, 168, 158))
d = ImageDraw.Draw(og)
d.text((520, 150), 'MedVerse', font=serS, fill=MINT)
d.text((520, 215), 'Your family’s health,', font=ser, fill=(255, 255, 255))
d.text((520, 300), 'in words you understand.', font=ser, fill=(255, 255, 255))
d.text((520, 430), 'Understand  ·  Organise  ·  Compare', font=sans, fill=MINT)
d.text((520, 480), 'Free for Android · English & Hindi', font=sans, fill=(214, 239, 235))
os.makedirs(f'{SITE}/assets/img', exist_ok=True)
og.save(f'{SITE}/assets/img/og.png', optimize=True)
ic = Image.new('RGB', (180, 180), BRAND)
heart(ic, 38, 30, 120, MINT, stroke_units=11, plus=(79, 168, 158))
ic.save(f'{SITE}/assets/img/apple-touch-icon.png', optimize=True)
print('done')
