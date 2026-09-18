/* Lucid website: appearance, navigation, copy buttons, live GitHub numbers,
 * the screenshot viewer, the Help Center search and the report builder. */
(() => {
  "use strict";

  const REPO = "Sn3akyy1/lucid";
  const root = document.documentElement;
  const $ = (sel, el = document) => el.querySelector(sel);
  const $$ = (sel, el = document) => Array.from(el.querySelectorAll(sel));

  // storage can throw in private windows or with site data blocked
  const store = {
    get(key, area = "localStorage") {
      try {
        return window[area].getItem(key);
      } catch {
        return null;
      }
    },
    set(key, value, area = "localStorage") {
      try {
        if (value == null) window[area].removeItem(key);
        else window[area].setItem(key, value);
      } catch {
        /* the page works without it */
      }
    },
  };

  // snackbar, like the shell's toasts
  let snackTimer = 0;
  function snack(text, colour) {
    $(".snackbar")?.remove();
    const el = document.createElement("div");
    el.className = "snackbar";
    el.setAttribute("role", "status");
    if (colour) {
      const dot = document.createElement("span");
      dot.className = "dot";
      dot.style.background = colour;
      el.append(dot);
    } else {
      el.insertAdjacentHTML("beforeend", '<svg class="i" aria-hidden="true"><use href="#i-check"></use></svg>');
    }
    el.append(document.createTextNode(text));
    document.body.append(el);
    clearTimeout(snackTimer);
    snackTimer = setTimeout(() => {
      el.classList.add("is-leaving");
      el.addEventListener("animationend", () => el.remove(), { once: true });
    }, 2400);
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      const ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.cssText = "position: fixed; opacity: 0; pointer-events: none";
      document.body.append(ta);
      ta.select();
      let ok = false;
      try {
        ok = document.execCommand("copy");
      } catch {
        ok = false;
      }
      ta.remove();
      return ok;
    }
  }

  /* motion helpers ---------------------------------------------------------- */

  const calm = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

  // play the element's .is-closing animation, then run `after`; a reopen cancels it
  function animateOut(el, after) {
    const token = (el._outToken = (el._outToken || 0) + 1);
    let done = false;
    const finish = () => {
      el.removeEventListener("animationend", onEnd);
      if (done || el._outToken !== token) return;
      done = true;
      el.classList.remove("is-closing");
      after();
    };
    const onEnd = (e) => {
      if (e.target === el) finish();
    };
    el.classList.add("is-closing");
    el.addEventListener("animationend", onEnd);
    setTimeout(finish, 450);
  }

  function cancelOut(el) {
    el._outToken = (el._outToken || 0) + 1;
    el.classList.remove("is-closing");
  }

  // a palette or mode change spreads from the button in a circle, like a new wallpaper
  function reshade(origin, change) {
    if (!document.startViewTransition || calm()) {
      change();
      return;
    }
    const box = origin.getBoundingClientRect();
    const x = box.left + box.width / 2;
    const y = box.top + box.height / 2;
    const r = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
    root.classList.add("theme-shift");
    const shift = document.startViewTransition(change);
    shift.ready
      .then(() =>
        root.animate(
          { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${r}px at ${x}px ${y}px)`] },
          { duration: 720, easing: "cubic-bezier(0.05, 0.7, 0.1, 1)", pseudoElement: "::view-transition-new(root)" }
        )
      )
      .catch(() => {});
    shift.finished.finally(() => root.classList.remove("theme-shift"));
  }

  /* appearance: mode and palette ------------------------------------------ */

  // a choice is saved in this browser: every page, later visits and other open tabs follow it.
  // the page head applies it before first paint; this keeps the controls and the tabs in step
  const darkQuery = matchMedia("(prefers-color-scheme: dark)");
  const mode = () => root.getAttribute("data-theme") || (darkQuery.matches ? "dark" : "light");
  const palette = () => root.getAttribute("data-palette") || "matugen";
  // the Theme page's own hint under "Light or dark"
  const hints = {
    wallpaper: "Re-derives the palette from your wallpaper in the mode you pick.",
    fixed: "Builds a light palette from this theme's own colours.",
  };

  // saving and painting are separate: a click saves at once, and the paint may wait for the
  // circle transition, which only runs on a rendered frame
  function applyMode(next) {
    root.setAttribute("data-theme", next);
    syncAppearance();
  }

  function applyPalette(next) {
    if (next === "matugen") root.removeAttribute("data-palette");
    else root.setAttribute("data-palette", next);
    syncAppearance();
  }

  // re-read what is saved, for another tab's change or a page back from the back/forward cache
  function applySaved() {
    const t = store.get("lucid-theme");
    const p = store.get("lucid-palette");
    const known = $$("button[data-palette]").map((b) => b.dataset.palette);
    if (t === "light" || t === "dark") root.setAttribute("data-theme", t);
    else root.removeAttribute("data-theme");
    if (p && p !== "matugen" && (!known.length || known.includes(p))) root.setAttribute("data-palette", p);
    else root.removeAttribute("data-palette");
    syncAppearance();
  }

  function tokenValue(name) {
    return getComputedStyle(root).getPropertyValue(name).trim().toLowerCase();
  }

  const pwTitle = $("#pw-title");
  const modeHint = $("#mode-hint");
  let copiedTimer = 0;

  function paletteName() {
    return $(`button[data-palette="${palette()}"] .pal-name`)?.textContent || "Matugen";
  }

  function syncAppearance() {
    $$("[data-mode]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.mode === mode())));
    $$("button[data-palette]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.palette === palette())));
    $$(".pw-swatch[data-role]").forEach((b) => {
      const code = $("code", b);
      if (code) code.textContent = tokenValue(b.dataset.role);
    });
    if (pwTitle && !copiedTimer) pwTitle.textContent = paletteName();
    if (modeHint) modeHint.textContent = palette() === "matugen" ? hints.wallpaper : hints.fixed;
  }

  // a click always saves the choice, even for the mode already showing, so the page stops
  // following the system; only a visible change gets the animation
  $$("[data-mode]").forEach((b) =>
    b.addEventListener("click", () => {
      const next = b.dataset.mode;
      store.set("lucid-theme", next);
      if (next !== mode()) reshade(b, () => applyMode(next));
      else applyMode(next);
    })
  );
  $$("button[data-palette]").forEach((b) =>
    b.addEventListener("click", () => {
      const next = b.dataset.palette;
      store.set("lucid-palette", next === "matugen" ? null : next);
      if (next !== palette()) reshade(b, () => applyPalette(next));
    })
  );

  // like the Palette widget: the title says what was copied, then goes back to the theme's name
  $$(".pw-swatch[data-role]").forEach((b) =>
    b.addEventListener("click", async () => {
      const hex = tokenValue(b.dataset.role);
      if (!(await copyText(hex)) || !pwTitle) return;
      clearTimeout(copiedTimer);
      pwTitle.textContent = `Copied ${hex}`;
      copiedTimer = setTimeout(() => {
        copiedTimer = 0;
        syncAppearance();
      }, 1400);
    })
  );

  darkQuery.addEventListener("change", syncAppearance);
  window.addEventListener("storage", (e) => {
    if (e.key === null || e.key === "lucid-theme" || e.key === "lucid-palette") applySaved();
  });
  window.addEventListener("pageshow", (e) => {
    if (e.persisted) applySaved();
  });
  applySaved();

  /* dropdown panels -------------------------------------------------------- */

  let openDd = null;

  function closeDd(returnFocus) {
    if (!openDd) return;
    const { btn, panel } = openDd;
    openDd = null;
    btn.setAttribute("aria-expanded", "false");
    animateOut(panel, () => {
      panel.hidden = true;
    });
    if (returnFocus) btn.focus();
  }

  $$("[data-dd]").forEach((btn) => {
    const panel = document.getElementById(btn.getAttribute("aria-controls"));
    const wrap = btn.closest(".dd");
    if (!panel || !wrap) return;
    btn.addEventListener("click", () => {
      const wasOpen = openDd && openDd.btn === btn;
      closeDd(false);
      if (wasOpen) return;
      btn.setAttribute("aria-expanded", "true");
      cancelOut(panel);
      panel.hidden = false;
      openDd = { btn, panel, wrap };
    });
    wrap.addEventListener("focusout", (e) => {
      if (openDd && openDd.wrap === wrap && e.relatedTarget && !wrap.contains(e.relatedTarget)) closeDd(false);
    });
    panel.addEventListener("click", (e) => {
      if (e.target.closest("a")) closeDd(false);
    });
  });

  document.addEventListener("click", (e) => {
    if (openDd && !openDd.wrap.contains(e.target)) closeDd(false);
  });

  /* mobile sheet ----------------------------------------------------------- */

  const sheet = $("#sheet");
  const menuBtn = $("#menu-btn");

  function openSheet() {
    closeDd(false);
    cancelOut(sheet);
    sheet.hidden = false;
    menuBtn.setAttribute("aria-expanded", "true");
    document.body.classList.add("is-locked");
    $("[data-sheet-close]", sheet)?.focus();
  }

  function closeSheet(returnFocus = true) {
    if (sheet.hidden || sheet.classList.contains("is-closing")) return;
    animateOut(sheet, () => {
      sheet.hidden = true;
    });
    menuBtn.setAttribute("aria-expanded", "false");
    document.body.classList.remove("is-locked");
    if (returnFocus) menuBtn.focus();
  }

  if (sheet && menuBtn) {
    menuBtn.addEventListener("click", openSheet);
    $("[data-sheet-close]", sheet)?.addEventListener("click", () => closeSheet());
    sheet.addEventListener("click", (e) => {
      if (e.target === sheet) closeSheet();
      else if (e.target.closest("a")) closeSheet(false);
    });
    matchMedia("(min-width: 1101px)").addEventListener("change", (e) => {
      if (e.matches) closeSheet(false);
    });
  }

  document.addEventListener("keydown", (e) => {
    if (e.key !== "Escape") return;
    if (openDd) closeDd(true);
    else if (sheet && !sheet.hidden) closeSheet();
  });

  /* copy buttons ------------------------------------------------------------ */

  function textFor(btn) {
    if (btn.dataset.copy != null) return btn.dataset.copy;
    const pre = $("pre", btn.closest(".code") || document.createElement("div"));
    if (!pre) return "";
    const clone = pre.cloneNode(true);
    $$(".p, .c", clone).forEach((n) => n.remove());
    return clone.textContent.replace(/[ \t]+$/gm, "").trim();
  }

  $$(".copy-btn").forEach((btn) =>
    btn.addEventListener("click", async () => {
      if (!(await copyText(textFor(btn)))) {
        snack("Couldn't reach the clipboard. Select the text instead");
        return;
      }
      const use = $("use", btn);
      btn.classList.add("is-done");
      use?.setAttribute("href", "#i-check");
      snack("Copied to clipboard");
      setTimeout(() => {
        btn.classList.remove("is-done");
        use?.setAttribute("href", "#i-content_copy");
      }, 1600);
    })
  );

  /* live GitHub numbers, cached for half an hour ---------------------------- */

  const ghEls = $$("[data-gh]");
  if (ghEls.length) {
    const fmt = (n) => (n >= 1000 ? `${(n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "")}k` : String(n));
    const apply = (d) =>
      ghEls.forEach((el) => {
        const v = d[el.dataset.gh];
        if (typeof v === "number") el.textContent = fmt(v);
      });
    let cached = null;
    try {
      cached = JSON.parse(store.get("lucid-gh", "sessionStorage") || "null");
    } catch {
      cached = null;
    }
    if (cached && Date.now() - cached.t < 30 * 60 * 1000) {
      apply(cached.d);
    } else {
      fetch(`https://api.github.com/repos/${REPO}`, { headers: { Accept: "application/vnd.github+json" } })
        .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
        .then((j) => {
          const d = { stars: j.stargazers_count, forks: j.forks_count };
          apply(d);
          store.set("lucid-gh", JSON.stringify({ t: Date.now(), d }), "sessionStorage");
        })
        .catch(() => {
          /* keep the numbers baked into the page */
        });
    }
  }

  // avatars come from GitHub; fall back to the Lucid mark when offline
  $$("img[data-fallback]").forEach((img) => {
    const fallback = () => {
      img.removeAttribute("data-fallback");
      img.src = "assets/images/icon-192.png";
    };
    if (img.complete && img.naturalWidth === 0) fallback();
    else img.addEventListener("error", fallback, { once: true });
  });

  /* scroll reveal: armed in the page head, so nothing flashes before it hides ---- */

  if (root.classList.contains("reveal-ready")) {
    window.__lucidReveal = true;
    const selector = [
      ".ann-wrap > *", ".section-head", ".bento > *", ".cards > *", ".routes > *", ".keygrid > *", ".steps > li",
      ".theming > *", ".install > *", ".feature-copy", ".feature-detail", ".mini-grid > *",
      ".table-wrap", ".callout", ".release", ".stats > *", ".timeline > li", ".people > *",
      ".mark-story", ".gallery > *", ".gather > *", ".report > *", ".prose > section",
      ".topics > *", ".more-row", ".shot-caption", ".footer-grid > *", ".footer-base",
    ].join(",");
    const found = $$(selector);
    const set = new Set(found);
    const insideAnother = (el) => {
      for (let p = el.parentElement; p; p = p.parentElement) if (set.has(p)) return true;
      return false;
    };
    // the outermost match animates; anything inside it just comes along
    const targets = found.filter((el) => {
      if (!insideAnother(el)) return true;
      el.classList.add("reveal-skip");
      return false;
    });
    const io = new IntersectionObserver((entries) => {
      entries
        .filter((e) => e.isIntersecting)
        .map((e) => e.target)
        .sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1))
        .forEach((el, i) => {
          el.style.setProperty("--reveal-delay", `${Math.min(i, 6) * 70}ms`);
          el.classList.add("is-in");
          io.unobserve(el);
        });
    });
    targets.forEach((el) => io.observe(el));
  }

  /* on-this-page highlighting ---------------------------------------------- */

  $$("[data-spy]").forEach((nav) => {
    const links = $$('a[href^="#"]', nav);
    const targets = new Map();
    links.forEach((a) => {
      const t = document.getElementById(a.getAttribute("href").slice(1));
      if (t) targets.set(t, a);
    });
    if (!targets.size || !("IntersectionObserver" in window)) return;
    const visible = new Set();
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => (e.isIntersecting ? visible.add(e.target) : visible.delete(e.target)));
        const first = [...targets.keys()].find((t) => visible.has(t));
        if (!first) return;
        const active = targets.get(first);
        links.forEach((a) => a.classList.toggle("is-active", a === active));
        if (nav.scrollWidth > nav.clientWidth) nav.scrollTo({ left: active.offsetLeft - 24 });
      },
      { rootMargin: "-18% 0px -62% 0px" }
    );
    targets.forEach((_, t) => io.observe(t));
  });

  /* screenshot viewer ------------------------------------------------------- */

  const lb = $("#lightbox");
  if (lb && typeof lb.showModal === "function") {
    const items = $$("[data-lb]");
    const img = $("#lb-img");
    const caption = $("#lb-caption");
    const count = $("#lb-count");
    let index = 0;
    let swiped = false;

    function show(i) {
      index = (i + items.length) % items.length;
      const a = items[index];
      img.src = a.getAttribute("href");
      img.alt = $("img", a)?.alt || "";
      img.style.animation = "none";
      void img.offsetWidth;
      img.style.animation = "";
      const title = document.createElement("strong");
      title.textContent = a.dataset.title || "";
      caption.replaceChildren(title);
      count.textContent = `${index + 1} / ${items.length}`;
    }

    items.forEach((a, i) =>
      a.addEventListener("click", (e) => {
        e.preventDefault();
        cancelOut(lb);
        show(i);
        lb.showModal();
        document.body.classList.add("is-locked");
      })
    );

    const closeLb = () => {
      if (lb.open && !lb.classList.contains("is-closing")) animateOut(lb, () => lb.close());
    };

    lb.addEventListener("close", () => {
      document.body.classList.remove("is-locked");
      items[index]?.focus();
    });

    // Escape fades out like the close button instead of vanishing
    lb.addEventListener("cancel", (e) => {
      e.preventDefault();
      closeLb();
    });

    lb.addEventListener("click", (e) => {
      if (swiped) {
        swiped = false;
        return;
      }
      const act = e.target.closest("[data-lb-act]")?.dataset.lbAct;
      if (act === "close") closeLb();
      else if (act === "prev") show(index - 1);
      else if (act === "next") show(index + 1);
      else if (e.target === lb || e.target.classList.contains("lb-stage")) closeLb();
    });

    lb.addEventListener("keydown", (e) => {
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        show(index - 1);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        show(index + 1);
      }
    });

    let startX = null;
    lb.addEventListener("pointerdown", (e) => {
      startX = e.clientX;
    });
    lb.addEventListener("pointerup", (e) => {
      if (startX == null) return;
      const dx = e.clientX - startX;
      startX = null;
      if (Math.abs(dx) > 60) {
        swiped = true;
        show(index + (dx < 0 ? 1 : -1));
      }
    });
  }

  /* announcements ----------------------------------------------------------- */

  // each announcement is a <dialog id="ann-<id>">; anything with data-ann="<id>" opens it,
  // and index.html#ann-<id> opens it on arrival, so one can be linked to directly
  function openAnn(id) {
    const dlg = document.getElementById(`ann-${id}`);
    if (!dlg || typeof dlg.showModal !== "function") return false;
    cancelOut(dlg);
    if (!dlg.open) dlg.showModal();
    document.body.classList.add("is-locked");
    $(".ann-scroll", dlg)?.scrollTo(0, 0);
    history.replaceState(null, "", `#${dlg.id}`);
    return true;
  }

  $$(".ann-dialog").forEach((dlg) => {
    const close = () => {
      if (dlg.open && !dlg.classList.contains("is-closing")) animateOut(dlg, () => dlg.close());
    };
    dlg.addEventListener("cancel", (e) => {
      e.preventDefault();
      close();
    });
    dlg.addEventListener("click", (e) => {
      if (e.target === dlg || e.target.closest("[data-ann-close]")) close();
    });
    dlg.addEventListener("close", () => {
      document.body.classList.remove("is-locked");
      if (location.hash === `#${dlg.id}`) history.replaceState(null, "", location.pathname + location.search);
    });
  });

  $$("[data-ann]").forEach((el) =>
    el.addEventListener("click", (e) => {
      if (openAnn(el.dataset.ann)) e.preventDefault();
    })
  );

  const annHash = location.hash.match(/^#ann-(.+)$/);
  if (annHash) openAnn(annHash[1]);

  /* Help Center ------------------------------------------------------------- */

  const search = $("#help-search");
  if (search) {
    const articles = $$(".article");
    const topics = $$(".topic");
    const clear = $("#help-clear");
    const reset = $("#help-reset");
    const counter = $("#help-count");
    const empty = $("#help-empty");
    const emptyText = $("#help-empty-text");
    const norm = (s) => s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    const index = articles.map((a) => norm(`${a.textContent} ${a.dataset.keywords || ""}`));
    let topic = null;

    topics.forEach((b) => {
      const n = articles.filter((a) => a.dataset.topic === b.dataset.topic).length;
      const small = $("[data-topic-count]", b);
      if (small) small.textContent = `${n} article${n === 1 ? "" : "s"}`;
    });

    function run() {
      const raw = search.value.trim();
      const words = norm(raw).split(/\s+/).filter(Boolean);
      let shown = 0;
      articles.forEach((a, i) => {
        const ok = (!topic || a.dataset.topic === topic) && words.every((w) => index[i].includes(w));
        a.hidden = !ok;
        if (ok) shown += 1;
      });
      const label = topic ? $("strong", topics.find((b) => b.dataset.topic === topic)).textContent : "";
      clear.hidden = !raw;
      reset.hidden = !(topic || raw);
      counter.textContent =
        shown === articles.length
          ? `Showing all ${shown} articles`
          : `${shown} of ${articles.length} articles${label ? ` in ${label}` : ""}${raw ? ` matching “${raw}”` : ""}`;
      empty.hidden = shown > 0;
      if (!shown) emptyText.textContent = `No articles match “${raw}”${label ? ` in ${label}` : ""}.`;
    }

    search.addEventListener("input", run);
    clear.addEventListener("click", () => {
      search.value = "";
      run();
      search.focus();
    });
    reset.addEventListener("click", () => {
      search.value = "";
      topic = null;
      topics.forEach((b) => b.setAttribute("aria-pressed", "false"));
      run();
    });
    topics.forEach((b) =>
      b.addEventListener("click", () => {
        topic = topic === b.dataset.topic ? null : b.dataset.topic;
        topics.forEach((t) => t.setAttribute("aria-pressed", String(t.dataset.topic === topic)));
        run();
      })
    );

    function openFromHash() {
      const id = decodeURIComponent(location.hash.slice(1));
      const a = id && document.getElementById(id);
      if (!a || !a.classList.contains("article")) return;
      a.hidden = false;
      a.open = true;
      a.scrollIntoView({ block: "start" });
    }

    articles.forEach((a) =>
      a.addEventListener("toggle", () => {
        if (a.open) history.replaceState(null, "", `#${a.id}`);
      })
    );

    const q = new URLSearchParams(location.search).get("q");
    if (q) search.value = q;
    run();
    openFromHash();
    window.addEventListener("hashchange", openFromHash);
  }

  /* report builder ---------------------------------------------------------- */

  const form = $("#report-form");
  if (form) {
    const preview = $("#report-preview");
    const openBtn = $("#report-open");
    const chip = $("#report-kind-chip");
    const MAX_BODY = 6000;
    const val = (name) => (form.elements[name]?.value || "").trim();
    const kind = () => (form.elements.kind.value === "feature" ? "feature" : "bug");
    const section = (heading, body, placeholder) => `### ${heading}\n\n${body || placeholder}\n`;

    function markdown(log = val("log")) {
      if (kind() === "feature") {
        return [
          section("What should Lucid do?", val("idea"), "_Describe the feature._"),
          section("Why would it help?", val("why"), "_What would it make easier?_"),
        ].join("\n");
      }
      const env = [
        `- Lucid: ${val("lucid") || "_version_"}`,
        `- Hyprland: ${val("hypr") || "_version_"}`,
        `- GPU: ${val("gpu") || "_not sure_"}`,
      ].join("\n");
      return [
        section("What happened", val("what"), "_Describe the problem._"),
        section("What I expected", val("expected"), "_What should have happened?_"),
        section("Steps to reproduce", val("steps"), "1. \n2. \n3. "),
        section("Environment", env),
        section("Log", log ? `\`\`\`\n${log}\n\`\`\`` : "", "_Output of `qs log`._"),
      ].join("\n");
    }

    function update() {
      const k = kind();
      $$("[data-for]", form).forEach((el) => {
        el.hidden = el.dataset.for !== k;
      });
      chip.textContent = k === "feature" ? "Idea" : "Bug";
      const title = val("title");
      let body = markdown();
      preview.textContent = (title ? `# ${title}\n\n` : "") + body;
      if (body.length > MAX_BODY) {
        // links have a length limit, so keep the end of the log, where the error usually is
        const log = val("log");
        const keep = Math.max(0, log.length - (body.length - MAX_BODY) - 120);
        body = markdown(`[log trimmed: paste the full output below]\n…${log.slice(log.length - keep)}`);
      }
      const params = new URLSearchParams({ title, body });
      openBtn.href = `https://github.com/${REPO}/issues/new?${params}`;
    }

    function kindFromHash() {
      if (location.hash !== "#feature") return;
      $("#kind-feature").checked = true;
      update();
      $("#report")?.scrollIntoView({ block: "start" });
    }

    form.addEventListener("input", update);
    form.addEventListener("change", update);
    form.addEventListener("submit", (e) => e.preventDefault());
    $("#report-copy").addEventListener("click", async () => {
      if (await copyText(preview.textContent)) snack("Report copied as Markdown");
    });
    $$("[data-kind-link]").forEach((a) =>
      a.addEventListener("click", () => {
        $(`#kind-${a.dataset.kindLink}`).checked = true;
        update();
      })
    );
    update();
    kindFromHash();
    window.addEventListener("hashchange", kindFromHash);
  }
})();
