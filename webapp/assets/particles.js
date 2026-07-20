// Floating particle field — the same look as the TCS splash. Drop a
// <canvas id="particles"></canvas> on the page (or let this create one) and
// include this script; it animates a drifting field of soft brand-coloured dots.
(function () {
  var canvas = document.getElementById('particles');
  if (!canvas) {
    canvas = document.createElement('canvas');
    canvas.id = 'particles';
    document.body.insertBefore(canvas, document.body.firstChild);
  }
  var ctx = canvas.getContext('2d');
  var COLORS = ['#6DD5FA', '#8E54E9', '#F7971E', '#FF5858'];
  var W = 0, H = 0, dpr = Math.min(window.devicePixelRatio || 1, 2), P = [];

  function resize() {
    W = window.innerWidth; H = window.innerHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  window.addEventListener('resize', resize);
  resize();

  for (var i = 0; i < 24; i++) {
    P.push({
      x: Math.random(), y: Math.random(),
      r: Math.random() * 4 + 2,
      speed: Math.random() * 0.3 + 0.1,
      color: COLORS[Math.floor(Math.random() * 4)],
      alpha: Math.random() * 0.5 + 0.2,
      offset: Math.random() * Math.PI * 2,
    });
  }

  var TWO_PI = Math.PI * 2, start = performance.now();
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function frame(now) {
    var progress = (((now - start) / 4000) % 1);
    ctx.clearRect(0, 0, W, H);
    for (var k = 0; k < P.length; k++) {
      var p = P[k];
      var t = (progress + p.offset / TWO_PI) % 1;
      var dy = (p.y - t * p.speed) % 1; if (dy < 0) dy += 1;
      var dx = p.x + Math.sin(t * TWO_PI + p.offset) * 0.04;
      ctx.globalAlpha = p.alpha;
      ctx.fillStyle = p.color;
      ctx.shadowColor = p.color;
      ctx.shadowBlur = 4;
      ctx.beginPath();
      ctx.arc(dx * W, dy * H, p.r, 0, TWO_PI);
      ctx.fill();
    }
    ctx.globalAlpha = 1; ctx.shadowBlur = 0;
    if (!reduce) requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
