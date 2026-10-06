const {
  app,
  BrowserWindow,
  dialog,
  Menu,
  Tray,
  ipcMain,
  nativeImage,
  nativeTheme,
  net,
  powerMonitor,
  protocol,
  screen,
} = require("electron");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const isDev = Boolean(process.env.VITE_DEV_SERVER_URL);
const CUSTOM_BACKGROUND_ID = "custom";

protocol.registerSchemesAsPrivileged([
  {
    scheme: "clockio",
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      corsEnabled: true,
    },
  },
]);

const DEFAULT_SETTINGS = {
  launchAtLogin: true,
  autoStartScreensaver: true,
  idleMinutes: 5,
  hideDock: true,
  clockStyle: "digital",
  backgroundId: "aurora",
  motion: 42,
  showDate: true,
  showSeconds: false,
  showTemp: true,
  temperature: 24,
  customBackgroundPath: null,
  customBackgroundName: "",
  paletteOverrides: {},
};

const ALLOWED_CLOCK_STYLES = new Set(["digital", "paint", "horizon", "flip", "analog", "minimal", "codex"]);
const ALLOWED_BACKGROUNDS = new Set([
  "aurora",
  "mahogany",
  "spectrum",
  "silk",
  "prism",
  "vellum",
  "dawn-silk",
  "polar-silk",
  "solar",
  "tide",
  "lumen",
  "ember",
  "codex",
  CUSTOM_BACKGROUND_ID,
]);

let mainWindow = null;
let tray = null;
let idleTimer = null;
let settings = { ...DEFAULT_SETTINGS };
let isQuitting = false;
let screensaverWindows = [];

function settingsPath() {
  return path.join(process.env.CLOCKIO_SETTINGS_DIR || app.getPath("userData"), "settings.json");
}

function clampNumber(value, fallback, min, max) {
  const next = Number(value);
  if (!Number.isFinite(next)) return fallback;
  return Math.min(max, Math.max(min, next));
}

function isHexColor(value) {
  return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value);
}

function sanitizePaletteOverrides(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  return Object.fromEntries(
    Object.entries(value)
      .filter(([id, colors]) => ALLOWED_BACKGROUNDS.has(id) && id !== CUSTOM_BACKGROUND_ID && Array.isArray(colors))
      .map(([id, colors]) => [id, colors.slice(0, 5).filter(isHexColor)])
      .filter(([, colors]) => colors.length === 5),
  );
}

function hasCustomBackground() {
  return typeof settings.customBackgroundPath === "string" && fs.existsSync(settings.customBackgroundPath);
}

function customBackgroundUrl() {
  if (!hasCustomBackground()) return null;

  try {
    const stat = fs.statSync(settings.customBackgroundPath);
    return `clockio://custom-background/current?mtime=${Math.round(stat.mtimeMs)}`;
  } catch {
    return "clockio://custom-background/current";
  }
}

function sanitizeStoredSettings(raw = {}) {
  const clean = sanitizeSettingsPatch(raw);

  if (typeof raw.customBackgroundPath === "string" && fs.existsSync(raw.customBackgroundPath)) {
    clean.customBackgroundPath = raw.customBackgroundPath;
    clean.customBackgroundName =
      typeof raw.customBackgroundName === "string" && raw.customBackgroundName.trim()
        ? raw.customBackgroundName.trim()
        : path.basename(raw.customBackgroundPath);
  }

  if (clean.backgroundId === CUSTOM_BACKGROUND_ID && !clean.customBackgroundPath) {
    clean.backgroundId = DEFAULT_SETTINGS.backgroundId;
  }

  return clean;
}

