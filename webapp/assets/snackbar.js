// Lightweight toast/snackbar. Usage: window.snack('Message', 'error'|'ok'|'info', ms?)
(function () {
  var ICONS = {
    error: '<svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>',
    ok:    '<svg viewBox="0 0 24 24"><path d="M9 16.2l-3.5-3.5L4 14.2 9 19.2 20 8.2l-1.5-1.5z"/></svg>',
    info:  '<svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>',
  };
  function zone() {
    var z = document.getElementById('snackzone');
    if (!z) { z = document.createElement('div'); z.id = 'snackzone'; document.body.appendChild(z); }
    return z;
  }
  window.snack = function (msg, kind, ms) {
    kind = kind || 'info'; ms = ms || 3600;
    var el = document.createElement('div');
    el.className = 'snack ' + kind;
    el.setAttribute('role', kind === 'error' ? 'alert' : 'status');
    el.innerHTML = '<span class="ico">' + (ICONS[kind] || ICONS.info) + '</span><span class="txt"></span>';
    el.querySelector('.txt').textContent = msg;
    zone().appendChild(el);
    requestAnimationFrame(function () { el.classList.add('show'); });
    setTimeout(function () {
      el.classList.remove('show');
      setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 320);
    }, ms);
  };
})();
