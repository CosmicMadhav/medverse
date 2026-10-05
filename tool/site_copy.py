"""Plain-voice rewrite of the website copy (EN + matching HI). Idempotent."""
import html, json, re

SITE = 'site'
EMAIL = 'madhavmaheshwari314@gmail.com'


def rd(p): return open(p, encoding='utf-8').read()
def wr(p, c): open(p, 'w', encoding='utf-8', newline='\n').write(c)


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


def put(key, en, hi=None):
    EN[key] = en
    if hi is not None:
        HI[key] = hi


# ── hero ──
put('lead', 'Keep every report, prescription and doctor visit for your whole family in one place, and read them in plain English or Hindi. Go into your next appointment knowing what to ask.')
put('altLine', 'Your family’s health, in your language.', 'Your family’s health, in your language.')
put('trust1', 'Explains, never diagnoses')
put('anno1', 'Tap Ramesh. His ring is orange because a report needs a doctor today.',
    'रमेश पर टैप करें। उनका घेरा नारंगी है क्योंकि एक रिपोर्ट आज ही डॉक्टर को दिखानी है।')
put('anno2', 'Tap “Mark as taken” and watch the line fill.')

# ── survey ──
put('surveyH', 'A pile of reports and no one to explain them.', 'रिपोर्टों का ढेर, और समझाने वाला कोई नहीं।')
put('surveyP', 'We asked 31 people how their families deal with medical papers. A report from one lab, a prescription from another hospital, two doctors who say different things. Here is what they told us.',
    'हमने 31 लोगों से पूछा कि उनके परिवार मेडिकल कागज़ात कैसे संभालते हैं। एक लैब की रिपोर्ट, दूसरे अस्पताल का पर्चा, दो डॉक्टरों की अलग-अलग बातें। उन्होंने हमें यह बताया।')
put('surveyNote', 'A small survey (a Google Form, 31 people), so read these as a signal, not a study. Percentages are rounded to one decimal.',
    'छोटा सर्वे (Google Form, 31 लोग), इसलिए इसे संकेत समझें, पक्का अध्ययन नहीं। प्रतिशत एक दशमलव तक।')
put('surveyMore', 'Some other answers: 80.6% said choosing the right treatment is a big challenge, 67.7% don’t keep their records digitally, and 61.3% would like a tool that explains reports and prescriptions.',
    'कुछ और जवाब: 80.6% ने कहा कि सही इलाज चुनना बड़ी चुनौती है, 67.7% अपने रिकॉर्ड डिजिटल नहीं रखते, और 61.3% ऐसा टूल चाहेंगे जो रिपोर्ट और पर्चे समझाए।')

# ── how it works ──
put('howH', 'What MedVerse does', 'MedVerse क्या करता है')
put('s1P', 'Take a photo of a lab report. MedVerse explains each value in simple English or Hindi and can read it out loud. Every number sits next to its normal range, so you can see what matters.')
put('s1P2', 'Each explanation points back to the exact line in your original report, so you can check it yourself.',
    'हर समझाई गई बात आपकी मूल रिपोर्ट की उसी पंक्ति तक ले जाती है, ताकि आप खुद जाँच सकें।')
put('s2P', 'Your mother’s, your father’s and your own records, all in one place and in date order. It also keeps track of medicines and doctor visits, and warns you before you pay for a test you already did.')
put('s3P', 'Two doctors gave two different answers? MedVerse puts them side by side and shows where they agree and where they differ. It doesn’t pick a side. You also get a list of questions to take to your next visit.')
put('exampleNote', 'Sample data, not real patients.', 'नमूना डेटा, असली मरीज़ नहीं।')

# ── features ──
put('featH', 'What’s in the app', 'ऐप में क्या-क्या है')
put('f1d', 'English or Hindi, with every value shown next to its normal range.')
put('f3d', 'Where they agree and where they differ, shown without taking sides.', 'कहाँ सहमत हैं और कहाँ अलग, बिना किसी का पक्ष लिए।')
put('f4d', 'Warns you when two doctors prescribe the same kind of painkiller.', 'जब दो डॉक्टर एक ही तरह की दर्द की दवा लिखते हैं तो चेतावनी देता है।')
put('f5d', 'Tells you if a recent report already has the result a doctor is asking for again.', 'बताता है कि जो जाँच डॉक्टर फिर से लिख रहे हैं, उसका नतीजा हाल की किसी रिपोर्ट में पहले से है।')
put('f6d', 'Share them on WhatsApp or print them, so nothing gets forgotten at the visit.', 'WhatsApp पर भेजें या प्रिंट करें, ताकि मुलाक़ात में कुछ छूटे नहीं।')
put('f8d', 'Keep private records behind a PIN, even on a shared phone.', 'निजी रिकॉर्ड PIN के पीछे रखें, साझा फ़ोन पर भी।')
put('f9t', 'ASHA worker mode', 'ASHA कार्यकर्ता मोड')
put('f9d', 'Keep simple records for many families from one phone.')