function sanitizeSettingsPatch(patch = {}) {
  const clean = {};

  if (typeof patch.launchAtLogin === "boolean") clean.launchAtLogin = patch.launchAtLogin;
  if (typeof patch.autoStartScreensaver === "boolean") clean.autoStartScreensaver = patch.autoStartScreensaver;
  if (typeof patch.hideDock === "boolean") clean.hideDock = patch.hideDock;
  if (patch.idleMinutes !== undefined) clean.idleMinutes = clampNumber(patch.idleMinutes, settings.idleMinutes, 1, 180);
  if (patch.motion !== undefined) clean.motion = clampNumber(patch.motion, settings.motion, 8, 100);
  if (patch.temperature !== undefined) clean.temperature = clampNumber(patch.temperature, settings.temperature, -80, 80);
  if (typeof patch.showDate === "boolean") clean.showDate = patch.showDate;
  if (typeof patch.showSeconds === "boolean") clean.showSeconds = patch.showSeconds;
  if (typeof patch.showTemp === "boolean") clean.showTemp = patch.showTemp;
  if (ALLOWED_CLOCK_STYLES.has(patch.clockStyle)) clean.clockStyle = patch.clockStyle;
  if (ALLOWED_BACKGROUNDS.has(patch.backgroundId)) clean.backgroundId = patch.backgroundId;
  if (patch.paletteOverrides !== undefined) clean.paletteOverrides = sanitizePaletteOverrides(patch.paletteOverrides);

  return clean;
}

function loadSettings() {
  try {
    const saved = JSON.parse(fs.readFileSync(settingsPath(), "utf8"));
    settings = { ...DEFAULT_SETTINGS, ...sanitizeStoredSettings(saved) };
  } catch {
    settings = { ...DEFAULT_SETTINGS };
  }
}

function saveSettings() {
  fs.mkdirSync(path.dirname(settingsPath()), { recursive: true });
  fs.writeFileSync(settingsPath(), JSON.stringify(settings, null, 2));
}

function customBackgroundDir() {
  return path.join(process.env.CLOCKIO_SETTINGS_DIR || app.getPath("userData"), "custom-backgrounds");
}

function registerAssetProtocol() {
  protocol.handle("clockio", (request) => {
    const url = new URL(request.url);

    if (url.hostname === "custom-background" && hasCustomBackground()) {
      return net.fetch(pathToFileURL(settings.customBackgroundPath).toString());
    }

    return new globalThis.Response("Not found", { status: 404 });
  });
}

async function chooseCustomBackground() {
  const result = await dialog.showOpenDialog(mainWindow ?? undefined, {
    title: "Choose screensaver background",
    properties: ["openFile"],
    filters: [
      {
        name: "Images",
        extensions: ["png", "jpg", "jpeg", "webp", "gif", "heic", "heif", "avif"],
      },
    ],
  });

  if (result.canceled || result.filePaths.length === 0) {
    return publicSettings();
  }

  const sourcePath = result.filePaths[0];
  const ext = path.extname(sourcePath).toLowerCase() || ".png";
  const targetDir = customBackgroundDir();
  const targetPath = path.join(targetDir, `background-${Date.now()}${ext}`);

  fs.mkdirSync(targetDir, { recursive: true });
  fs.copyFileSync(sourcePath, targetPath);

  settings = {
    ...settings,
    backgroundId: CUSTOM_BACKGROUND_ID,
    customBackgroundPath: targetPath,
    customBackgroundName: path.basename(sourcePath),
  };

  saveSettings();
  rebuildTrayMenu();
  broadcastSettings();
  return publicSettings();
}

function syncLaunchAtLogin() {
  if (!app.isReady()) return;
  if (process.env.CLOCKIO_SKIP_LOGIN_SYNC === "1") return;

  app.setLoginItemSettings({
    openAtLogin: settings.launchAtLogin,
    openAsHidden: true,
    name: "Clockio",
  });
}

function publicSettings() {
  return {
    ...settings,
    customBackgroundUrl: customBackgroundUrl(),
    displayCount: screen.getAllDisplays().length,
    screensaverRunning: screensaverWindows.length > 0,
  };
}

