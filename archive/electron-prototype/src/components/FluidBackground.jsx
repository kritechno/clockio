import { useEffect, useRef } from "react";

function mix(hexA, hexB, t) {
  const a = hexA.match(/\w\w/g).map((v) => parseInt(v, 16));
  const b = hexB.match(/\w\w/g).map((v) => parseInt(v, 16));
  return `rgb(${a.map((v, i) => Math.round(v + (b[i] - v) * t)).join(",")})`;
}

function ribbonProfile(id) {
  const profiles = {
    aurora: { base: 0.4, gap: 0.09, amp: 0.07, ampStep: 0.03, drift: 0.0014, bend: 1.38, weight: 1, cx: 0.5, cy: 0.4 },
    mahogany: { base: 0.48, gap: 0.075, amp: 0.055, ampStep: 0.024, drift: 0.001, bend: 1.08, weight: 1.16, cx: 0.62, cy: 0.62 },
    solar: { base: 0.36, gap: 0.105, amp: 0.09, ampStep: 0.022, drift: 0.0018, bend: 1.64, weight: 1.08, cx: 0.78, cy: 0.56 },
    tide: { base: 0.5, gap: 0.082, amp: 0.045, ampStep: 0.018, drift: 0.00086, bend: 0.92, weight: 1.28, cx: 0.34, cy: 0.52 },
    lumen: { base: 0.33, gap: 0.112, amp: 0.082, ampStep: 0.034, drift: 0.00162, bend: 1.72, weight: 0.94, cx: 0.48, cy: 0.34 },
    ember: { base: 0.43, gap: 0.09, amp: 0.062, ampStep: 0.02, drift: 0.00112, bend: 1.24, weight: 1.04, cx: 0.72, cy: 0.72 },
    codex: { base: 0.38, gap: 0.072, amp: 0.036, ampStep: 0.016, drift: 0.00072, bend: 0.78, weight: 0.86, cx: 0.54, cy: 0.48 },
  };

  return profiles[id] ?? profiles.aurora;
}