# ── safety ──
put('safeP', 'MedVerse helps you understand your records. It does not diagnose, it does not prescribe, and it never says which doctor is right.')
put('p1t', 'Urgent values go to a doctor', 'ख़तरनाक वैल्यू सीधे डॉक्टर के पास भेजी जाती हैं')
put('p1x', 'If a result is dangerous, like potassium above 6.0, MedVerse shows “see a doctor today” and doesn’t try to explain it away.',
    'अगर कोई नतीजा ख़तरनाक है, जैसे पोटैशियम 6.0 से ऊपर, तो MedVerse “आज ही डॉक्टर को दिखाएँ” कहता है और उसे हल्का करके नहीं समझाता।')
put('p2x', 'Each plain sentence links back to the line it came from in your report.',
    'हर आसान वाक्य आपकी रिपोर्ट की उसी पंक्ति से जुड़ा है जहाँ से वह आया।')
put('p3x', 'Differences are shown side by side so you can talk them through with your doctor.')

# ── FAQ ──
put('a1', 'Yes, it’s free to download and use.', 'हाँ, डाउनलोड करना और इस्तेमाल करना मुफ़्त है।')
put('a2', 'You install it as an APK file straight from this page, because it isn’t on the Play Store yet. Android will ask your permission to install it, which is normal. Only download it from here.',
    'आप इसे सीधे इसी पेज से APK फ़ाइल के रूप में इंस्टॉल करते हैं, क्योंकि यह अभी Play Store पर नहीं है। इंस्टॉल से पहले Android अनुमति माँगेगा, यह सामान्य है। इसे सिर्फ़ यहीं से डाउनलोड करें।')
put('a5', 'No. It explains what your reports and prescriptions already say. Only your doctor can diagnose you or decide your treatment.',
    'नहीं। यह वही समझाता है जो आपकी रिपोर्ट और पर्चे में पहले से लिखा है। बीमारी तय करना और इलाज चुनना सिर्फ़ आपके डॉक्टर का काम है।')
put('a8', 'Yes. Add separate profiles for your parents, children and spouse, and keep each person’s records, medicines and doctor visits in one app.',
    'हाँ। माता-पिता, बच्चों और जीवनसाथी के अलग प्रोफ़ाइल जोड़ें, और हर किसी के रिकॉर्ड, दवाइयाँ और डॉक्टर की मुलाक़ातें एक ही ऐप में रखें।')
put('a9', 'Add prescriptions from two doctors and MedVerse lists what they agree on, like the tests, and what is different, like the medicines. It also flags two similar painkillers.',
    'दो डॉक्टरों के पर्चे जोड़ें, तो MedVerse दिखाता है कि वे किन बातों पर सहमत हैं (जैसे जाँचें) और किनमें फ़र्क़ है (जैसे दवाइयाँ)। अगर दो एक जैसी दर्द की दवाएँ हों तो यह भी बताता है।')

# ── download / team / footer ──
put('dlP', 'Works on Android 7.0 and newer. It isn’t on the Play Store yet, so you install it directly. It takes about a minute.',
    'Android 7.0 और उससे नए फ़ोन पर चलता है। यह अभी Play Store पर नहीं है, इसलिए इसे सीधे इंस्टॉल करना होता है। लगभग एक मिनट लगता है।')
put('p2Bio', 'Built the Flutter app, the part that reads report photos, and the comparison of two doctors’ advice.',
    'Flutter ऐप बनाया, रिपोर्ट की फ़ोटो पढ़ने वाला हिस्सा बनाया, और दो डॉक्टरों की सलाह की तुलना वाला हिस्सा बनाया।')
