import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import FluidBackground from "./components/FluidBackground.jsx";
import { ClockFace } from "./components/ClockFaces.jsx";
import { Glyph } from "./components/icons.jsx";
import { backgrounds, clockStyles, sideItems } from "./lib/presets.js";

function useClock() {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  return now;
}

const DEFAULT_RENDERER_SETTINGS = {
  launchAtLogin: true,
  autoStartScreensaver: true,
  idleMinutes: 5,
  hideDock: true,
  displayCount: 1,
  screensaverRunning: false,
  clockStyle: "digital",
  backgroundId: "aurora",
  motion: 42,
  showDate: true,
  showSeconds: false,
  showTemp: true,
  temperature: 24,
  customBackgroundUrl: "",
  customBackgroundName: "",
  paletteOverrides: {},
};

const idleOptions = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120];
const CUSTOM_BACKGROUND_ID = "custom";
const fallbackGradient = ["#0d1118", "#1b2430", "#435268", "#8492a6", "#f8fafc"];

function boolFromParam(value, fallback) {
  if (value === "true") return true;
  if (value === "false") return false;
  return fallback;
}

function numberFromValue(value, fallback, min, max) {
  const next = Number(value);
  if (!Number.isFinite(next)) return fallback;
  return Math.min(max, Math.max(min, next));
}

function validClockStyle(id, fallback = DEFAULT_RENDERER_SETTINGS.clockStyle) {
  return clockStyles.some((style) => style.id === id) ? id : fallback;
}

function validBackground(id, fallback = DEFAULT_RENDERER_SETTINGS.backgroundId) {
  return backgrounds.some((background) => background.id === id) || id === CUSTOM_BACKGROUND_ID ? id : fallback;
}

function isHexColor(value) {
  return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value);
}

function normalizePaletteOverrides(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  return Object.fromEntries(
    Object.entries(value)
      .filter(([id, colors]) => backgrounds.some((background) => background.id === id) && Array.isArray(colors))
      .map(([id, colors]) => [id, colors.slice(0, 5).filter(isHexColor)])
      .filter(([, colors]) => colors.length === 5),
  );
}

