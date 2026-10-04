/* Medverse website behaviour. No dependencies.
   - Language switch (English / हिंदी), remembered on this device
   - "Larger text" (A+), remembered on this device
   - "As printed / Medverse explains" toggle
   - Compare case switcher
   - Thread connectors that draw when scrolled into view
   - The live app demo inside the phone */
(function () {
  'use strict';
  var S = window.MV_STRINGS;
  var root = document.documentElement;
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function fmt(s, vars) { return s.replace(/\{(\w+)\}/g, function (_, k) { return vars[k]; }); }

  // ---------------------------------------------------------------- state
  var params = new URLSearchParams(location.search);
  var state = {
    lang: params.get('lang') === 'hi' || params.get('lang') === 'en' ? params.get('lang') : (store('mv-lang') || 'en'),
    comfort: store('mv-comfort') === '1',
    cmp: 'knee',
    demo: { member: 'mother', taken: false, justTaken: false, sos: null, count: 5, hint: false }
  };
  function t(k) { return (S[state.lang] && S[state.lang][k]) || S.en[k] || ''; }

  // ---------------------------------------------------------------- language
  function applyLang() {
    var other = state.lang === 'hi' ? 'en' : 'hi';
    root.lang = state.lang;
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var v = t(el.getAttribute('data-i18n'));
      if (v) el.textContent = v;
      if (el.hasAttribute('data-lang-other')) el.lang = other;
    });
    document.querySelectorAll('[data-i18n-aria]').forEach(function (el) {
      el.setAttribute('aria-label', t(el.getAttribute('data-i18n-aria')));
    });
    var lb = document.getElementById('langBtn');
    if (lb) lb.lang = other;
    document.title = t('metaTitle');
    var md = document.querySelector('meta[name="description"]');
    if (md) md.setAttribute('content', t('metaDesc'));
    renderCompare();
    renderDemo(false);
  }
  document.getElementById('langBtn').addEventListener('click', function () {
    state.lang = state.lang === 'hi' ? 'en' : 'hi';
    store('mv-lang', state.lang);
    applyLang();
  });

  // ---------------------------------------------------------------- larger text
  var comfortBtn = document.getElementById('comfortBtn');
  function applyComfort() {
    root.classList.toggle('is-comfort', state.comfort);
    comfortBtn.setAttribute('aria-pressed', String(state.comfort));
  }
  comfortBtn.addEventListener('click', function () {
    state.comfort = !state.comfort;
    store('mv-comfort', state.comfort ? '1' : '0');
    applyComfort();
  });

  // ---------------------------------------------------------------- printed / explained
  var vP = document.getElementById('vPrinted'), vE = document.getElementById('vExplained');
  var cP = document.getElementById('printedCard'), cE = document.getElementById('explainedCard');
  function setView(printed) {
    vP.setAttribute('aria-pressed', String(printed));
    vE.setAttribute('aria-pressed', String(!printed));
    cP.hidden = !printed; cE.hidden = printed;
    var shown = printed ? cP : cE;
    shown.classList.remove('swap-in'); void shown.offsetWidth; shown.classList.add('swap-in');
  }
  vP.addEventListener('click', function () { setView(true); });
  vE.addEventListener('click', function () { setView(false); });

  // ---------------------------------------------------------------- compare
  var CASES = {
    knee: { title: 'kneeTitle', a: 'kneeA', aRole: 'kneeARole', b: 'kneeB', bRole: 'kneeBRole', counts: [2, 3, 2], q: 'kneeQ',
      rows: [['rDiag', 'kneeDiag', true], ['rTreat', 'kneeTreat', false]] },
    diabetes: { title: 'diaTitle', a: 'diaA', aRole: 'diaARole', b: 'diaB', bRole: 'diaBRole', counts: [1, 2, 0], q: 'diaQ',
      rows: [['rDiag', 'diaDiag', true], ['rMeds', 'diaMeds', false], ['rTests', 'diaTests', false]] }
  };
  function renderCompare() {
    var c = CASES[state.cmp], el = document.getElementById('cmpCard');
    var cls = ['c-agree', 'c-differ', 'c-one'], lab = ['nAgree', 'nDiffer', 'nOne'];
    var bar = '', legend = '';
    c.counts.forEach(function (n, i) {
      if (!n) return;
      bar += '<span class="' + cls[i] + '" style="flex:' + n + '"></span>';
      legend += '<li><i class="' + cls[i] + '"></i>' + esc(fmt(t(lab[i]), { n: n })) + '</li>';
    });
    el.innerHTML =
      '<h4 class="cmp-title" style="margin:0;font-weight:400">' + esc(t(c.title)) + '</h4>' +
      '<div class="docs"><div class="doc a"><span class="letter">A</span><span class="who"><b>' + esc(t(c.a)) + '</b><small>' + esc(t(c.aRole)) + '</small></span></div>' +
      '<div class="doc b"><span class="letter">B</span><span class="who"><b>' + esc(t(c.b)) + '</b><small>' + esc(t(c.bRole)) + '</small></span></div></div>' +
      '<div class="cmp-rows">' + c.rows.map(function (r) {
        return '<div class="cmp-row"><span class="what"><b>' + esc(t(r[0])) + '</b><span>' + esc(t(r[1])) + '</span></span>' +
          '<span class="tag ' + (r[2] ? 'tag-mint' : 'tag-alert') + '">' + esc(t(r[2] ? 'agree' : 'differ')) + '</span></div>';
      }).join('') + '</div>' +
      '<div class="stack" style="gap:.5rem"><div class="agree-bar" aria-hidden="true">' + bar + '</div><ul class="legend">' + legend + '</ul></div>' +
      '<div class="fake-btn">' + esc(t(c.q)) + '</div>';
    el.classList.remove('swap-in'); void el.offsetWidth; el.classList.add('swap-in');
  }
  document.querySelectorAll('[data-case]').forEach(function (b) {
    b.addEventListener('click', function () {
      state.cmp = b.getAttribute('data-case');
      document.querySelectorAll('[data-case]').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
      renderCompare();
    });
  });

  // ---------------------------------------------------------------- thread connectors
  var links = document.querySelectorAll('.link');
  if (!reduced && 'IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); } });
    }, { rootMargin: '0px 0px -15% 0px' });
    links.forEach(function (l) { io.observe(l); });
  } else {
    links.forEach(function (l) { l.classList.add('is-in'); });
  }

  // ================================================================ APP DEMO
  var demoEl = document.getElementById('demo');
  var C = 182.2;
  var ICON = {
    check: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#043B42" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
    bell: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#043B42" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',
    heart: '<svg width="24" height="28" viewBox="-6 -6 99 112" fill="none" aria-hidden="true"><path d="M50.8 100 L55.4 92.8 L62.2 86.8 L67.1 79.6 L71.7 71.9 L76.1 63.5 L79.9 55.1 L82.8 46.7 L85 38.3 L86.2 29.9 L86.2 21.6 L84.8 13.2 L81.1 5.1 L73.9 0 L65.5 1.6 L57.7 6.3 L50.5 11.4 L42.1 13.7 L34 9.9 L26.9 4.9 L18.8 .7 L10.4 .6 L4 6.9 L.9 15.3 L0 23.7 L1 32 L3.7 40.4 L7.7 48.8 L12.5 56.3 L18.1 63.5 L24.5 70.1 L31.3 76.4 L38.2 81.7" stroke="#043B42" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/><path d="M23.9 32.9 L32.2 36.7 L39.7 42.1 L46 49.1 L50.4 57.2 L52.8 65.6 L53.1 72 L50.8 100" stroke="#043B42" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    plus: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1F6F68" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
    mic: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#043B42" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
    doc: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#043B42" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 19V5a2 2 0 0 1 2-2h9l5 5v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><path d="M8 13h8M8 17h5"/></svg>',
    folder: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#043B42" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>',
    cmp: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#043B42" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 4v16M16 4v16M4 9h4M16 15h4M4 15h4M16 9h4"/></svg>'
  };
  function navIcon(path, color, fill) { return '<svg width="24" height="24" viewBox="0 0 24 24" fill="' + (fill ? color : 'none') + '" stroke="' + (fill ? 'none' : color) + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="' + path + '"/></svg>'; }

  function members() {
    var d = state.demo;
    return [
      { id: 'self', ini: 'PM', name: t('dPreeti'), status: t('dNothingDue'), ring: 0, color: '#1F8C80', alert: false },
      { id: 'mother', ini: 'SM', name: t('dSunita'), status: d.taken ? t('dAllDone') : t('dDoses'), ring: d.taken ? 1 : 0.5, color: '#1F8C80', alert: false },
      { id: 'father', ini: 'RM', name: t('dRamesh'), status: t('dNeedsYou'), ring: 1, color: '#D2571C', alert: true }
    ];
  }
  function hero() {
    var d = state.demo;
    if (d.member === 'father') return { eyebrow: t('dFEyebrow'), head: t('dFHead'), alert: true, rows: [
      { time: t('dToday'), title: t('dKHigh'), detail: t('dKDetail'), state: 'alert', act: t('dViewReport') },
      { time: t('dTomorrow'), title: t('dJain'), detail: t('dJaind'), state: 'next', act: t('dPrep') }] };
    if (d.member === 'self') return { eyebrow: t('dSEyebrow'), head: t('dSHead'), rows: [
      { time: t('dSaved'), title: t('dThy'), detail: t('dThyd'), state: 'later', act: t('dOpenCmp') }] };
    return { eyebrow: t('dMEyebrow'), head: d.taken ? t('dMDone') : t('dMNext'), rows: [
      { time: t('dAm9'), title: t('dMed1'), detail: t('dMed1d'), state: 'done', tag: t('dTaken') },
      d.taken ? { time: t('dPm2'), title: t('dMed2'), detail: t('dMed2d'), state: 'done', tag: t('dTaken'), tick: d.justTaken }
              : { time: t('dPm2'), title: t('dMed2'), detail: t('dMed2d'), state: 'next', act: t('dMarkTaken'), take: true },
      { time: t('dDec28'), title: t('dMeera'), detail: t('dMeerad'), state: 'later', tag: '9:00' }] };
  }

  function renderDemo(animateThread) {
    var d = state.demo, h = hero(), ms = members();
    var noAnim = !animateThread || reduced;
    var fam = ms.map(function (m) {
      var on = m.id === d.member;
      return '<button class="member" type="button" data-member="' + m.id + '" aria-pressed="' + on + '" aria-label="' + esc(m.name + ', ' + m.status) + '">' +
        '<span class="r"><svg width="66" height="66" viewBox="0 0 66 66" aria-hidden="true"><circle cx="33" cy="33" r="29" fill="none" stroke="#DCE7E5" stroke-width="5"/>' +
        '<circle class="fg" cx="33" cy="33" r="29" fill="none" stroke="' + m.color + '" stroke-width="5" stroke-linecap="round" stroke-dasharray="' + (m.ring * C).toFixed(1) + ' ' + C + '"/></svg>' +
        '<span class="seal">' + m.ini + '</span></span><span class="nm">' + esc(m.name) + '</span><span class="st' + (m.alert ? ' alert' : '') + '">' + esc(m.status) + '</span></button>';
    }).join('') +
      '<span class="member ghost" aria-hidden="true"><span class="r">' + ICON.plus + '</span><span class="nm">' + esc(t('dAdd')) + '</span><span class="st">' + esc(t('dFamily')) + '</span></span>';

    var rows = h.rows.map(function (r, i) {
      var last = i === h.rows.length - 1;
      var style = noAnim ? ' style="--i:' + i + ';animation:none"' : ' style="--i:' + i + '"';
      var nodeCls = 'node ' + r.state + (r.tick ? ' tick' : '');
      return '<li>' +
        (last ? '' : '<span class="ln ' + (r.state === 'done' ? 'done' : r.state === 'alert' ? 'alert' : '') + '"' + style + '></span>') +
        '<span class="t">' + esc(r.time) + '</span>' +
        '<span class="' + nodeCls + '"' + (r.tick ? ' style="--i:0"' : style) + '>' + (r.state === 'done' ? ICON.check : r.state === 'alert' ? '!' : '') + '</span>' +
        '<span class="body"' + style + '><b class="' + (r.state === 'done' ? 'dim' : '') + '">' + esc(r.title) + '</b><small>' + esc(r.detail) + '</small>' +
        (r.act ? '<button type="button" class="act' + (r.state === 'alert' ? ' soft' : '') + '"' + (r.take ? ' data-take' : '') + '>' + esc(r.act) + '</button>' : '') +
        (r.tag ? '<span class="tag ' + (r.state === 'done' ? 'tag-mint' : 'tag-neutral') + '">' + esc(r.tag) + '</span>' : '') +
        '</span></li>';
    }).join('');

    var html =
      '<div class="app" lang="' + state.lang + '">' +
      '<div class="app-top"><div class="app-row"><span class="app-hello">' + ICON.heart + esc(t('dHello')) + '</span>' +
      '<span style="display:flex;gap:.625rem;align-items:center"><span class="app-bell" aria-hidden="true">' + ICON.bell + '<i>9</i></span>' +
      '<button type="button" class="app-sos" id="demoSos" aria-label="' + esc(t('sosHint')) + '"><span class="fill"></span><span>SOS</span></button></span></div>' +
      '<div class="app-title"><h3>' + esc(t('dTitle')) + '</h3><small>' + esc(t('dDate')) + '</small></div></div>' +
      '<div class="app-family" role="group">' + fam + '</div>' +
      '<div class="today"><div class="band' + (h.alert ? ' alert' : '') + '"><small>' + esc(h.eyebrow) + '</small><h4 aria-live="polite">' + esc(h.head) + '</h4></div>' +
      '<ul class="thread">' + rows + '</ul></div>' +
      '<div class="app-section"><h4>' + esc(t('dNeeds')) + ' <i>9</i></h4>' +
      '<div class="app-card"><div class="row-between"><span class="mini-eyebrow">' + esc(t('dFEyebrow')) + '</span><span class="tag tag-alert">' + esc(t('seeDoc')) + '</span></div>' +
      '<div class="value-line"><span class="name" style="font-size:1.0625rem">' + esc(t('potassium')) + '</span><span class="big" style="font-size:2.125rem">6.3</span><span class="muted" style="font-size:.875rem">mmol/L</span></div>' +
      '<div class="range"><div class="bar"><span class="normal"></span><span class="dot"></span></div><div class="labels"><span class="l1">3.5</span><span class="l2">' + esc(t('normal')) + '</span><span class="l3">5.1</span></div></div></div></div>' +
      '<div class="app-section"><div class="app-ask"><div><b>' + esc(t('dAsk')) + '</b><small>' + esc(t('dAskSub')) + '</small></div><span>' + ICON.mic + '</span></div>' +
      '<div class="app-pillars"><div><em>' + ICON.doc + '</em><b>' + esc(t('dUnderstand')) + '</b></div><div><em>' + ICON.folder + '</em><b>' + esc(t('dOrganise')) + '</b></div><div><em>' + ICON.cmp + '</em><b>' + esc(t('dCompare')) + '</b></div></div></div>' +
      '<div class="app-nav" aria-hidden="true">' +
      '<span class="on">' + navIcon('M3 10.5L12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z', '#043B42', true) + esc(t('dNavHome')) + '</span>' +
      '<span>' + navIcon('M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', '#3D5A5E') + esc(t('dNavRecords')) + '</span>' +
      '<span><span class="plus"><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#B2E4DE" stroke-width="3.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg></span>' + esc(t('dAdd')) + '</span>' +
      '<span>' + navIcon('M8 4v16M16 4v16M4 9h4M16 15h4M4 15h4M16 9h4', '#3D5A5E') + esc(t('dNavCompare')) + '</span>' +
      '<span>' + navIcon('M3 17c3 0 3-10 6-10s3 10 6 10 3-6 6-6', '#3D5A5E') + esc(t('dNavJourney')) + '</span></div>' +
      (d.hint ? '<div class="app-toast" role="status">' + esc(t('sosHint')) + '</div>' : '') +
      (d.sos ? '<div class="app-overlay" role="alertdialog" aria-label="SOS"><div class="count" aria-live="assertive">' + (d.sos === 'sent' ? 'SOS' : d.count) + '</div>' +
        '<h4>' + esc(t('dSosTitle')) + '</h4><p>' + esc(t('dSosBody')) + '</p><button type="button" id="demoCancel">' + esc(t('dCancel')) + '</button></div>' : '') +
      '</div>';
    var scroll = demoEl.scrollTop;
    demoEl.innerHTML = html;
    demoEl.scrollTop = scroll;
    bindSos();
    if (d.sos) { var cb = document.getElementById('demoCancel'); if (cb) cb.focus(); }
  }

  demoEl.addEventListener('click', function (e) {
    var m = e.target.closest('[data-member]');
    if (m) { state.demo.member = m.getAttribute('data-member'); state.demo.justTaken = false; renderDemo(true); return; }
    if (e.target.closest('[data-take]')) { state.demo.taken = true; state.demo.justTaken = true; renderDemo(false); return; }
    if (e.target.closest('#demoCancel')) { stopSos(); }
  });

  // SOS: hold 1.5 s → 5 s countdown with Cancel. Quick tap → hint.
  var holdTimer = null, tickTimer = null, hintTimer = null;
  function bindSos() {
    var b = document.getElementById('demoSos');
    if (!b) return;
    var start = function (e) {
      if (state.demo.sos) return;
      e.preventDefault();
      b.classList.add('holding');
      holdTimer = setTimeout(function () {
        b.classList.remove('holding');
        holdTimer = null;
        state.demo.sos = 'count'; state.demo.count = 5; state.demo.hint = false;
        renderDemo(false);
        tickTimer = setInterval(function () {
          state.demo.count -= 1;
          if (state.demo.count <= 0) { clearInterval(tickTimer); state.demo.sos = 'sent'; }
          renderDemo(false);
        }, 1000);
      }, 1500);
    };
    var end = function () {
      if (!holdTimer) return;
      clearTimeout(holdTimer); holdTimer = null;
      b.classList.remove('holding');
      state.demo.hint = true; renderDemo(false);
      clearTimeout(hintTimer);
      hintTimer = setTimeout(function () { state.demo.hint = false; renderDemo(false); }, 2600);
    };
    b.addEventListener('pointerdown', start);
    b.addEventListener('pointerup', end);
    b.addEventListener('pointerleave', end);
    b.addEventListener('pointercancel', end);
    // keyboard / screen reader: Enter or Space opens the countdown directly (the countdown is the safety net)
    b.addEventListener('keydown', function (e) {
      if ((e.key === 'Enter' || e.key === ' ') && !state.demo.sos) {
        e.preventDefault();
        state.demo.sos = 'count'; state.demo.count = 5; renderDemo(false);
        tickTimer = setInterval(function () {
          state.demo.count -= 1;
          if (state.demo.count <= 0) { clearInterval(tickTimer); state.demo.sos = 'sent'; }
          renderDemo(false);
        }, 1000);
      }
    });
  }
  function stopSos() {
    clearInterval(tickTimer); clearTimeout(holdTimer);
    state.demo.sos = null; state.demo.count = 5;
    renderDemo(false);
    var b = document.getElementById('demoSos'); if (b) b.focus();
  }

  // ---------------------------------------------------------------- QR code (optional)
  // Set data-qr-src on #qrBox (e.g. "assets/img/qr-apk.svg") and the image replaces the placeholder.
  var qr = document.getElementById('qrBox');
  if (qr && qr.getAttribute('data-qr-src')) {
    var img = new Image();
    img.onload = function () { qr.classList.remove('placeholder'); qr.textContent = ''; img.alt = ''; img.width = 96; img.height = 96; qr.appendChild(img); };
    img.src = qr.getAttribute('data-qr-src');
  }

  // ---------------------------------------------------------------- go
  applyComfort();
  applyLang();
  renderDemo(true);
})();
