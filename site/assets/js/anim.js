/* MedVerse: plays the Lottie animations only while they are on screen.
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
        a.addEventListener('DOMLoaded', function () { a.goToAndStop(loop ? Math.floor(a.totalFrames * 0.6) : Math.max(0, a.totalFrames - 1), true); });
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
