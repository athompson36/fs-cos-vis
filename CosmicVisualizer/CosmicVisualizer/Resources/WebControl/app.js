(() => {
  const qs = (sel) => document.querySelector(sel);
  const token = new URLSearchParams(window.location.search).get("token") || "";

  async function api(path, opts = {}) {
    const headers = opts.headers || {};
    if (token) headers["Authorization"] = "Bearer " + token;
    const r = await fetch(path, { ...opts, headers });
    return r;
  }

  async function postCommand(body) {
    const r = await api("/api/command", {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) },
      body: JSON.stringify(body),
    });
    if (!r.ok) console.warn("command failed", r.status);
  }

  function applyState(s) {
    qs("#bpm").textContent = Math.round(s.bpm || 0);
    qs("#phase").textContent = (s.beatPhase ?? 0).toFixed(2);
    qs("#sync").textContent = s.syncSource || "—";
    qs("#conf").textContent =
      s.beatConfidence != null ? Math.round(s.beatConfidence * 100) + "%" : "—";
    qs("#rms").textContent = (s.audioRMS ?? 0).toFixed(3);
    qs("#peak").textContent = (s.audioPeak ?? 0).toFixed(3);
    const ae = s.audioError;
    const aep = qs("#audioErrP");
    if (ae) {
      aep.hidden = false;
      qs("#audioErr").textContent = ae;
    } else {
      aep.hidden = true;
    }
    const dmxOn = s.dmxEnabled;
    qs("#dmxStat").textContent = dmxOn ? "on ~" + (s.dmxNominalHz || 0) + " Hz" : "off";
    qs("#dmxErr").textContent = s.dmxLastError ? " · " + s.dmxLastError : "";

    const fx = s.lightingPatchFixtureCount ?? 0;
    const nCues = s.lightingCueCount ?? 0;
    const cueName = s.lightingActiveCueName;
    let lightingLine = fx + " patch · " + nCues + " cue" + (nCues === 1 ? "" : "s");
    if (cueName) lightingLine += " · " + cueName;
    if ((s.lightingModulatorCount ?? 0) > 0) {
      lightingLine += " · " + s.lightingModulatorCount + " mod";
    }
    qs("#lightingStat").textContent = lightingLine;

    const list = qs("#sceneList");
    list.innerHTML = "";
    (s.scenes || []).forEach((sc, i) => {
      const li = document.createElement("li");
      const mark = i === s.sceneIndex ? "> " : "";
      li.textContent = mark + sc.name;
      list.appendChild(li);
    });
  }

  async function poll() {
    try {
      const r = await api("/api/state");
      if (!r.ok) return;
      const s = await r.json();
      applyState(s);
    } catch (e) {
      console.warn(e);
    }
  }

  qs("#tap").onclick = () => postCommand({ type: "TapTempo" });
  qs("#prev").onclick = () => postCommand({ type: "PreviousScene" });
  qs("#next").onclick = () => postCommand({ type: "NextScene" });
  qs("#rand").onclick = () => postCommand({ type: "RandomScene" });
  qs("#dup").onclick = () => postCommand({ type: "DuplicateScene" });
  qs("#del").onclick = () => postCommand({ type: "DeleteScene" });
  qs("#saveScenes").onclick = () => postCommand({ type: "PersistScenes" });

  const fz = qs("#fractalZoom");
  const lt = qs("#liqTurbo");
  const cb = qs("#composite");
  let t1, t2, t3;
  fz.addEventListener("input", () => {
    clearTimeout(t1);
    t1 = setTimeout(() => postCommand({ type: "SetFractalZoom", fractalZoom: parseFloat(fz.value) }), 80);
  });
  lt.addEventListener("input", () => {
    clearTimeout(t2);
    t2 = setTimeout(() => postCommand({ type: "SetLiquidTurbulence", liquidTurbulence: parseFloat(lt.value) }), 80);
  });
  cb.addEventListener("input", () => {
    clearTimeout(t3);
    t3 = setTimeout(() => postCommand({ type: "SetCompositeBlend", compositeBlend: parseFloat(cb.value) }), 80);
  });

  const proto = window.location.protocol === "https:" ? "wss" : "ws";
  const wsUrl = proto + "://" + window.location.host + "/ws" + (token ? "?token=" + encodeURIComponent(token) : "");
  let useWs = true;
  try {
    const sock = new WebSocket(wsUrl);
    sock.onmessage = (ev) => {
      try {
        applyState(JSON.parse(ev.data));
      } catch (_) {}
    };
    sock.onerror = () => {
      useWs = false;
    };
    sock.onclose = () => {
      useWs = false;
    };
  } catch (_) {
    useWs = false;
  }

  setInterval(() => {
    if (!useWs) poll();
  }, 500);
  poll();
})();