function parseJsonParam(value, fallback) {
  if (!value) return fallback;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function buildBackgrounds(settings) {
  const paletteOverrides = normalizePaletteOverrides(settings.paletteOverrides);
  const presetBackgrounds = backgrounds.map((background) => {
    const gradient = paletteOverrides[background.id];
    if (!gradient) return background;
    return {
      ...background,
      gradient,
      accent: gradient[3] ?? background.accent,
    };
  });

  if (!settings.customBackgroundUrl) return presetBackgrounds;

  return [
    ...presetBackgrounds,
    {
      id: CUSTOM_BACKGROUND_ID,
      name: settings.customBackgroundName || "Custom Image",
      scene: "image",
      accent: "#f8fafc",
      gradient: fallbackGradient,
      imageUrl: settings.customBackgroundUrl,
    },
  ];
}

function normalizeSettings(raw = {}) {
  return {
    ...DEFAULT_RENDERER_SETTINGS,
    ...raw,
    idleMinutes: numberFromValue(raw.idleMinutes, DEFAULT_RENDERER_SETTINGS.idleMinutes, 1, 180),
    motion: numberFromValue(raw.motion, DEFAULT_RENDERER_SETTINGS.motion, 8, 100),
    temperature: numberFromValue(raw.temperature, DEFAULT_RENDERER_SETTINGS.temperature, -80, 80),
    clockStyle: validClockStyle(raw.clockStyle),
    backgroundId: validBackground(raw.backgroundId),
    launchAtLogin: typeof raw.launchAtLogin === "boolean" ? raw.launchAtLogin : DEFAULT_RENDERER_SETTINGS.launchAtLogin,
    autoStartScreensaver:
      typeof raw.autoStartScreensaver === "boolean"
        ? raw.autoStartScreensaver
        : DEFAULT_RENDERER_SETTINGS.autoStartScreensaver,
    hideDock: typeof raw.hideDock === "boolean" ? raw.hideDock : DEFAULT_RENDERER_SETTINGS.hideDock,
    showDate: typeof raw.showDate === "boolean" ? raw.showDate : DEFAULT_RENDERER_SETTINGS.showDate,
    showSeconds: typeof raw.showSeconds === "boolean" ? raw.showSeconds : DEFAULT_RENDERER_SETTINGS.showSeconds,
    showTemp: typeof raw.showTemp === "boolean" ? raw.showTemp : DEFAULT_RENDERER_SETTINGS.showTemp,
    displayCount: numberFromValue(raw.displayCount, DEFAULT_RENDERER_SETTINGS.displayCount, 1, 16),
    customBackgroundUrl:
      typeof raw.customBackgroundUrl === "string" ? raw.customBackgroundUrl : DEFAULT_RENDERER_SETTINGS.customBackgroundUrl,
    customBackgroundName:
      typeof raw.customBackgroundName === "string"
        ? raw.customBackgroundName
        : DEFAULT_RENDERER_SETTINGS.customBackgroundName,
    paletteOverrides: normalizePaletteOverrides(raw.paletteOverrides),
    screensaverRunning:
      typeof raw.screensaverRunning === "boolean" ? raw.screensaverRunning : DEFAULT_RENDERER_SETTINGS.screensaverRunning,
  };
}

function readRouteSettings() {
  if (typeof window === "undefined") {
    return { ...DEFAULT_RENDERER_SETTINGS, saverMode: false };
  }

  const params = new URLSearchParams(window.location.search);
  return normalizeSettings({
    saverMode: params.get("saver") === "1",
    clockStyle: validClockStyle(params.get("style")),
    backgroundId: validBackground(params.get("background")),
    motion: numberFromValue(params.get("motion"), DEFAULT_RENDERER_SETTINGS.motion, 8, 100),
    showDate: boolFromParam(params.get("showDate"), DEFAULT_RENDERER_SETTINGS.showDate),
    showSeconds: boolFromParam(params.get("showSeconds"), DEFAULT_RENDERER_SETTINGS.showSeconds),
    showTemp: boolFromParam(params.get("showTemp"), DEFAULT_RENDERER_SETTINGS.showTemp),
    temperature: numberFromValue(params.get("temperature"), DEFAULT_RENDERER_SETTINGS.temperature, -80, 80),
    customBackgroundUrl: params.get("customBackgroundUrl") ?? DEFAULT_RENDERER_SETTINGS.customBackgroundUrl,
    customBackgroundName: params.get("customBackgroundName") ?? DEFAULT_RENDERER_SETTINGS.customBackgroundName,
    paletteOverrides: parseJsonParam(params.get("paletteOverrides"), DEFAULT_RENDERER_SETTINGS.paletteOverrides),
  });
}

export default function App() {
  const now = useClock();
  const routeSettings = useMemo(() => readRouteSettings(), []);
  const isSystemSaver = routeSettings.saverMode;
  const [mode, setMode] = useState("gallery");
  const [clockStyle, setClockStyleState] = useState(routeSettings.clockStyle);
  const [backgroundId, setBackgroundIdState] = useState(routeSettings.backgroundId);
  const [motion, setMotionState] = useState(routeSettings.motion);
  const [showDate, setShowDateState] = useState(routeSettings.showDate);
  const [showSeconds, setShowSecondsState] = useState(routeSettings.showSeconds);
  const [showTemp, setShowTempState] = useState(routeSettings.showTemp);
  const [favorite, setFavorite] = useState(false);
  const [screensaver, setScreensaver] = useState(false);
  const [nativeSettings, setNativeSettings] = useState(() => normalizeSettings(routeSettings));

  const availableBackgrounds = useMemo(() => buildBackgrounds(nativeSettings), [nativeSettings]);

  const background = useMemo(
    () => availableBackgrounds.find((item) => item.id === backgroundId) ?? availableBackgrounds[0],
    [availableBackgrounds, backgroundId],
  );

  const persistSettings = useCallback(async (patch) => {
    const optimisticSettings = normalizeSettings({ ...nativeSettings, ...patch });
    setNativeSettings(optimisticSettings);

    if (!window.clockio?.updateSettings) return optimisticSettings;

    try {
      const updated = normalizeSettings(await window.clockio.updateSettings(patch));
      setNativeSettings(updated);
      return updated;
    } catch (error) {
      console.warn("Unable to update Clockio settings", error);
      return optimisticSettings;
    }
  }, [nativeSettings]);

  const currentVisualSettings = useCallback(
    () => ({
      clockStyle,
      backgroundId,
      motion,
      showDate,
      showSeconds,
      showTemp,
    }),
    [backgroundId, clockStyle, motion, showDate, showSeconds, showTemp],
  );

  const openScreensaver = useCallback(async () => {
    if (window.clockio?.startScreensaver) {
      await persistSettings(currentVisualSettings());
      try {
        const result = await window.clockio.startScreensaver();
        if (result?.settings) setNativeSettings(normalizeSettings(result.settings));
        return;
      } catch (error) {
        console.warn("Unable to start native screensaver", error);
      }
    }

    startLocalFullScreen(setScreensaver);
  }, [currentVisualSettings, persistSettings]);

  const closeScreensaver = useCallback(async () => {
    setScreensaver(false);
    exitLocalFullScreen();
    if (window.clockio?.stopScreensaver) {
      try {
        const result = await window.clockio.stopScreensaver();
        if (result?.settings) setNativeSettings(normalizeSettings(result.settings));
      } catch (error) {
        console.warn("Unable to stop native screensaver", error);
      }
    }
  }, []);

  useEffect(() => {
    const handleKey = (event) => {
      if (event.key === "Escape") {
        void closeScreensaver();
      }
      if (event.key.toLowerCase() === "f") {
        void openScreensaver();
      }
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [closeScreensaver, openScreensaver]);

  useEffect(() => {
    if (!window.clockio?.getSettings) return undefined;

    let cancelled = false;
    const applySettings = (settings) => {
      if (cancelled) return;
      const next = normalizeSettings(settings);
      setNativeSettings(next);

      if (!isSystemSaver) {
        setClockStyleState(next.clockStyle);
        setBackgroundIdState(next.backgroundId);
        setMotionState(next.motion);
        setShowDateState(next.showDate);
        setShowSecondsState(next.showSeconds);
        setShowTempState(next.showTemp);
      }
    };

    window.clockio.getSettings().then(applySettings).catch(() => {});
    const unsubscribe = window.clockio.onSettingsChanged?.(applySettings);

    return () => {
      cancelled = true;
      if (typeof unsubscribe === "function") unsubscribe();
    };
  }, [isSystemSaver]);

  useEffect(() => {
    if (!isSystemSaver) return undefined;

    let armed = false;
    const armTimer = window.setTimeout(() => {
      armed = true;
    }, 900);
    const stop = () => {
      if (armed) void closeScreensaver();
    };

    window.addEventListener("pointerdown", stop);
    window.addEventListener("keydown", stop);

    return () => {
      window.clearTimeout(armTimer);
      window.removeEventListener("pointerdown", stop);
      window.removeEventListener("keydown", stop);
    };
  }, [closeScreensaver, isSystemSaver]);

  const shuffleBackground = () => {
    const current = availableBackgrounds.findIndex((item) => item.id === backgroundId);
    const nextBackground = availableBackgrounds[(current + 1) % availableBackgrounds.length].id;
    setBackgroundIdState(nextBackground);
    void persistSettings({ backgroundId: nextBackground });
  };

  const selectClockStyle = (styleId) => {
    const nextStyle = validClockStyle(styleId, clockStyle);
    setClockStyleState(nextStyle);
    void persistSettings({ clockStyle: nextStyle });
  };

  const selectBackground = (nextBackground) => {
    const safeBackground = availableBackgrounds.some((item) => item.id === nextBackground) ? nextBackground : backgroundId;
    setBackgroundIdState(safeBackground);
    void persistSettings({ backgroundId: safeBackground });
  };

  const chooseCustomBackground = async () => {
    if (!window.clockio?.chooseCustomBackground) return;

    try {
      const updated = normalizeSettings(await window.clockio.chooseCustomBackground());
      setNativeSettings(updated);
      setBackgroundIdState(updated.backgroundId);
    } catch (error) {
      console.warn("Unable to choose a custom background", error);
    }
  };

  const updateBackgroundColor = (index, color) => {
    if (!background.customizable || !isHexColor(color)) return;

    const nextGradient = background.gradient.map((current, currentIndex) => (currentIndex === index ? color : current));
    void persistSettings({
      backgroundId: background.id,
      paletteOverrides: {
        ...nativeSettings.paletteOverrides,
        [background.id]: nextGradient,
      },
    });
  };

  const resetBackgroundColors = () => {
    if (!background.customizable) return;

    const { [background.id]: _removed, ...nextOverrides } = nativeSettings.paletteOverrides;
    void persistSettings({ paletteOverrides: nextOverrides });
  };

  const updateMotion = (nextMotion) => {
    const safeMotion = numberFromValue(nextMotion, motion, 8, 100);
    setMotionState(safeMotion);
    void persistSettings({ motion: safeMotion });
  };

  const updateShowDate = (checked) => {
    setShowDateState(checked);
    void persistSettings({ showDate: checked });
  };

  const updateShowSeconds = (checked) => {
    setShowSecondsState(checked);
    void persistSettings({ showSeconds: checked });
  };

  const updateShowTemp = (checked) => {
    setShowTempState(checked);
    void persistSettings({ showTemp: checked });
  };

  if (isSystemSaver) {
    return (
      <main className="app-shell is-saver system-saver">
        <Screensaver
          now={now}
          background={background}
          clockStyle={clockStyle}
          motion={motion}
          showDate={showDate}
          showSeconds={showSeconds}
          showTemp={showTemp}
          temperature={nativeSettings.temperature}
          onClose={closeScreensaver}
        />
      </main>
    );
  }

  const isSettingsMode = mode === "settings";

  return (
    <main className={`app-shell ${screensaver ? "is-saver" : ""}`}>
      <NoiseLayer />
      <TitleBar onSettings={() => setMode("settings")} />
      <section className={`workspace ${isSettingsMode ? "settings-mode" : ""}`} aria-label="Clockio workspace">
        <Sidebar
          mode={mode}
          setMode={setMode}
          backgroundId={backgroundId}
          setBackgroundId={selectBackground}
          backgroundsList={availableBackgrounds}
        />
        <section className="stage-column">
          {isSettingsMode ? (
            <SettingsPage
              settings={nativeSettings}
              updateSettings={persistSettings}
              onStart={openScreensaver}
            />
          ) : (
            <>
              <PreviewCard
                now={now}
                background={background}
                clockStyle={clockStyle}
                motion={motion}
                showDate={showDate}
                showSeconds={showSeconds}
                showTemp={showTemp}
                favorite={favorite}
                setFavorite={setFavorite}
                onExpand={openScreensaver}
              />
              <BackgroundRail
                backgroundId={backgroundId}
                setBackgroundId={selectBackground}
                backgroundsList={availableBackgrounds}
              />
            </>
          )}
        </section>
        {isSettingsMode ? null : (
          <Inspector
            clockStyle={clockStyle}
            setClockStyle={selectClockStyle}
            background={background}
            backgroundId={backgroundId}
            setBackgroundId={selectBackground}
            backgroundsList={availableBackgrounds}
            motion={motion}
            setMotion={updateMotion}
            showDate={showDate}
            setShowDate={updateShowDate}
            showSeconds={showSeconds}
            setShowSeconds={updateShowSeconds}
            showTemp={showTemp}
            setShowTemp={updateShowTemp}
            shuffleBackground={shuffleBackground}
            chooseCustomBackground={chooseCustomBackground}
            updateBackgroundColor={updateBackgroundColor}
            resetBackgroundColors={resetBackgroundColors}
            onStart={openScreensaver}
          />
        )}
      </section>

      {screensaver ? (
        <Screensaver
          now={now}
          background={background}
          clockStyle={clockStyle}
          motion={motion}
          showDate={showDate}
          showSeconds={showSeconds}
          showTemp={showTemp}
          temperature={nativeSettings.temperature}
          onClose={closeScreensaver}
        />
      ) : null}
    </main>
  );
}

function startLocalFullScreen(setScreensaver) {
  setScreensaver(true);
  const root = document.documentElement;
  if (!document.fullscreenElement && root.requestFullscreen) {
    root.requestFullscreen().catch(() => {});
  }
}

function exitLocalFullScreen() {
  if (document.fullscreenElement && document.exitFullscreen) {
    document.exitFullscreen().catch(() => {});
  }
}

function TitleBar({ onSettings }) {
  return (
    <header className="titlebar">
      <div className="window-control-spacer" aria-hidden="true" />
      <div className="title-lockup">
        <span>Clockio</span>
        <small>Studio</small>
      </div>
      <button className="icon-button" type="button" onClick={onSettings} aria-label="Open settings">
        <Glyph name="settings" />
      </button>
    </header>
  );
}

function Sidebar({ mode, setMode, backgroundId, setBackgroundId, backgroundsList }) {
  const presetRows = ["aurora", "mahogany", "spectrum", "silk", "codex"]
    .map((id) => backgroundsList.find((background) => background.id === id))
    .filter(Boolean);

  return (
    <aside className="sidebar">
      <div>
        <h1>Clockio</h1>
        <nav className="mode-list" aria-label="Primary">
          {sideItems.map((item) => (
            <button
              className={mode === item.id ? "active" : ""}
              key={item.id}
              type="button"
              onClick={() => setMode(item.id)}
            >
              <Glyph
                name={
                  item.id === "gallery"
                    ? "grid"
                    : item.id === "screensavers"
                      ? "display"
                      : "heart"
                }
              />
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
      </div>

      <div className="preset-list">
        <p>Presets</p>
        {presetRows.map((preset) => (
          <button
            className={backgroundId === preset.id ? "preset active" : "preset"}
            key={preset.id}
            type="button"
            onClick={() => setBackgroundId(preset.id)}
          >
            <Thumb preset={preset} />
            <span>{preset.name}</span>
            {backgroundId === preset.id ? <i /> : null}
          </button>
        ))}
      </div>
    </aside>
  );
}

function PreviewCard({
  now,
  background,
  clockStyle,
  motion,
  showDate,
  showSeconds,
  showTemp,
  favorite,
  setFavorite,
  onExpand,
}) {
  const cardRef = useRef(null);

  const handlePointerMove = (event) => {
    const card = cardRef.current;
    if (!card) return;
    const box = card.getBoundingClientRect();
    const x = (event.clientX - box.left) / box.width;
    const y = (event.clientY - box.top) / box.height;
    const clampedX = Math.max(0, Math.min(1, x));
    const clampedY = Math.max(0, Math.min(1, y));
    const tiltX = (0.5 - clampedY) * 1.1;
    const tiltY = (clampedX - 0.5) * 1.35;
    card.style.setProperty("--mx", `${clampedX * 100}%`);
    card.style.setProperty("--my", `${clampedY * 100}%`);
    card.style.setProperty("--tilt-x", `${tiltX}deg`);
    card.style.setProperty("--tilt-y", `${tiltY}deg`);
    card.style.setProperty("--light", "0.18");
  };

  const handlePointerLeave = () => {
    const card = cardRef.current;
    if (!card) return;
    card.style.setProperty("--mx", "50%");
    card.style.setProperty("--my", "50%");
    card.style.setProperty("--tilt-x", "0deg");
    card.style.setProperty("--tilt-y", "0deg");
    card.style.setProperty("--light", "0");
  };

  return (
    <div
      className="preview-shell"
      ref={cardRef}
      onPointerMove={handlePointerMove}
      onPointerLeave={handlePointerLeave}
    >
      <div
        className={`preview-card scene-${background.scene ?? "ribbons"}`}
        data-background={background.id}
        data-clock-style={clockStyle}
      >
        <FluidBackground preset={background} speed={motion / 100} />
        <div className="preview-tools">
          <button className="ghost-tool" type="button" onClick={onExpand} aria-label="Open fullscreen preview">
            <Glyph name="expand" />
          </button>
          <button
            className={favorite ? "ghost-tool selected" : "ghost-tool"}
            type="button"
            onClick={() => setFavorite((value) => !value)}
            aria-label="Toggle favorite"
          >
            <Glyph name="heart" />
          </button>
        </div>
        <ClockFace
          styleId={clockStyle}
          now={now}
          showDate={showDate}
          showSeconds={showSeconds}
          showTemp={showTemp}
          temperature={24}
        />
        <div className="pager" aria-hidden="true">
          <span className="active" />
          <span />
          <span />
          <span />
        </div>
      </div>
    </div>
  );
}

function BackgroundRail({ backgroundId, setBackgroundId, backgroundsList }) {
  return (
    <section className="background-rail" aria-label="Background gallery">
      <p>Background</p>
      <div className="rail-scroll">
        {backgroundsList.map((preset) => (
          <button
            key={preset.id}
            className={backgroundId === preset.id ? "thumb-card active" : "thumb-card"}
            type="button"
            onClick={() => setBackgroundId(preset.id)}
            aria-label={`Select ${preset.name}`}
          >
            <Thumb preset={preset} large />
            <span className="thumb-label">{preset.name}</span>
            <span className="thumb-kind">{sceneLabel(preset.scene)}</span>
            {backgroundId === preset.id ? (
              <span className="check">
                <Glyph name="check" />
              </span>
            ) : null}
          </button>
        ))}
      </div>
    </section>
  );
}

function sceneLabel(scene) {
  if (scene === "paint") return "Brush";
  if (scene === "horizon") return "Horizon";
  if (scene === "image") return "Image";
  return "Flow";
}

function SettingsPage({
  settings,
  updateSettings,
  onStart,
}) {
  return (
    <section className="settings-page" aria-label="Clockio settings">
      <div className="settings-hero">
        <div className="settings-heading">
          <p>Settings</p>
          <h2>General</h2>
          <div className="status-line">
            <span />
            <b>{settings.screensaverRunning ? "Active" : "Ready"}</b>
            <small>{settings.displayCount} display{settings.displayCount === 1 ? "" : "s"}</small>
          </div>
        </div>
        <button className="primary-button settings-start" type="button" onClick={onStart}>
          <span>
            <Glyph name="play" />
          </span>
          Start screensaver
        </button>
      </div>

      <div className="settings-grid">
        <section className="settings-panel agent-panel">
          <div className="settings-panel-title">
            <span>App</span>
            <strong>macOS</strong>
          </div>
          <SettingSwitch
            label="Launch at login"
            checked={settings.launchAtLogin}
            onChange={(checked) => updateSettings({ launchAtLogin: checked })}
          />
          <SettingSwitch
            label="Hide Dock icon"
            checked={settings.hideDock}
            onChange={(checked) => updateSettings({ hideDock: checked })}
          />
        </section>

        <section className="settings-panel timer-panel">
          <div className="settings-panel-title">
            <span>Idle Timer</span>
            <strong>{settings.autoStartScreensaver ? `${settings.idleMinutes} min` : "Off"}</strong>
          </div>
          <SettingSwitch
            label="Start after inactivity"
            checked={settings.autoStartScreensaver}
            onChange={(checked) => updateSettings({ autoStartScreensaver: checked })}
          />
          <label className="timer-select">
            <span>After</span>
            <select
              value={settings.idleMinutes}
              disabled={!settings.autoStartScreensaver}
              onChange={(event) =>
                updateSettings({ idleMinutes: Number(event.target.value), autoStartScreensaver: true })
              }
            >
              {idleOptions.map((minutes) => (
                <option key={minutes} value={minutes}>
                  {minutes} minutes
                </option>
              ))}
            </select>
          </label>
        </section>
      </div>
    </section>
  );
}

function SettingSwitch({ label, description, checked, onChange }) {
  return (
    <label className="setting-switch">
      <input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />
      <span className="setting-copy">
        <b>{label}</b>
        {description ? <small>{description}</small> : null}
      </span>
      <span className="switch-track" aria-hidden="true">
        <i />
      </span>
    </label>
  );
}

function Inspector({
  clockStyle,
  setClockStyle,
  background,
  backgroundId,
  setBackgroundId,
  backgroundsList,
  motion,
  setMotion,
  showDate,
  setShowDate,
  showSeconds,
  setShowSeconds,
  showTemp,
  setShowTemp,
  shuffleBackground,
  chooseCustomBackground,
  updateBackgroundColor,
  resetBackgroundColors,
  onStart,
}) {
  return (
    <aside className="inspector">
      <Panel title="Clock Style">
        <div className="style-grid">
          {clockStyles.map((style) => (
            <button
              key={style.id}
              className={clockStyle === style.id ? "style-cell active" : "style-cell"}
              type="button"
              onClick={() => setClockStyle(style.id)}
            >
              <StylePreview id={style.id} />
              <span>{style.name}</span>
            </button>
          ))}
        </div>
      </Panel>

      <Panel title="Background">
        <label className="select-row">
          <Thumb preset={background} />
          <select value={backgroundId} onChange={(event) => setBackgroundId(event.target.value)}>
            {backgroundsList.map((preset) => (
              <option key={preset.id} value={preset.id}>
                {preset.name}
              </option>
            ))}
          </select>
        </label>
        <div className="button-row">
          <button className="secondary-button" type="button" onClick={shuffleBackground}>
            <Glyph name="shuffle" />
            Shuffle
          </button>
          <button className="secondary-button" type="button" onClick={() => setMotion(18)}>
            Slow Fade
          </button>
          <button className="secondary-button" type="button" onClick={chooseCustomBackground}>
            <Glyph name="ray" />
            Load Image
          </button>
        </div>
        {background.customizable ? (
          <PaletteEditor
            colors={background.gradient}
            onChange={updateBackgroundColor}
            onReset={resetBackgroundColors}
          />
        ) : null}
      </Panel>

      <Panel title="Motion">
        <label className="range-block">
          <span>Speed</span>
          <input
            type="range"
            min="8"
            max="100"
            value={motion}
            onChange={(event) => setMotion(Number(event.target.value))}
          />
        </label>
      </Panel>

      <Panel title="Info">
        <Toggle label="Show Temperature" checked={showTemp} onChange={setShowTemp} />
        <Toggle label="Show Date" checked={showDate} onChange={setShowDate} />
        <Toggle label="Show Seconds" checked={showSeconds} onChange={setShowSeconds} />
        <button className="primary-button" type="button" onClick={onStart}>
          <span>
            <Glyph name="play" />
          </span>
          Start Screensaver
        </button>
      </Panel>
    </aside>
  );
}

function PaletteEditor({ colors, onChange, onReset }) {
  return (
    <div className="palette-editor" aria-label="Background colors">
      <div className="palette-swatches">
        {colors.map((color, index) => (
          <label className="color-swatch" key={`${color}-${index}`}>
            <input
              type="color"
              value={color}
              aria-label={`Background color ${index + 1}`}
              onChange={(event) => onChange(index, event.target.value)}
            />
            <span style={{ background: color }} />
          </label>
        ))}
      </div>
      <button className="secondary-button palette-reset" type="button" onClick={onReset}>
        Reset
      </button>
    </div>
  );
}

function Panel({ title, children }) {
  return (
    <section className="panel">
      <h2>{title}</h2>
      {children}
    </section>
  );
}

function Toggle({ label, checked, onChange }) {
  return (
    <label className="toggle-row">
      <input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />
      <span>{label}</span>
    </label>
  );
}

function StylePreview({ id }) {
  if (id === "analog") {
    return (
      <span className="style-preview analog">
        <i />
      </span>
    );
  }
  if (id === "paint") {
    return <span className="style-preview paint">Mar 13</span>;
  }
  if (id === "horizon") {
    return <span className="style-preview horizon">10:32</span>;
  }
  if (id === "flip") {
    return <span className="style-preview flip">12 24</span>;
  }
  if (id === "minimal") {
    return <span className="style-preview minimal">12:24</span>;
  }
  if (id === "codex") {
    return <span className="style-preview codex">12:24</span>;
  }
  return <span className="style-preview digital">12:24</span>;
}

function Thumb({ preset, large = false }) {
  if (preset.imageUrl) {
    return (
      <span className={`${large ? "thumb large" : "thumb"} thumb-image`}>
        <img src={preset.imageUrl} alt="" aria-hidden="true" />
      </span>
    );
  }

  return (
    <span
      className={`${large ? "thumb large" : "thumb"} thumb-${preset.scene ?? "ribbons"}`}
      style={{
        "--c0": preset.gradient[0],
        "--c1": preset.gradient[1],
        "--c2": preset.gradient[2],
        "--c3": preset.gradient[3],
        "--c4": preset.gradient[4],
        "--accent": preset.accent,
      }}
    />
  );
}

function Screensaver({ now, background, clockStyle, motion, showDate, showSeconds, showTemp, temperature, onClose }) {
  return (
    <section
      className={`screensaver scene-${background.scene ?? "ribbons"}`}
      data-background={background.id}
      data-clock-style={clockStyle}
      aria-label="Screensaver mode"
    >
      <FluidBackground preset={background} speed={motion / 100} saver />
      <ClockFace
        styleId={clockStyle}
        now={now}
        showDate={showDate}
        showSeconds={showSeconds}
        showTemp={showTemp}
        temperature={temperature}
        saver
      />
      <button className="exit-saver" type="button" onClick={onClose}>
        Exit
      </button>
    </section>
  );
}

function NoiseLayer() {
  return <div className="noise-layer" aria-hidden="true" />;
}