export default function FluidBackground({ preset, speed = 0.42, saver = false }) {
  const canvasRef = useRef(null);
  const reducedMotion = useRef(false);
  const isImageBackground = Boolean(preset.imageUrl);

  useEffect(() => {
    reducedMotion.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }, []);

  useEffect(() => {
    if (isImageBackground) return undefined;

    const canvas = canvasRef.current;
    if (!canvas) return undefined;

    const context = canvas.getContext("2d", { alpha: false });
    let frame = 0;
    let running = true;
    let width = 1;
    let height = 1;
    let ratio = 1;
    const pointer = {
      x: 0.5,
      y: 0.52,
      tx: 0.5,
      ty: 0.52,
      force: 0,
      targetForce: 0.05,
      lastMove: 0,
    };
    const profile = ribbonProfile(preset.id);

    const resize = () => {
      const box = canvas.getBoundingClientRect();
      ratio = Math.min(window.devicePixelRatio || 1, saver ? 2 : 1.7);
      width = Math.max(1, Math.floor(box.width * ratio));
      height = Math.max(1, Math.floor(box.height * ratio));
      canvas.width = width;
      canvas.height = height;
    };

    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    resize();

    const handlePointerMove = (event) => {
      const box = canvas.getBoundingClientRect();
      if (!box.width || !box.height) return;
      const x = (event.clientX - box.left) / box.width;
      const y = (event.clientY - box.top) / box.height;
      if (x < -0.2 || x > 1.2 || y < -0.2 || y > 1.2) {
        pointer.targetForce = saver ? 0.05 : 0.025;
        return;
      }
      pointer.tx = Math.max(0, Math.min(1, x));
      pointer.ty = Math.max(0, Math.min(1, y));
      pointer.targetForce = saver ? 0.24 : 0.2;
      pointer.lastMove = performance.now();
    };

    window.addEventListener("pointermove", handlePointerMove, { passive: true });

    const drawRibbon = (time, index, colorA, colorB) => {
      const yBase = height * (profile.base + index * profile.gap);
      const amplitude = height * (profile.amp + index * profile.ampStep);
      const drift = time * (profile.drift + index * 0.00038) * speed;
      const gradient = context.createLinearGradient(0, 0, width, height);
      gradient.addColorStop(0, colorA);
      gradient.addColorStop(0.45, mix(colorA, colorB, 0.4));
      gradient.addColorStop(1, colorB);

      context.beginPath();
      context.moveTo(-width * 0.08, yBase);
      for (let i = 0; i <= 5; i += 1) {
        const x = (width / 5) * i;
        const normalizedX = x / width;
        const normalizedY = yBase / height;
        const dx = normalizedX - pointer.x;
        const dy = normalizedY - pointer.y;
        const pointerWake = Math.exp(-(dx * dx * 7 + dy * dy * 11)) * pointer.force;
        const pull = pointerWake * amplitude * (index % 2 === 0 ? 0.42 : -0.34);
        const y =
          yBase +
          Math.sin(i * profile.bend + drift + pointer.x * 0.22) * amplitude +
          Math.cos(i * 0.9 - drift + pointer.y * 0.18) * amplitude * 0.5 +
          pull;
        const cx = x - width * (0.08 + profile.weight * 0.04);
        context.quadraticCurveTo(cx, y - amplitude * (0.42 + profile.weight * 0.16), x, y);
      }
      context.lineCap = "round";
      context.lineJoin = "round";
      context.strokeStyle = gradient;
      context.lineWidth = Math.max(18, height * (saver ? 0.048 : 0.038) * profile.weight);
      context.globalAlpha = (saver ? 0.24 : 0.2) * (preset.id === "codex" ? 0.72 : 1);
      context.shadowColor = colorB;
      context.shadowBlur = 48 * ratio * profile.weight;
      context.stroke();

      context.lineWidth = Math.max(6, height * (saver ? 0.018 : 0.015) * profile.weight);
      context.globalAlpha = (saver ? 0.42 : 0.34) * (preset.id === "codex" ? 0.82 : 1);
      context.shadowBlur = 20 * ratio;
      context.stroke();
      context.shadowBlur = 0;
    };

    const drawParticles = (time, color) => {
      if (preset.id !== "ember" && preset.id !== "codex") return;
      context.globalAlpha = preset.id === "ember" ? 0.42 : 0.18;
      context.fillStyle = color;
      const count = saver ? 86 : 44;
      for (let i = 0; i < count; i += 1) {
        const seed = i * 97.13;
        const x = ((Math.sin(seed) * 0.5 + 0.5 + time * 0.000018 * speed * (1 + (i % 5))) % 1) * width;
        const y = ((Math.cos(seed * 1.71) * 0.5 + 0.5 + time * 0.000012 * speed * (1 + (i % 4))) % 1) * height;
        const r = (1.2 + (i % 7) * 0.48) * ratio;
        context.beginPath();
        context.arc(x, y, r, 0, Math.PI * 2);
        context.fill();
      }
    };

    const drawPaintScene = (time, colors) => {
      context.globalCompositeOperation = "source-over";
      context.fillStyle = colors[0];
      context.fillRect(0, 0, width, height);

      const drift = time * 0.00026 * speed;
      const brushColors = [colors[1], colors[2], colors[3], colors[4], "#ff4f7b"];
      context.globalCompositeOperation = "source-over";
      brushColors.forEach((color, index) => {
        context.beginPath();
        const startX = width * (-0.05 + index * 0.18);
        context.moveTo(startX, height * 0.92);
        for (let step = 0; step <= 7; step += 1) {
          const x = startX + step * width * 0.105;
          const wave = Math.sin(step * 1.3 + drift + index) * height * 0.09;
          const pointerPull = Math.exp(-Math.abs(x / width - pointer.x) * 2.4) * pointer.force * height * 0.035;
          const y = height * (0.22 + index * 0.03) + wave + pointerPull;
          context.quadraticCurveTo(x - width * 0.04, y + height * 0.14, x, y);
        }
        context.lineCap = "round";
        context.lineJoin = "round";
        context.strokeStyle = color;
        context.globalAlpha = 0.68;
        context.lineWidth = height * (0.16 + index * 0.012);
        context.shadowColor = color;
        context.shadowBlur = 42 * ratio;
        context.stroke();
      });
      context.shadowBlur = 0;
    };

    const drawHorizonScene = (time, colors) => {
      context.globalCompositeOperation = "source-over";
      context.fillStyle = colors[0];
      context.fillRect(0, 0, width, height);

      const drift = time * 0.00036 * speed;
      const gradient = context.createLinearGradient(0, height * 0.35, width, height * 0.75);
      gradient.addColorStop(0, colors[1]);
      gradient.addColorStop(0.22, colors[2]);
      gradient.addColorStop(0.43, "#ffd32e");
      gradient.addColorStop(0.6, colors[3]);
      gradient.addColorStop(0.78, "#075e39");
      gradient.addColorStop(1, colors[4]);

      context.beginPath();
      context.moveTo(-width * 0.08, height * 0.54);
      for (let i = 0; i <= 8; i += 1) {
        const x = (width / 8) * i;
        const y =
          height * 0.5 +
          Math.sin(i * 1.15 + drift) * height * 0.14 +
          Math.cos(i * 0.7 - drift) * height * 0.07 +
          Math.exp(-Math.abs(x / width - pointer.x) * 3) * pointer.force * height * 0.04;
        context.quadraticCurveTo(x - width * 0.08, y - height * 0.08, x, y);
      }
      context.globalCompositeOperation = "source-over";
      context.strokeStyle = gradient;
      context.lineCap = "round";
      context.lineJoin = "round";
      context.globalAlpha = 0.86;
      context.lineWidth = height * 0.28;
      context.shadowColor = "rgba(70, 60, 45, 0.22)";
      context.shadowBlur = 70 * ratio;
      context.stroke();
      context.shadowBlur = 0;
    };

    const render = (time) => {
      if (!running) return;
      frame = requestAnimationFrame(render);

      pointer.x += (pointer.tx - pointer.x) * 0.026;
      pointer.y += (pointer.ty - pointer.y) * 0.026;
      if (time - pointer.lastMove > 1200) {
        pointer.targetForce = saver ? 0.045 : 0.035;
      }
      pointer.force += (pointer.targetForce - pointer.force) * 0.04;

      const colors = preset.gradient;
      const staticTime = reducedMotion.current ? 4000 : time;
      if (preset.scene === "paint") {
        drawPaintScene(staticTime, colors);
        return;
      }

      if (preset.scene === "horizon") {
        drawHorizonScene(staticTime, colors);
        return;
      }

      const base = context.createRadialGradient(
        width * profile.cx,
        height * profile.cy,
        0,
        width * 0.5,
        height * 0.5,
        width * 0.92,
      );
      base.addColorStop(0, colors[1]);
      base.addColorStop(0.42, colors[0]);
      base.addColorStop(0.76, mix(colors[0], colors[2], 0.28));
      base.addColorStop(1, "#020407");
      context.globalAlpha = 1;
      context.globalCompositeOperation = "source-over";
      context.fillStyle = base;
      context.fillRect(0, 0, width, height);

      const wash = context.createLinearGradient(0, 0, width, height);
      wash.addColorStop(0, mix(colors[0], colors[1], preset.id === "tide" ? 0.52 : 0.2));
      wash.addColorStop(0.5, "rgba(255,255,255,0.01)");
      wash.addColorStop(1, mix(colors[0], colors[3], preset.id === "solar" ? 0.5 : 0.28));
      context.globalAlpha = preset.id === "codex" ? 0.18 : 0.28;
      context.globalCompositeOperation = "soft-light";
      context.fillStyle = wash;
      context.fillRect(0, 0, width, height);

      context.globalCompositeOperation = "screen";
      drawRibbon(staticTime, 0, colors[2], colors[3]);
      drawRibbon(staticTime + 1700, 1, colors[1], colors[4]);
      drawRibbon(staticTime + 3300, 2, colors[3], colors[2]);

      const veil = context.createLinearGradient(0, 0, width, height);
      veil.addColorStop(0, "rgba(255,255,255,0.11)");
      veil.addColorStop(0.5, "rgba(255,255,255,0.01)");
      veil.addColorStop(1, "rgba(255,255,255,0.08)");
      context.globalAlpha = 1;
      context.globalCompositeOperation = "overlay";
      context.fillStyle = veil;
      context.fillRect(0, 0, width, height);

      context.globalCompositeOperation = "screen";
      drawParticles(staticTime, colors[4]);

      context.globalCompositeOperation = "source-over";
      const vignette = context.createRadialGradient(width * 0.5, height * 0.45, width * 0.18, width * 0.5, height * 0.5, width * 0.86);
      vignette.addColorStop(0, "rgba(0,0,0,0)");
      vignette.addColorStop(0.72, "rgba(0,0,0,0.1)");
      vignette.addColorStop(1, "rgba(0,0,0,0.72)");
      context.fillStyle = vignette;
      context.fillRect(0, 0, width, height);
    };

    frame = requestAnimationFrame(render);

    return () => {
      running = false;
      cancelAnimationFrame(frame);
      window.removeEventListener("pointermove", handlePointerMove);
      observer.disconnect();
    };
  }, [isImageBackground, preset, saver, speed]);

  if (isImageBackground) {
    return <img className="image-background" src={preset.imageUrl} alt="" aria-hidden="true" />;
  }

  return <canvas className="fluid-canvas" ref={canvasRef} aria-hidden="true" />;
}
