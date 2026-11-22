// Browser twin of the local-only Roblox console. No gameplay API or persistence.
const $ = (s, p = document) => p.querySelector(s);
const el = (tag, cls, str) => {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (str != null) n.textContent = str;
  return n;
};
const ns = "http://www.w3.org/2000/svg";
async function boot() {
  const response = await fetch("kit.json");
  if (!response.ok) throw new Error("Missing console catalog");
  const { tabs, icons, accents } = await response.json();
  function glyph(name) {
    const svg = document.createElementNS(ns, "svg");
    const attrs = (n, a) =>
      Object.entries(a).forEach(([k, v]) => n.setAttribute(k, v));
    attrs(svg, {
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.6,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      "aria-hidden": true,
    });
    for (const [shape, ...p] of icons[name]) {
      const [x, y, w, h, rot] = p;
      const node = document.createElementNS(
        ns,
        { o: "ellipse", p: "polyline", c: "circle", b: "rect" }[shape],
      );
      if (shape === "o")
        attrs(node, {
          cx: x,
          cy: y,
          rx: w / 2,
          ry: h / 2,
          transform: `rotate(${rot} ${x} ${y})`,
          fill: "currentColor",
          stroke: "none",
        });
      if (shape === "p") node.setAttribute("points", p.join(" "));
      if (shape === "b") attrs(node, { x, y, width: w, height: h, rx: 1.4 });
      if (shape === "c") attrs(node, { cx: x, cy: y, r: w });
      svg.append(node);
    }
    return svg;
  }
  for (const node of document.querySelectorAll("[data-glyph]"))
    node.append(glyph(node.dataset.glyph));
  const win = $("#window"),
    bench = $("#workbench"),
    open = $("#open"),
    modal = $("#confirm");
  const state = {
    page: 0,
    on: new Set(),
    levels: {},
    accent: 0,
    notes: true,
    compact: false,
  };
  const total = tabs.reduce((n, t) => n + (t.cards?.length ?? 0), 0);
  let timer = 0,
    action = null,
    previousFocus = null;
  const normalStatus = "Local preview · no game effects";
  function status(text = normalStatus) {
    clearTimeout(timer);
    $("#status").textContent = text;
    if (text !== normalStatus) timer = setTimeout(() => status(), 2200);
  }
  function updateCount() {
    $("#count").textContent = `${state.on.size} / ${total} SELECTED`;
  }
  function theme() {
    document.documentElement.style.setProperty(
      "--ice",
      "#" + accents[state.accent].hex,
    );
    win.classList.toggle("trim", state.compact);
    win.classList.toggle("no-notes", !state.notes);
  }
  function makeCard(data, index, onClick, pressed) {
    const b = el("button", "card");
    b.type = "button";
    b.setAttribute("aria-label", data.name);
    b.setAttribute("aria-pressed", String(pressed()));
    const top = el("span", "card-top"),
      tile = el("span", "icon-tile");
    tile.append(glyph(data.icon));
    top.append(
      tile,
      el("span", "serial", `${tabs[state.page].name[0]} / 0${index + 1}`),
      el("span", "switch"),
    );
    const text = el("span");
    text.append(el("strong", "", data.name), el("small", "", data.note));
    b.append(top, text);
    b.onclick = () => {
      onClick();
      b.setAttribute("aria-pressed", String(pressed()));
    };
    return b;
  }
  function tuner(tab) {
    const spec = tab.slider,
      row = el("div", "tune"),
      tile = el("span", "icon-tile");
    tile.append(glyph("range"));
    const label = el("label", "", spec.name);
    label.htmlFor = "tuning";
    const input = el("input");
    input.type = "range";
    input.id = "tuning";
    input.min = spec.min;
    input.max = spec.max;
    input.value = state.levels[tab.name] ?? spec.initial;
    const output = el("output");
    output.htmlFor = "tuning";
    const sync = () => {
      const v = +input.value;
      output.textContent = v + spec.suffix;
      input.style.setProperty(
        "--fill",
        (100 * (v - spec.min)) / (spec.max - spec.min) + "%",
      );
      input.setAttribute("aria-valuetext", v + spec.suffix);
    };
    sync();
    input.oninput = () => {
      state.levels[tab.name] = +input.value;
      sync();
    };
    row.append(tile, label, input, output);
    return row;
  }
  function ask(title, body, verb, fn) {
    previousFocus = document.activeElement;
    action = fn;
    $("#dialogTitle").textContent = title;
    $("#dialogText").textContent = body;
    $("#accept").textContent = verb;
    modal.showModal();
    $("#cancel").focus();
  }
  $("#cancel").onclick = () => modal.close();
  modal.addEventListener("close", () => {
    action = null;
    if (previousFocus?.isConnected && !win.hidden) previousFocus.focus();
  });
  $("#accept").onclick = () => {
    const fn = action;
    modal.close();
    fn?.();
  };
  function settings() {
    const palette = el("div", "palette"),
      tile = el("span", "icon-tile");
    tile.append(glyph("palette"));
    const caption = el("strong", "", `Accent · ${accents[state.accent].name}`);
    const swatches = el("div", "swatches");
    for (const [i, a] of accents.entries()) {
      const b = el("button");
      b.title = a.name;
      b.setAttribute("aria-label", a.name + " accent");
      b.setAttribute("aria-pressed", String(i === state.accent));
      const dot = el("i");
      dot.style.background = "#" + a.hex;
      b.append(dot);
      b.onclick = () => {
        state.accent = i;
        caption.textContent = "Accent · " + a.name;
        [...swatches.children].forEach((c, j) =>
          c.setAttribute("aria-pressed", String(i === j)),
        );
        theme();
      };
      swatches.append(b);
    }
    palette.append(tile, caption, swatches);
    const grid = el("div", "grid");
    for (const [i, data] of [
      {
        name: "Module notes",
        icon: "notes",
        note: "Card descriptions",
        key: "notes",
      },
      {
        name: "Compact cards",
        icon: "grid",
        note: "Denser spacing",
        key: "compact",
      },
    ].entries())
      grid.append(
        makeCard(
          data,
          i,
          () => {
            state[data.key] = !state[data.key];
            theme();
          },
          () => state[data.key],
        ),
      );
    const reset = el("div", "reset-row"),
      copy = el("div");
    copy.append(
      el("strong", "", "Reset preview"),
      el("p", "", "Restore the default look and switches."),
    );
    const btn = el("button", "", "Reset");
    btn.onclick = () =>
      ask(
        "Reset the preview?",
        "This clears selections, tuning and appearance for this session.",
        "Reset",
        () => {
          state.on.clear();
          state.levels = {};
          state.accent = 0;
          state.compact = false;
          state.notes = true;
          render();
          status("Preview reset");
        },
      );
    reset.append(copy, btn);
    bench.append(palette, grid, reset);
  }
  function render() {
    const tab = tabs[state.page];
    theme();
    status();
    updateCount();
    for (const n of document.querySelectorAll("nav button")) {
      if (+n.dataset.i === state.page) n.setAttribute("aria-current", "page");
      else n.removeAttribute("aria-current");
    }
    $("#crumb").textContent = tab.name;
    $("#heroLead").textContent = tab.lead;
    $("#heroScript").textContent = tab.script;
    $("#heroNote").textContent = tab.caption;
    $("#kicker").textContent = `WORKBENCH / 0${state.page + 1}`;
    $("#heading").textContent = tab.cards ? "Module library" : "Preferences";
    $("#suite").replaceChildren(
      glyph(tab.icon),
      document.createTextNode(tab.type),
    );
    bench.replaceChildren();
    if (tab.cards) {
      const grid = el("div", "grid");
      tab.cards.forEach((d, i) =>
        grid.append(
          makeCard(
            d,
            i,
            () => {
              if (state.on.has(d.id)) state.on.delete(d.id);
              else state.on.add(d.id);
              updateCount();
            },
            () => state.on.has(d.id),
          ),
        ),
      );
      bench.append(grid, tuner(tab));
    } else settings();
    $("#scroll").scrollTop = 0;
  }
  for (const nav of document.querySelectorAll("nav"))
    tabs.forEach((tab, i) => {
      const b = el("button");
      b.dataset.i = i;
      b.append(
        glyph(tab.icon),
        el("span", "", tab.name),
        el("b", "", `0${i + 1}`),
      );
      b.onclick = () => {
        if (i !== state.page) {
          state.page = i;
          render();
        }
      };
      nav.append(b);
    });
  function hide() {
    win.hidden = true;
    open.hidden = false;
    open.focus();
  }
  function restore() {
    open.hidden = true;
    win.hidden = false;
    $("#min").focus();
  }
  $("#min").onclick = hide;
  open.onclick = restore;
  $("#exit").onclick = () =>
    ask(
      "Close Snowpaw?",
      "Closing clears this local session. You can launch the console again.",
      "Close",
      () => {
        state.on.clear();
        state.levels = {};
        state.accent = 0;
        state.compact = false;
        state.notes = true;
        state.page = 0;
        render();
        hide();
      },
    );
  window.addEventListener("keydown", (e) => {
    if (e.code === "ShiftRight" && !e.repeat && !modal.open) {
      win.hidden ? restore() : hide();
    }
  });
  const wrap = $("#wrap"),
    handle = $("#handle");
  let pos = { x: 0, y: 0 },
    drag = null;
  function move(x, y) {
    const rx = Math.max(0, (innerWidth - wrap.offsetWidth) / 2 - 3),
      ry = Math.max(0, (innerHeight - wrap.offsetHeight) / 2 - 3);
    pos = {
      x: Math.max(-rx, Math.min(rx, x)),
      y: Math.max(-ry, Math.min(ry, y)),
    };
    wrap.style.left = `${pos.x}px`;
    wrap.style.top = `${pos.y}px`;
  }
  handle.onpointerdown = (e) => {
    if (e.button !== 0 || e.target.closest("button")) return;
    drag = { x: e.clientX - pos.x, y: e.clientY - pos.y, id: e.pointerId };
    handle.setPointerCapture(e.pointerId);
  };
  handle.onpointermove = (e) => {
    if (drag?.id === e.pointerId) move(e.clientX - drag.x, e.clientY - drag.y);
  };
  handle.onlostpointercapture = () => {
    drag = null;
  };
  window.addEventListener("resize", () => move(pos.x, pos.y));
  render();
  win.hidden = false;
  $("#boot").hidden = true;
}
boot().catch((err) => {
  console.error(err);
  $("#boot").textContent =
    "Could not load the console catalog. Reload to retry.";
});
