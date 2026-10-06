const { contextBridge, ipcRenderer } = require("electron");

window.addEventListener("DOMContentLoaded", () => {
  document.documentElement.dataset.shell = "electron";
});

contextBridge.exposeInMainWorld("clockio", {
  getSettings: () => ipcRenderer.invoke("clockio:settings:get"),
  updateSettings: (patch) => ipcRenderer.invoke("clockio:settings:update", patch),
  chooseCustomBackground: () => ipcRenderer.invoke("clockio:background:choose"),
  startScreensaver: () => ipcRenderer.invoke("clockio:screensaver:start"),
  stopScreensaver: () => ipcRenderer.invoke("clockio:screensaver:stop"),
  onSettingsChanged: (callback) => {
    const listener = (_event, settings) => callback(settings);
    ipcRenderer.on("clockio:settings:changed", listener);
    return () => ipcRenderer.removeListener("clockio:settings:changed", listener);
  },
});
