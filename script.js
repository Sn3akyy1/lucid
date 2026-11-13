/* Lucid's site. Each piece here is a port of something the shell does: the bar's clock
   and workspaces, ThemePage's palettes, the icons' tones, the Poster clock, the wavy
   progress ring, Jelly motion, Lens' viewer, Settings' search and its rail. */
(function () {
  "use strict";

  var doc = document.documentElement;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  window.__lucidReveal = true;

  /* ------------------------------------------------------------ palettes */

  var PALETTES = [
    { id: "lucid", name: "Lucid", dark: ["#050a0b", "#80d4dc", "#181e1e"], light: ["#e6eced", "#006970", "#ceddde"] },
    { id: "catppuccin-mocha", name: "Catppuccin", dark: ["#11111b", "#89b4fa", "#1e1e2e"], light: ["#ecf1ff", "#475f86", "#d1d7ec"] },
    { id: "gruvbox", name: "Gruvbox", dark: ["#1d2021", "#83a598", "#32302f"], light: ["#fff0ca", "#4d635b", "#e6d6ae"] },
    { id: "nightfox", name: "Nightfox", dark: ["#131a24", "#719cd6", "#29394f"], light: ["#f0f1f2", "#446085", "#d6d7d8"] },
    { id: "nord", name: "Nord", dark: ["#1b2027", "#88c0d0", "#3b4252"], light: ["#f5f8fd", "#44636c", "#dbdee3"] },
    { id: "tokyo-night", name: "Tokyo Night", dark: ["#16161e", "#7aa2f7", "#1e202e"], light: ["#edf0ff", "#455e91", "#d1d6ec"] }
  ];

  function store(k, v) {
    try { localStorage.setItem(k, v); } catch (e) {}
  }

  function load(k) {
    try { return localStorage.getItem(k); } catch (e) { return null; }
  }

  function isLight() {
    var t = doc.getAttribute("data-theme");
    if (t) return t === "light";
    return matchMedia("(prefers-color-scheme: light)").matches;
  }

  function currentPalette() {
    return doc.getAttribute("data-palette") || "lucid";
  }

  // a change of palette or mode redraws the page in a circle from where you clicked,
  // and never waits on a frame that may not come
  function transition(update, x, y) {
    if (reduce || !document.startViewTransition) {
      update();
      return;
    }
    var done = false;
    var guarded = function () {
      if (!done) {
        done = true;
        update();
      }
    };
    doc.classList.add("vt-swap");
    var vt = document.startViewTransition(guarded);
    var watchdog = setTimeout(function () {
      try { vt.skipTransition(); } catch (e) {}
      guarded();
    }, 400);
    vt.ready.then(function () {
      var r = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
      doc.animate({ clipPath: ["circle(0 at " + x + "px " + y + "px)", "circle(" + r + "px at " + x + "px " + y + "px)"] },
        { duration: 560, easing: "cubic-bezier(0.05, 0.7, 0.1, 1)", pseudoElement: "::view-transition-new(root)" });
    }).catch(function () {});
    vt.finished.finally(function () {
      clearTimeout(watchdog);
      doc.classList.remove("vt-swap");
    });
  }

  function setPalette(id, ev) {
    store("lucid-palette", id);
    transition(function () {
      if (id === "lucid") doc.removeAttribute("data-palette");
      else doc.setAttribute("data-palette", id);
      repaint();
    }, ev ? ev.clientX : innerWidth / 2, ev ? ev.clientY : 0);
  }

  function setTheme(t, ev) {
    store("lucid-theme", t);
    transition(function () {
      doc.setAttribute("data-theme", t);
      repaint();
    }, ev ? ev.clientX : innerWidth / 2, ev ? ev.clientY : 0);
  }

  function modeIcon(name) {
    return '<svg class="i" aria-hidden="true"><use href="#i-' + name + '"></use></svg>';
  }

  function drawPalettes() {
    var light = isLight();
    $$("[data-palettes]").forEach(function (box) {
      box.textContent = "";
      PALETTES.forEach(function (p) {
        var c = light ? p.light : p.dark;
        var b = document.createElement("button");
        b.type = "button";
        b.className = "pal" + (p.id === currentPalette() ? " on" : "");
        b.setAttribute("aria-pressed", p.id === currentPalette());
        b.innerHTML = '<span class="sw" style="background:' + c[0] + '"><b style="background:' + c[2] + '"></b><i style="background:' + c[1] + '"></i></span>' + p.name;
        b.addEventListener("click", function (ev) { setPalette(p.id, ev); });
        box.appendChild(b);
      });
    });
    $$("[data-set-theme]").forEach(function (b) {
      b.classList.toggle("on", (b.getAttribute("data-set-theme") === "light") === light);
    });
    var mode = $("[data-mode]");
    if (mode) {
      mode.innerHTML = modeIcon(light ? "dark_mode" : "light_mode");
      mode.setAttribute("aria-label", light ? "Dark mode" : "Light mode");
    }
  }

  /* ------------------------------------------------- icon tones (LucidIcons.tone) */

  function hex(c) {
    c = (c || "").trim();
    if (c[0] === "#") {
      if (c.length === 4) c = "#" + c[1] + c[1] + c[2] + c[2] + c[3] + c[3];
      return [parseInt(c.slice(1, 3), 16) / 255, parseInt(c.slice(3, 5), 16) / 255, parseInt(c.slice(5, 7), 16) / 255];
    }
    var m = c.match(/[\d.]+/g) || [0, 0, 0];
    return [m[0] / 255, m[1] / 255, m[2] / 255];
  }

  function toHex(c) {
    return "#" + c.map(function (x) { return ("0" + Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16)).slice(-2); }).join("");
  }

  var lin = function (c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
  var gam = function (c) { var v = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055; return Math.max(0, Math.min(1, v)); };
  var lum = function (c) { return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]); };
  var yAt = function (t) { return t <= 8 ? t / 903.2963 : Math.pow((t + 16) / 116, 3); };
  var toneOf = function (c) { var y = lum(c); return y <= 0.008856 ? 903.2963 * y : 116 * Math.cbrt(y) - 16; };

  function atTone(c, t) {
    var target = yAt(Math.max(0, Math.min(100, t))), y = lum(c);
    if (y <= 0) { var g = gam(target); return [g, g, g]; }
    var k = target / y, r = lin(c[0]) * k, gg = lin(c[1]) * k, b = lin(c[2]) * k;
    var peak = Math.max(r, gg, b);
    if (peak > 1) {
      r /= peak; gg /= peak; b /= peak;
      var yb = 0.2126 * r + 0.7152 * gg + 0.0722 * b;
      var w = yb >= 1 ? 0 : Math.max(0, Math.min(1, (target - yb) / (1 - yb)));
      r += (1 - r) * w; gg += (1 - gg) * w; b += (1 - b) * w;
    }
    return [gam(r), gam(gg), gam(b)];
  }

  function repaint() {
    var cs = getComputedStyle(doc);
    var v = function (n) { return hex(cs.getPropertyValue(n) || "#000"); };
    var bases = { primary: v("--accent"), error: v("--error"), neutral: v("--text"), container: v("--s2") };
    var raised = !isLight() ? v("--s3") : null;
    var keys = (document.body.getAttribute("data-tones") || "").split(",").filter(Boolean);
    keys.forEach(function (key) {
      var i = key.lastIndexOf("-"), fam = key.slice(0, i), t = Number(key.slice(i + 1)), out;
      if (fam === "container" && raised) out = t === 25 ? raised : atTone(raised, Math.max(0, toneOf(raised) + t - 25));
      else out = atTone(bases[fam] || bases.neutral, t);
      doc.style.setProperty("--t-" + key, toHex(out));
    });
    drawPalettes();
    drawRoles();
  }

  /* ------------------------------------------------------- Jelly (Jelly.qml) */

  // a damped spring on scale: positive stretch is taller and narrower, the way the
  // shell's Jelly transform wobbles a panel or an icon as it lands. one per element;
  // a second kick only ever adds up to the bigger of the two
  var JELLY_W = 2 * Math.PI * 2.4, JELLY_Z = 0.2;
  var jellies = new Map();

  function jelly(el, amp, spread) {
    if (!el || reduce) return;
    var j = jellies.get(el);
    if (!j) {
      var r = el.getBoundingClientRect();
      j = { s: 0, v: 0, spread: spread !== undefined ? spread : Math.max(0.2, Math.min(0.8, 2 * r.height / Math.max(1, r.width))), last: 0 };
      jellies.set(el, j);
    }
    j.v = Math.max(j.v, amp * JELLY_W);
    if (!j.running) {
      j.running = true;
      j.last = performance.now();
      requestAnimationFrame(function step(now) {
        var dt = Math.min(0.05, (now - j.last) / 1000);
        j.last = now;
        for (var n = 0; n < 4; n++) {
          var h = dt / 4;
          j.v += (-JELLY_W * JELLY_W * j.s - 2 * JELLY_Z * JELLY_W * j.v) * h;
          j.s += j.v * h;
        }
        if (Math.abs(j.s) < 0.0004 && Math.abs(j.v) < 0.004) {
          el.style.transform = "";
          j.running = false;
          jellies.delete(el);
          return;
        }
        el.style.transform = "scale(" + (1 - j.s * j.spread).toFixed(4) + "," + (1 + j.s).toFixed(4) + ")";
        requestAnimationFrame(step);
      });
    }
  }

  /* -------------------------------------------------------------- the bar */

  // the page's underline, gliding over from the page you came from
  function under(on) {
    var label = on.querySelector(".ws-label") || on;
    return { x: on.offsetLeft + label.offsetLeft, w: label.offsetWidth };
  }

  function placePill(animate) {
    var pill = $(".ws-pill"), on = $(".ws.on"), box = $(".workspaces");
    if (!pill || !on || !box || !box.offsetParent) return;
    var u = under(on), x = u.x, w = u.w;
    if (animate) {
      var from = null;
      try { from = JSON.parse(sessionStorage.getItem("lucid-ws") || "null"); } catch (e) {}
      if (from && !reduce && (from.x !== x || from.w !== w)) {
        pill.style.translate = from.x + "px 0";
        pill.style.width = from.w + "px";
        pill.classList.add("ready");
        pill.getBoundingClientRect();
        pill.classList.add("glide");
        setTimeout(function () { jelly(pill, 0.12, 0.15); }, 260);
      }
    }
    pill.style.translate = x + "px 0";
    pill.style.width = w + "px";
    pill.classList.add("ready");
  }

  addEventListener("pagehide", function () {
    var on = $(".ws.on");
    if (on) try { sessionStorage.setItem("lucid-ws", JSON.stringify(under(on))); } catch (e) {}
  });

  function panels() {
    var openOne = null;
    function close() {
      if (!openOne) return;
      openOne.panel.hidden = true;
      openOne.btn.setAttribute("aria-expanded", "false");
      openOne = null;
    }
    function bind(btn, panel) {
      btn.addEventListener("click", function (e) {
        e.stopPropagation();
        var was = openOne && openOne.panel === panel;
        close();
        if (!was) {
          panel.hidden = false;
          btn.setAttribute("aria-expanded", "true");
          openOne = { btn: btn, panel: panel };
          setTimeout(function () { jelly(panel, 0.045); }, 170);
        }
      });
      panel.addEventListener("click", function (e) { e.stopPropagation(); });
    }
    var pb = $("[data-panel=palette]"), pp = $("#palette-panel");
    if (pb && pp) bind(pb, pp);
    var mb = $(".menu-btn"), sh = $("#sheet");
    if (mb && sh) bind(mb, sh);
    document.addEventListener("click", close);
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") close(); });
    $$("[data-set-theme]").forEach(function (b) {
      b.addEventListener("click", function (ev) { setTheme(b.getAttribute("data-set-theme"), ev); });
    });
    var mode = $("[data-mode]");
    if (mode) mode.addEventListener("click", function (ev) { setTheme(isLight() ? "dark" : "light", ev); });
  }

  // the stars, asked of GitHub once an hour at most
  function github() {
    var cached = null;
    try { cached = JSON.parse(load("lucid-gh") || "null"); } catch (e) {}
    var show = function (d) {
      $$("[data-stars]").forEach(function (e) { e.textContent = d.stars; });
      $$("[data-forks]").forEach(function (e) { e.textContent = d.forks; });
    };
    if (cached) show(cached);
    if (cached && Date.now() - cached.at < 3600e3) return;
    if (!window.fetch || location.protocol === "file:") return;
    fetch("https://api.github.com/repos/Sn3akyy1/lucid").then(function (r) { return r.ok ? r.json() : null; }).then(function (j) {
      if (!j) return;
      var d = { stars: j.stargazers_count, forks: j.forks_count, at: Date.now() };
      store("lucid-gh", JSON.stringify(d));
      show(d);
    }).catch(function () {});
  }

  /* --------------------------------------------------------- the headline */

  // the part of Lucid the headline is about right now: the word springs up from
  // below, the pill springs to its width, the old word lifts away
  function cycle() {
    var box = $("[data-cycle]");
    if (!box) return;
    var words = box.getAttribute("data-cycle").split("|");
    var cur = box.querySelector(".ht-word");
    var measure = document.createElement("span");
    measure.className = "ht-word";
    measure.style.cssText = "position:absolute;visibility:hidden;pointer-events:none";
    box.appendChild(measure);
    var pad = function () {
      var cs = getComputedStyle(box);
      return parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight);
    };
    var widthOf = function (w) {
      measure.textContent = w;
      return Math.ceil(measure.getBoundingClientRect().width + pad());
    };
    var at = words.length - 1;
    box.style.width = widthOf(words[at]) + "px";
    // measured again once the real font is in, or the fallback's width sticks
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () { box.style.width = widthOf(words[at]) + "px"; });
    }
    if (reduce) return;
    var tilt = 1;
    var visible = true;
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; }).observe(box);
    }
    function next() {
      var hold = at === words.length - 1 ? 3400 : 1500;
      setTimeout(function () {
        if (!visible || document.hidden) {
          next();
          return;
        }
        at = (at + 1) % words.length;
        var old = cur;
        old.classList.remove("in");
        old.classList.add("out");
        setTimeout(function () { old.remove(); }, 260);
        cur = document.createElement("span");
        cur.className = "ht-word in";
        tilt = -tilt;
        cur.style.setProperty("--tilt", tilt * 7 + "deg");
        cur.textContent = words[at];
        box.insertBefore(cur, measure);
        box.style.width = widthOf(words[at]) + "px";
        setTimeout(function () { jelly(box, 0.05, 0.3); }, 260);
        next();
      }, hold);
    }
    next();
    addEventListener("resize", function () { box.style.width = widthOf(words[at]) + "px"; });
  }

  // a heading's words, each in a span of its own, so they can tip in one by one
  function splitWords() {
    $$("[data-words], .band-head h2, .page-head h1, .mark-show h2, .lost h1").forEach(function (el) {
      if (el.querySelector("*")) return;
      var words = el.textContent.trim().split(/\s+/);
      el.textContent = "";
      el.classList.add("split");
      words.forEach(function (w, i) {
        var s = document.createElement("span");
        s.className = "wd";
        s.style.setProperty("--i", i);
        s.style.setProperty("--tilt", (i % 2 ? -1 : 1) * (3 + (i * 7) % 5) + "deg");
        s.textContent = w;
        el.appendChild(s);
        if (i < words.length - 1) el.appendChild(document.createTextNode(" "));
      });
    });
  }

  /* ---------------------------------------------------- the hero's widgets */

  var ringFrac = 0, ringPhase = 0, ringOn = false;

  function roll(el) {
    if (reduce) return;
    el.classList.remove("roll");
    void el.offsetWidth;
    el.classList.add("roll");
  }

  function setText(sel, val) {
    $$(sel).forEach(function (e) {
      if (e.textContent !== String(val)) {
        var first = !e.hasAttribute("data-set");
        e.textContent = val;
        e.setAttribute("data-set", "");
        if (!first) roll(e);
      }
    });
  }

  function widgets() {
    var d = new Date();
    var opts = Intl.DateTimeFormat(undefined, { hour: "numeric" }).resolvedOptions();
    var h24 = opts.hourCycle ? opts.hourCycle === "h23" || opts.hourCycle === "h24" : !/AM|PM/i.test(d.toLocaleTimeString());
    var h = d.getHours();
    if (!h24) h = h % 12 || 12;
    setText("[data-poster-h]", (h24 && h < 10 ? "0" : "") + h);
    setText("[data-poster-m]", ("0" + d.getMinutes()).slice(-2));
    setText("[data-poster-date]", d.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" }));
    setText("[data-today-day]", d.toLocaleDateString(undefined, { weekday: "long" }));
    setText("[data-today-num]", d.getDate());
    setText("[data-today-month]", d.toLocaleDateString(undefined, { month: "long" }));
    var start = new Date(d);
    start.setHours(0, 0, 0, 0);
    var frac = (d - start) / 864e5;
    setText("[data-day-pct]", Math.floor(frac * 100) + "%");
    var left = Math.round((1 - frac) * 1440);
    setText("[data-day-left]", Math.floor(left / 60) + " h " + (left % 60) + " min left");
    ringFrac = frac;
  }

  // the wavy ring: only the done part waves, and the wave travels while it is on screen
  function drawRing(grow) {
    var p = $("[data-wave]");
    if (!p) return;
    var f = ringFrac * (grow === undefined ? 1 : grow);
    var cx = 60, cy = 60, r = 48, amp = 2.6, waves = 12, steps = Math.max(2, Math.round(160 * f));
    var a0 = -Math.PI / 2, span = f * Math.PI * 2, d = "";
    for (var i = 0; i <= steps; i++) {
      var t = i / steps, a = a0 + span * t;
      // the wave fades out at the ends, so they stay round
      var ease = Math.min(1, t * 8, (1 - t) * 8);
      var rr = r + amp * ease * Math.sin(a * waves + ringPhase);
      d += (i ? "L" : "M") + (cx + rr * Math.cos(a)).toFixed(2) + " " + (cy + rr * Math.sin(a)).toFixed(2);
    }
    p.setAttribute("d", d);
  }

  var ringGrow = 0;

  function ringLoop() {
    if (!ringOn) return;
    ringPhase -= 0.035;
    // it fills to where the day is the first time it comes on screen
    if (ringGrow < 1) ringGrow = Math.min(1, ringGrow + 0.022);
    drawRing(1 - Math.pow(1 - ringGrow, 3));
    requestAnimationFrame(ringLoop);
  }

  /* --------------------------------------------- shapes (lucidui/Shapes.js) */

  function shapePath(r, size) {
    var N = r.length, c = size / 2, pts = [];
    for (var i = 0; i < N; i++) {
      var th = i / N * 2 * Math.PI;
      pts.push([c + c * r[i] * Math.cos(th), c + c * r[i] * Math.sin(th)]);
    }
    var d = "M" + pts[0][0].toFixed(2) + " " + pts[0][1].toFixed(2);
    for (var j = 0; j < N; j++) {
      var p0 = pts[(j - 1 + N) % N], p1 = pts[j], p2 = pts[(j + 1) % N], p3 = pts[(j + 2) % N];
      d += "C" + (p1[0] + (p2[0] - p0[0]) / 6).toFixed(2) + " " + (p1[1] + (p2[1] - p0[1]) / 6).toFixed(2) + " " +
        (p2[0] - (p3[0] - p1[0]) / 6).toFixed(2) + " " + (p2[1] - (p3[1] - p1[1]) / 6).toFixed(2) + " " +
        p2[0].toFixed(2) + " " + p2[1].toFixed(2);
    }
    return d + "Z";
  }

  function half(r) {
    return r.filter(function (_, i) { return i % 2 === 0; });
  }

  // a shape morphs to another and back, the way the session screen's shapes do
  function morph(svg, from, to, ms) {
    var S = window.LUCID_SHAPES;
    if (!S || !S[from] || reduce) return;
    var a = half(S[from]), b = half(S[to] || S.circle);
    var path = svg.querySelector("path.live");
    if (!path) {
      path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("class", "live");
      svg.textContent = "";
      svg.appendChild(path);
    }
    var t0 = performance.now();
    // there and back: out fast, a little past, home
    function step(now) {
      var t = Math.min(1, (now - t0) / ms);
      var k = Math.sin(Math.PI * t) * (1 + 0.15 * Math.sin(Math.PI * 2 * t));
      var r = a.map(function (x, i) { return x + (b[i] - x) * k; });
      path.setAttribute("d", shapePath(r, 100));
      if (t < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  /* ---------------------------------------------------------------- sounds */

  var ext = (function () {
    var a = document.createElement("audio");
    return a.canPlayType && a.canPlayType('audio/ogg; codecs="vorbis"') ? "ogg" : "m4a";
  })();

  function pads() {
    $$("[data-sound]").forEach(function (pad) {
      pad.addEventListener("click", function () {
        var a = new Audio("assets/sounds/" + pad.getAttribute("data-sound") + "." + ext);
        a.volume = 0.7;
        pad.classList.add("playing");
        a.play().catch(function () {});
        var stop = function () { pad.classList.remove("playing"); };
        a.addEventListener("ended", stop);
        setTimeout(stop, 2600);
        var svg = pad.querySelector(".pad-shape");
        if (svg) morph(svg, pad.getAttribute("data-shape"), "circle", 620);
        jelly(pad, 0.12, 0.6);
        if (!reduce) {
          var ring = document.createElement("span");
          ring.className = "ring";
          pad.appendChild(ring);
          setTimeout(function () { ring.remove(); }, 950);
        }
      });
    });
  }

  /* ----------------------------------------------------------------- roles */

  var ROLES = [
    ["Primary", "--accent"], ["On primary", "--on-accent"], ["Primary container", "--accent-c"],
    ["Secondary", "--secondary"], ["Tertiary", "--tertiary"], ["Error", "--error"],
    ["Surface", "--s1"], ["Surface high", "--s3"], ["On surface", "--text"], ["Outline", "--line-2"]
  ];

  function drawRoles() {
    var box = $("[data-roles]");
    if (!box) return;
    var cs = getComputedStyle(doc);
    box.textContent = "";
    ROLES.forEach(function (r) {
      var val = toHex(hex(cs.getPropertyValue(r[1]) || "#000")).toUpperCase();
      var b = document.createElement("button");
      b.type = "button";
      b.className = "role";
      b.innerHTML = '<i style="background:' + val + '"></i><span>' + r[0] + "</span><code>" + val + "</code>";
      b.addEventListener("click", function () {
        copy(val);
        var c = b.querySelector("code");
        c.textContent = "Copied " + val;
        b.classList.add("copied");
        jelly(b.querySelector("i"), 0.12, 0.8);
        setTimeout(function () { c.textContent = val; b.classList.remove("copied"); }, 1400);
      });
      box.appendChild(b);
    });
  }

  /* ------------------------------------------------------------------ copy */

  function copy(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) return navigator.clipboard.writeText(text).catch(function () {});
    var t = document.createElement("textarea");
    t.value = text;
    document.body.appendChild(t);
    t.select();
    try { document.execCommand("copy"); } catch (e) {}
    t.remove();
  }

  function copies() {
    $$(".copy").forEach(function (b) {
      b.addEventListener("click", function () {
        var text = b.getAttribute("data-copy");
        if (!text) {
          var code = b.parentElement.querySelector("code");
          text = code ? code.textContent : "";
        }
        copy(text);
        b.classList.add("done");
        jelly(b, 0.12, 0.6);
        setTimeout(function () { b.classList.remove("done"); }, 1400);
      });
    });
  }

  /* --------------------------------------------- springs on what you touch */

  function touches() {
    // buttons jelly as they let go, the dock's icons as the pointer reaches them,
    // as lucidui's Button and the dock's DockItem do
    $$(".btn, .sys, .icon-btn, .seg button").forEach(function (b) {
      b.addEventListener("click", function () { jelly(b, 0.06); });
    });
    $$(".dock-item").forEach(function (d) {
      d.addEventListener("mouseenter", function () { jelly(d, 0.07, 0.5); });
    });
    $$(".tile, .w.github").forEach(function (t) {
      t.addEventListener("pointerdown", function () { jelly(t, 0.03); });
    });
  }

  /* ---------------------------------------------------- the viewer (Lens) */

  function viewer() {
    var dlg = $("[data-viewer]"), tiles = $$("[data-gallery] .tile");
    if (!dlg || !tiles.length) return;
    var img = $("[data-viewer-img]", dlg), title = $("[data-viewer-title]", dlg), count = $("[data-viewer-count]", dlg);
    var strip = $("[data-filmstrip]", dlg), at = 0;
    tiles.forEach(function (t, i) {
      var b = document.createElement("button");
      b.type = "button";
      b.setAttribute("aria-label", t.getAttribute("data-title"));
      b.innerHTML = '<img src="' + t.querySelector("img").getAttribute("src") + '" alt="">';
      b.addEventListener("click", function () { show(i, 0); });
      strip.appendChild(b);
      t.addEventListener("click", function () { open(i); });
    });

    // the picture slides in from the side it comes from, as Lens' stage does
    function show(i, dir) {
      at = (i + tiles.length) % tiles.length;
      var t = tiles[at];
      var thumb = t.querySelector("img").getAttribute("src");
      img.src = thumb;
      var full = new Image();
      full.onload = function () { if (tiles[at] === t) img.src = full.src; };
      full.src = t.getAttribute("data-src");
      img.alt = t.querySelector("img").alt;
      title.textContent = t.getAttribute("data-title");
      count.textContent = at + 1 + " of " + tiles.length;
      $$("button", strip).forEach(function (b, k) { b.classList.toggle("on", k === at); });
      var on = strip.children[at];
      if (on && on.scrollIntoView) on.scrollIntoView({ block: "nearest", inline: "center", behavior: reduce ? "auto" : "smooth" });
      if (dir && !reduce && img.animate) {
        img.animate([{ transform: "translateX(" + dir * 60 + "px) scale(0.96)", opacity: 0.2 }, { transform: "none", opacity: 1 }],
          { duration: 460, easing: getComputedStyle(doc).getPropertyValue("--spring").trim() || "ease-out" });
      }
    }

    // it opens out of the picture you clicked, and closes back into it
    function flip(from, to, back) {
      var a = from.getBoundingClientRect(), b = to.getBoundingClientRect();
      if (!a.width || !b.width || !img.animate) return null;
      var s = a.width / b.width;
      var tx = a.left + a.width / 2 - (b.left + b.width / 2), ty = a.top + a.height / 2 - (b.top + b.height / 2);
      var frames = [{ transform: "translate(" + tx + "px," + ty + "px) scale(" + s + ")", borderRadius: "40px" }, { transform: "none", borderRadius: "12px" }];
      return img.animate(back ? frames.reverse() : frames,
        { duration: back ? 300 : 520, easing: back ? "cubic-bezier(0.3, 0, 0.8, 0.15)" : getComputedStyle(doc).getPropertyValue("--spring").trim(), fill: "both" });
    }

    function open(i) {
      show(i, 0);
      dlg.showModal();
      if (reduce) return;
      var a = flip(tiles[i].querySelector("img"), img, false);
      if (a) a.onfinish = function () { a.cancel(); };
    }

    function close() {
      var t = tiles[at];
      var a = reduce ? null : flip(t.querySelector("img"), img, true);
      if (!a) {
        dlg.close();
        return;
      }
      // shut once it has shrunk back, or on time if the animation never reports in
      var shut = false;
      var finish = function () {
        if (shut) return;
        shut = true;
        dlg.close();
        a.cancel();
        jelly(t, 0.04);
      };
      a.onfinish = finish;
      setTimeout(finish, 360);
    }

    $("[data-viewer-prev]", dlg).addEventListener("click", function () { show(at - 1, -1); });
    $("[data-viewer-next]", dlg).addEventListener("click", function () { show(at + 1, 1); });
    $("[data-viewer-close]", dlg).addEventListener("click", close);
    dlg.addEventListener("cancel", function (e) {
      e.preventDefault();
      close();
    });
    dlg.addEventListener("keydown", function (e) {
      if (e.key === "ArrowLeft") show(at - 1, -1);
      if (e.key === "ArrowRight") show(at + 1, 1);
    });
    dlg.addEventListener("click", function (e) { if (e.target === dlg) close(); });
  }

  /* --------------------------------------------- the docs, as Settings lays out */

  function docs() {
    var rail = $("[data-rail-nav]");
    if (!rail) return;
    var links = $$("a", rail), pill = $(".rail-pill", rail);
    var targets = links.map(function (a) { return document.getElementById(a.getAttribute("href").slice(1)); });
    var cur = -1, locked = false, unlock = 0, lockCap = 0;

    function setOn(i) {
      if (i === cur) return;
      var first = cur < 0;
      cur = i;
      links.forEach(function (a, k) { a.classList.toggle("on", k === i); });
      if (pill && links[i]) {
        if (!first) pill.classList.add("glide");
        pill.style.translate = "0 " + links[i].offsetTop + "px";
        pill.style.height = links[i].offsetHeight + "px";
        pill.style.opacity = links[i].offsetParent ? 1 : 0;
        if (!first) setTimeout(function () { jelly(pill, 0.05, 0.2); }, 200);
      }
      // the rail keeps the lit row in sight when it scrolls itself
      var r = $("[data-rail]");
      if (r && links[i] && r.scrollHeight > r.clientHeight) {
        var top = links[i].offsetTop + rail.offsetTop;
        if (top < r.scrollTop || top > r.scrollTop + r.clientHeight - 60) r.scrollTop = top - 80;
      }
    }

    // the section whose top has passed under the bar is the one you are in;
    // at the foot of the page it is the last one, which can never reach the top
    function mark() {
      if (locked) return;
      var y = 150, best = 0;
      targets.forEach(function (t, i) {
        if (t && t.offsetParent !== null && t.getBoundingClientRect().top <= y) best = i;
      });
      if (innerHeight + scrollY >= document.documentElement.scrollHeight - 4) {
        for (var k = targets.length - 1; k >= 0; k--) {
          if (targets[k] && targets[k].offsetParent !== null) { best = k; break; }
        }
      }
      setOn(best);
    }

    // a click lights its row at once and holds it until the page has stopped
    // scrolling there, so the pill doesn't run through every section on the way
    function release() {
      locked = false;
      clearTimeout(unlock);
      clearTimeout(lockCap);
      mark();
    }
    links.forEach(function (a, i) {
      a.addEventListener("click", function () {
        locked = true;
        setOn(i);
        clearTimeout(unlock);
        clearTimeout(lockCap);
        unlock = setTimeout(release, 250);
        lockCap = setTimeout(release, 2500);
      });
    });
    var ticking = false;
    addEventListener("scroll", function () {
      if (locked) {
        clearTimeout(unlock);
        unlock = setTimeout(release, 160);
        return;
      }
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(function () {
        ticking = false;
        mark();
      });
    }, { passive: true });
    addEventListener("resize", function () {
      var i = cur;
      cur = -1;
      setOn(Math.max(0, i));
    });
    mark();

    // search: what doesn't match folds away, part by part, the way Settings filters
    var input = $("[data-doc-search]"), empty = $("[data-doc-empty]");
    var secs = $$("[data-sec]");
    var chunks = secs.map(function (sec) {
      var out = [], cur = null;
      Array.prototype.slice.call(sec.children).forEach(function (el) {
        if (el.tagName === "H2") return;
        if (/^H[45]$/.test(el.tagName) || el.classList.contains("qa") || !cur) {
          cur = { els: [], text: "" };
          out.push(cur);
        }
        cur.els.push(el);
        cur.text += " " + el.textContent.toLowerCase();
        if (el.classList.contains("qa")) cur = null;
      });
      return out;
    });
    function filter() {
      var q = input.value.trim().toLowerCase();
      var words = q.split(/\s+/).filter(Boolean), any = false;
      secs.forEach(function (sec, i) {
        var hit = false;
        chunks[i].forEach(function (c) {
          var ok = !words.length || words.every(function (w) { return c.text.indexOf(w) >= 0; });
          c.els.forEach(function (el) {
            el.hidden = !ok;
            if (ok && words.length && el.tagName === "DETAILS") el.open = true;
          });
          if (ok) hit = true;
        });
        sec.hidden = !hit;
        if (hit) any = true;
      });
      empty.hidden = any;
      links.forEach(function (a, i) { a.style.opacity = targets[i] && targets[i].offsetParent === null ? 0.45 : ""; });
      cur = -1;
      mark();
    }
    input.addEventListener("input", filter);
    document.addEventListener("keydown", function (e) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "f") {
        e.preventDefault();
        input.focus();
      }
    });
  }

  /* --------------------------------------------------------- the report */

  function report() {
    var form = $("[data-report]");
    if (!form) return;
    var kind = "bug";
    $$("[data-kind]", form).forEach(function (b) {
      b.addEventListener("click", function () {
        kind = b.getAttribute("data-kind");
        $$("[data-kind]", form).forEach(function (o) { o.classList.toggle("on", o === b); });
        $("[data-bug-only]", form).hidden = kind !== "bug";
        $("[data-l-what]", form).textContent = kind === "bug" ? "What happened" : "What you would like";
      });
    });
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var f = form.elements, body = [];
      if (kind === "bug") {
        body.push("### What happened\n\n" + f.what.value.trim());
        if (f.steps.value.trim()) body.push("### How to make it happen\n\n" + f.steps.value.trim());
        body.push("### Setup\n\n- Lucid: " + (f.version.value.trim() || "?") + "\n- Hyprland: " + (f.hypr.value.trim() || "?") + "\n- Graphics: " + (f.gpu.value || "?"));
        if (f.log.value.trim()) body.push("### `qs log`\n\n```\n" + f.log.value.trim() + "\n```");
      } else {
        body.push("### The idea\n\n" + f.what.value.trim());
      }
      var url = "https://github.com/Sn3akyy1/lucid/issues/new?labels=" + (kind === "bug" ? "bug" : "enhancement") +
        "&title=" + encodeURIComponent(f.title.value.trim()) + "&body=" + encodeURIComponent(body.join("\n\n"));
      window.open(url, "_blank", "noopener");
    });
  }

  /* ------------------------------------------------- reveal, stagger, settle */

  var GROUPS = ".gallery, .pair, .people, .credits, .timeline, .stats, .eco-col, .pads, .help-cards, .releases";

  function countUp(el) {
    var target = parseInt(el.textContent, 10);
    if (!(target > 0) || reduce) return;
    var t0 = performance.now(), ms = 900;
    (function step(now) {
      var t = Math.min(1, (now - t0) / ms);
      el.textContent = Math.round(target * (1 - Math.pow(1 - t, 3)));
      if (t < 1) requestAnimationFrame(step);
      else el.textContent = target;
    })(t0);
  }

  function rise() {
    var els = $$("[data-rise]");
    // siblings come in one after another
    els.forEach(function (el) {
      var sibs = Array.prototype.slice.call(el.parentElement.children).filter(function (c) { return c.hasAttribute("data-rise"); });
      el.style.setProperty("--d", sibs.indexOf(el) * 70 + "ms");
      var groups = (el.matches(GROUPS) ? [el] : []).concat($$(GROUPS, el));
      groups.forEach(function (g) {
        g.classList.add("stagger");
        Array.prototype.slice.call(g.children).forEach(function (c, i) { c.style.setProperty("--i", Math.min(i, 14)); });
      });
    });
    if (!("IntersectionObserver" in window) || !doc.classList.contains("reveal")) {
      els.forEach(function (e) { e.classList.add("in", "done"); });
      $$(".stagger").forEach(function (g) { g.classList.add("done"); });
      return;
    }
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (en) {
        if (!en.isIntersecting) return;
        var el = en.target;
        el.classList.add("in");
        io.unobserve(el);
        $$("[data-count], .poster-num, .gh-num", el).forEach(countUp);
        if (el.classList.contains("w")) {
          var d = parseFloat(el.style.getPropertyValue("--d")) || 0;
          setTimeout(function () { jelly(el, 0.06); }, d + 260);
        }
        // the delays only shape the entrance; hovers answer at once after it
        setTimeout(function () {
          el.classList.add("done");
          $$(".stagger", el).concat(el.classList.contains("stagger") ? [el] : []).forEach(function (g) { g.classList.add("done"); });
        }, 1500);
      });
    }, { rootMargin: "0px 0px -8% 0px" });
    els.forEach(function (e) { io.observe(e); });
  }

  // pictures settle into place as they come up the page
  function settle() {
    var shots = $$(".hero-shot, .feature .shot, .pair .shot, .release figure.shot");
    if (!shots.length || reduce) return;
    shots.forEach(function (s) { s.classList.add("settle"); });
    var ticking = false;
    function update() {
      ticking = false;
      var h = innerHeight;
      shots.forEach(function (s) {
        var r = s.getBoundingClientRect();
        if (r.bottom < 0 || r.top > h) return;
        // 0 as its top enters the bottom of the screen, 1 once it is a third of the way up
        var p = Math.max(0, Math.min(1, (h - r.top) / (h * 0.45)));
        s.style.setProperty("--p", p.toFixed(3));
      });
    }
    addEventListener("scroll", function () {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    }, { passive: true });
    addEventListener("resize", update);
    update();
  }

  /* --------------------------------------------------- moving between pages */

  // where the browser has no cross-page view transition, the page lifts away by hand
  function leaving() {
    if (reduce || ("onpagereveal" in window && CSS.supports && CSS.supports("view-transition-name: a"))) return;
    document.addEventListener("click", function (e) {
      var a = e.target.closest && e.target.closest("a[href]");
      if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      if (a.target && a.target !== "_self") return;
      var url = new URL(a.href, location.href);
      if (url.origin !== location.origin || url.pathname === location.pathname || !/\.html$|\/$/.test(url.pathname)) return;
      e.preventDefault();
      doc.classList.add("leaving");
      setTimeout(function () { location.href = url.href; }, 190);
    });
    addEventListener("pageshow", function (e) { if (e.persisted) doc.classList.remove("leaving"); });
  }

  /* ------------------------------------------------------------------ go */

  document.addEventListener("DOMContentLoaded", function () {
    splitWords();
    repaint();
    panels();
    placePill(true);
    widgets();
    drawRing(0);
    cycle();
    github();
    pads();
    copies();
    touches();
    viewer();
    docs();
    report();
    rise();
    settle();
    leaving();

    setInterval(function () { widgets(); if (!ringOn) drawRing(); }, 10000);
    addEventListener("resize", function () { placePill(false); });

    var ring = $(".wave-ring");
    if (ring && !reduce && "IntersectionObserver" in window) {
      new IntersectionObserver(function (es) {
        var was = ringOn;
        ringOn = es[0].isIntersecting;
        if (ringOn && !was) requestAnimationFrame(ringLoop);
      }).observe(ring);
    } else {
      drawRing();
    }

    // a changelog link to an older version opens it
    var h = location.hash.slice(1);
    var target = h && document.getElementById(h);
    if (target && target.tagName === "DETAILS") target.open = true;

    // the system's mode changing redraws the tones while the site follows it
    matchMedia("(prefers-color-scheme: light)").addEventListener("change", function () {
      if (!doc.getAttribute("data-theme")) repaint();
    });
    addEventListener("storage", function (e) {
      if (e.key === "lucid-palette") {
        if (!e.newValue || e.newValue === "lucid") doc.removeAttribute("data-palette");
        else doc.setAttribute("data-palette", e.newValue);
        repaint();
      }
      if (e.key === "lucid-theme" && e.newValue) {
        doc.setAttribute("data-theme", e.newValue);
        repaint();
      }
    });
  });
})();