function broadcastSettings() {
  const payload = publicSettings();
  BrowserWindow.getAllWindows().forEach((win) => {
    if (!win.isDestroyed()) win.webContents.send("clockio:settings:changed", payload);
  });
}

function updateSettings(patch) {
  settings = { ...settings, ...sanitizeSettingsPatch(patch) };
  saveSettings();
  syncLaunchAtLogin();
  applyDockPolicy();
  rebuildTrayMenu();
  broadcastSettings();
  return publicSettings();
}

function applyDockPolicy() {
  if (process.platform === "darwin" && app.dock) {
    if (settings.hideDock) app.dock.hide();
    else app.dock.show();
  }
}

function rendererUrlParams(extra = {}) {
  return {
    ...extra,
    style: settings.clockStyle,
    background: settings.backgroundId,
    customBackgroundUrl: customBackgroundUrl() ?? "",
    customBackgroundName: settings.customBackgroundName ?? "",
    paletteOverrides: JSON.stringify(settings.paletteOverrides ?? {}),
    motion: String(settings.motion),
    showDate: String(settings.showDate),
    showSeconds: String(settings.showSeconds),
    showTemp: String(settings.showTemp),
    temperature: String(settings.temperature),
  };
}

function loadRenderer(win, query = {}) {
  if (isDev) {
    const url = new URL(process.env.VITE_DEV_SERVER_URL);
    Object.entries(query).forEach(([key, value]) => {
      if (value !== undefined && value !== null) url.searchParams.set(key, value);
    });
    win.loadURL(url.toString());
    return;
  }

  win.loadFile(path.join(__dirname, "../dist/index.html"), { query });
}