put('footTag', 'Helping families understand their medical papers.', 'परिवारों को उनके मेडिकल कागज़ समझने में मदद।')
put('disclaimer', 'MedVerse explains health information. It does not replace a doctor’s advice or diagnosis.',
    'MedVerse सेहत की जानकारी समझाता है। यह डॉक्टर की सलाह या जाँच की जगह नहीं लेता।')
put('metaDesc', 'Keep your family’s reports, prescriptions and doctor visits in one place and read them in plain English or Hindi. Android app.',
    'अपने परिवार की रिपोर्ट, पर्चे और डॉक्टर की मुलाक़ातें एक जगह रखें और आसान हिंदी या अंग्रेज़ी में पढ़ें। Android ऐप।')

# ── SOS ──
put('sosH', 'Hold to call for help.', 'मदद के लिए दबाकर रखें।')
put('sosP', 'SOS needs a deliberate press, so it can’t go off by accident, but it is always one hold away.',
    'SOS जानबूझकर दबाने पर ही चलता है, इसलिए गलती से नहीं बजता, पर हमेशा बस एक होल्ड दूर है।')
put('sos2', 'A 5-second countdown starts with a loud siren and a big Cancel button, so a slip of the thumb doesn’t call anyone.')
put('sos3', 'If you don’t cancel, your phone’s dialer opens with 108 ready, and the app shows the patient’s blood group, allergies, conditions and medicines so you can read them out.',
    'रद्द न करें तो फ़ोन के डायलर में 108 तैयार खुल जाता है, और ऐप मरीज़ का ब्लड ग्रुप, एलर्जी, बीमारियाँ और दवाइयाँ दिखाता है, ताकि आप उन्हें पढ़कर बता सकें।')
put('sosTry', 'Try it on the phone at the top: hold SOS.', 'ऊपर वाले फ़ोन पर आज़माएँ: SOS को दबाकर रखें।')
put('sosHint', 'Hold SOS to call for help', 'मदद के लिए SOS को दबाकर रखें')

# the Hindi line in the English card is only for the Hindi page now
put('kSentenceOther', 'सामान्य से बहुत ज़्यादा। यह रिपोर्ट आज ही डॉक्टर को दिखाएँ।', 'Much higher than normal. Show this report to a doctor today.')

wr(sp, s[:i] + json.dumps(data, ensure_ascii=False, indent=2) + s[j:])

# ── HTML: keep English pages English ──
h = rd(f'{SITE}/index.html')
h = h.replace('<p class="alt-line" data-i18n="altLine" data-lang-other>', '<p class="alt-line" data-i18n="altLine">')
h = re.sub(r'(<p class="alt-line"[^>]*>)[^<]*(</p>)', lambda m: m.group(1) + html.escape(EN['altLine'], quote=False) + m.group(2), h)


def sync(m):
    key = m.group(3)
    if key in EN and '{' not in EN[key]:
        return m.group(1) + html.escape(EN[key], quote=False) + m.group(5)
    return m.group(0)


h = re.sub(r'(<(\w+)[^>]*data-i18n="(\w+)"[^>]*>)([^<]*)(</\2>)', sync, h)
wr(f'{SITE}/index.html', h)

css = rd(f'{SITE}/assets/css/site.css')
if 'html[lang="en"] [data-lang-other]' not in css:
    css += '\n/* the English page stays fully English; the Hindi page shows the English line instead */\nhtml[lang="en"] [data-lang-other] { display: none; }\n'
    wr(f'{SITE}/assets/css/site.css', css)

# ── privacy page: a few stiff phrases ──
pv = rd(f'{SITE}/privacy.html')
pv = pv.replace('In short: MedVerse keeps your family’s health records in a private account so it can explain, organise and compare them for you. Only you can open them. To read and explain a report, its photo and text are processed by AI services. We never sell your data. You can delete everything from inside the app.',
                'The short version: MedVerse keeps your family’s records in a private account so it can explain and compare them for you. Only you can open them. To read a report, its photo and text are sent to AI services. We never sell your data, and you can delete everything from inside the app.')
pv = pv.replace('We aim to follow the principles of India’s Digital Personal Data Protection Act, 2023.', 'We are trying to follow the principles of India’s Digital Personal Data Protection Act, 2023.')
wr(f'{SITE}/privacy.html', pv)
print('copy updated', len(EN), len(HI))
