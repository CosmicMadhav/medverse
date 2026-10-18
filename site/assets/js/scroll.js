/* MedVerse website: things that react to scrolling. No dependencies, and everything is a no-op
   (content simply shows) when the visitor prefers reduced motion or the browser has no IntersectionObserver. */
(function () {
  'use strict';
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var canObserve = 'IntersectionObserver' in window;

  // ---- reading progress bar
  var bar = document.getElementById('progress');
  if (bar && !reduced) {
    var ticking = false;
    var update = function () {
      var h = document.documentElement;
      var max = h.scrollHeight - h.clientHeight;
      bar.style.transform = 'scaleX(' + (max > 0 ? Math.min(1, window.scrollY / max) : 0) + ')';
      ticking = false;
    };
    window.addEventListener('scroll', function () { if (!ticking) { ticking = true; requestAnimationFrame(update); } }, { passive: true });
    update();
  }

  // ---- gentle reveal for cards and headings
  var targets = [].slice.call(document.querySelectorAll('.section-head, .stat, .promise, .person, .dl-card, .faq-list details, .feature, .step, .care-step, .academic'));
  if (reduced || !canObserve) { return init(); }
  targets.forEach(function (el) {
    el.classList.add('reveal');
    var sibs = el.parentElement ? [].slice.call(el.parentElement.children) : [];
    var i = Math.max(0, sibs.indexOf(el));
    el.style.transitionDelay = Math.min(i, 6) * 55 + 'ms';
  });
  var ro = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('is-in'); ro.unobserve(e.target); }
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  targets.forEach(function (el) { ro.observe(el); });
  init();

  function init() {
    // ---- survey numbers count up once
    var nums = [].slice.call(document.querySelectorAll('.stat .num'));
    if (!reduced && canObserve) {
      var co = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting) return;
          co.unobserve(e.target);
          var el = e.target, txt = el.textContent, m = txt.match(/^([\d.]+)(.*)$/);
          if (!m) return;
          var end = parseFloat(m[1]), dec = (m[1].split('.')[1] || '').length, suffix = m[2], t0 = null;
          function step(t) {
            if (t0 === null) t0 = t;
            var p = Math.min(1, (t - t0) / 1100), eased = 1 - Math.pow(1 - p, 3);
            el.textContent = (end * eased).toFixed(dec) + suffix;
            if (p < 1) requestAnimationFrame(step); else el.textContent = txt;
          }
          requestAnimationFrame(step);
        });
      }, { threshold: 0.6 });
      nums.forEach(function (n) { co.observe(n); });
    }

    // ---- "daily care" story: the phone changes as each step scrolls past the middle of the screen
    var steps = [].slice.call(document.querySelectorAll('.care-step'));
    var panels = [].slice.call(document.querySelectorAll('.care-panel'));
    var dots = [].slice.call(document.querySelectorAll('.care-dots span'));
    if (!steps.length || !canObserve) { if (panels[0]) panels[0].classList.add('is-on'); return; }
    function show(i) {
      steps.forEach(function (s, k) { s.classList.toggle('is-active', k === i); });
      panels.forEach(function (p, k) { p.classList.toggle('is-on', k === i); });
      dots.forEach(function (d, k) { d.classList.toggle('is-on', k === i); });
    }
    show(0);
    // The step whose middle is nearest the middle of the screen is the active one.
    var current = -1, queued = false;
    function pick() {
      queued = false;
      var mid = window.innerHeight / 2, best = 0, bestGap = Infinity;
      steps.forEach(function (s, k) {
        var r = s.getBoundingClientRect();
        if (r.bottom < 0 || r.top > window.innerHeight) return;
        var gap = Math.abs((r.top + r.bottom) / 2 - mid);
        if (gap < bestGap) { bestGap = gap; best = k; }
      });
      if (best !== current) { current = best; show(best); }
    }
    window.addEventListener('scroll', function () { if (!queued) { queued = true; requestAnimationFrame(pick); } }, { passive: true });
    window.addEventListener('resize', pick);
    pick();
  }
})();