function createMainWindow({ showOnReady = true } = {}) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    if (showOnReady) showMainWindow();
    return mainWindow;
  }

  nativeTheme.themeSource = "light";

  mainWindow = new BrowserWindow({
    width: 1440,
    height: 930,
    minWidth: 1080,
    minHeight: 720,
    title: "Clockio",
    titleBarStyle: "hiddenInset",
    trafficLightPosition: { x: 18, y: 18 },
    vibrancy: "under-window",
    visualEffectState: "active",
    backgroundColor: "#f7f5f1",
    show: false,
    skipTaskbar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.once("ready-to-show", () => {
    if (showOnReady) mainWindow.show();
  });

  mainWindow.on("close", (event) => {
    if (isQuitting) return;
    event.preventDefault();
    mainWindow.hide();
  });

  mainWindow.on("show", rebuildTrayMenu);
  mainWindow.on("hide", rebuildTrayMenu);

  mainWindow.on("closed", () => {
    mainWindow = null;
  });

  loadRenderer(mainWindow);
  return mainWindow;
}

function showMainWindow() {
  const win = createMainWindow({ showOnReady: false });
  win.show();
  win.focus();
}

function hideMainWindow() {
  if (mainWindow && !mainWindow.isDestroyed()) mainWindow.hide();
}

function trayIcon() {
  const iconPath = path.join(__dirname, "../build/tray-icon.svg");
  let image = nativeImage.createFromPath(path.join(__dirname, "../build/icon.png")).resize({ width: 18, height: 18 });

  try {
    const svg = fs.readFileSync(iconPath, "utf8");
    const svgImage = nativeImage.createFromDataURL(`data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`);
    if (!svgImage.isEmpty()) image = svgImage.resize({ width: 18, height: 18 });
  } catch {
    // Keep the app icon fallback if the dedicated menu-bar logo is unavailable.
  }

  image.setTemplateImage(true);
  return image;
}

function createTray() {
  tray = new Tray(trayIcon());
  tray.setToolTip("Clockio");
  tray.on("click", () => {
    if (mainWindow && mainWindow.isVisible()) hideMainWindow();
    else showMainWindow();
  });
  rebuildTrayMenu();
}

function rebuildTrayMenu() {
  if (!tray) return;

  const isVisible = Boolean(mainWindow && mainWindow.isVisible());
  const contextMenu = Menu.buildFromTemplate([
    { label: "Clockio", enabled: false },
    { label: isVisible ? "Hide Clockio" : "Open Clockio", click: isVisible ? hideMainWindow : showMainWindow },
    { type: "separator" },
    { label: "Start Screensaver Now", click: () => startScreensaver("manual") },
    {
      label: "Stop Screensaver",
      enabled: screensaverWindows.length > 0,
      click: () => stopScreensaver(),
    },
    { type: "separator" },
    {
      label: "Launch at Login",
      type: "checkbox",
      checked: settings.launchAtLogin,
      click: (item) => updateSettings({ launchAtLogin: item.checked }),
    },
    {
      label: `Idle Start: ${settings.autoStartScreensaver ? `${settings.idleMinutes} min` : "Off"}`,
      enabled: false,
    },
    { type: "separator" },
    {
      label: "Quit Clockio",
      click: () => {
        isQuitting = true;
        stopScreensaver();
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);
}

function createScreensaverWindow(display) {
  const { x, y, width, height } = display.bounds;
  const win = new BrowserWindow({
    x,
    y,
    width,
    height,
    frame: false,
    fullscreen: true,
    movable: false,
    resizable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    autoHideMenuBar: true,
    backgroundColor: "#040812",
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setAlwaysOnTop(true, "screen-saver");
  win.once("ready-to-show", () => {
    win.show();
    win.focus();
  });

  win.on("closed", () => {
    screensaverWindows = screensaverWindows.filter((item) => item !== win);
    rebuildTrayMenu();
    broadcastSettings();
  });

  win.webContents.on("before-input-event", () => {
    stopScreensaver();
  });

  loadRenderer(win, rendererUrlParams({ saver: "1" }));
  return win;
}

function startScreensaver(source = "manual") {
  if (screensaverWindows.length > 0) {
    return { started: false, source, settings: publicSettings() };
  }

  screensaverWindows = screen.getAllDisplays().map((display) => createScreensaverWindow(display));
  rebuildTrayMenu();
  broadcastSettings();
  return { started: true, source, settings: publicSettings() };
}

function stopScreensaver() {
  const windows = [...screensaverWindows];
  screensaverWindows = [];
  windows.forEach((win) => {
    if (!win.isDestroyed()) win.close();
  });
  rebuildTrayMenu();
  broadcastSettings();
  return { stopped: windows.length > 0, settings: publicSettings() };
}

function startIdleWatcher() {
  if (idleTimer) clearInterval(idleTimer);

  idleTimer = setInterval(() => {
    if (!settings.autoStartScreensaver || screensaverWindows.length > 0) return;

    const idleSeconds = powerMonitor.getSystemIdleTime();
    if (idleSeconds >= settings.idleMinutes * 60) {
      startScreensaver("idle");
    }
  }, 5000);
}

function registerIpc() {
  ipcMain.handle("clockio:settings:get", () => publicSettings());
  ipcMain.handle("clockio:settings:update", (_event, patch) => updateSettings(patch));
  ipcMain.handle("clockio:background:choose", () => chooseCustomBackground());
  ipcMain.handle("clockio:screensaver:start", () => startScreensaver("renderer"));
  ipcMain.handle("clockio:screensaver:stop", () => stopScreensaver());
}

app.whenReady().then(() => {
  app.setName("Clockio");
  Menu.setApplicationMenu(null);

  loadSettings();
  registerAssetProtocol();
  applyDockPolicy();
  syncLaunchAtLogin();
  registerIpc();
  createTray();
  startIdleWatcher();

  const loginSettings = app.getLoginItemSettings();
  createMainWindow({ showOnReady: !loginSettings.wasOpenedAtLogin });

  app.on("activate", () => {
    showMainWindow();
  });
});

app.on("before-quit", () => {
  isQuitting = true;
});

app.on("window-all-closed", () => {});
