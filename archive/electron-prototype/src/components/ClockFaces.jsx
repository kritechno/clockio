import { useMemo } from "react";

const timeFormat = new Intl.DateTimeFormat([], {
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

const secondFormat = new Intl.DateTimeFormat([], {
  second: "2-digit",
});

const dateFormat = new Intl.DateTimeFormat([], {
  weekday: "long",
  month: "long",
  day: "numeric",
});

const paintDateFormat = new Intl.DateTimeFormat([], {
  weekday: "long",
  month: "short",
  day: "numeric",
});

const timeAmPmFormat = new Intl.DateTimeFormat([], {
  hour: "numeric",
  minute: "2-digit",
  hour12: true,
});

const monthShortFormat = new Intl.DateTimeFormat([], { month: "short" });
const weekdayShortFormat = new Intl.DateTimeFormat([], { weekday: "long" });

function splitTime(date) {
  return timeFormat.format(date).replace(".", ":").split(":");
}

function ordinal(day) {
  const mod10 = day % 10;
  const mod100 = day % 100;
  if (mod10 === 1 && mod100 !== 11) return `${day}st`;
  if (mod10 === 2 && mod100 !== 12) return `${day}nd`;
  if (mod10 === 3 && mod100 !== 13) return `${day}rd`;
  return `${day}th`;
}

function formatPaintLine(date) {
  const dateParts = paintDateFormat.formatToParts(date);
  const weekday = dateParts.find((part) => part.type === "weekday")?.value ?? "";
  const month = dateParts.find((part) => part.type === "month")?.value ?? "";
  const day = ordinal(date.getDate());
  return `${weekday}, ${month} ${day} at ${timeAmPmFormat.format(date).replace(" ", "").toLowerCase()}`;
}

export function ClockFace({ styleId, now, showDate, showSeconds, showTemp, temperature = 24, saver = false }) {
  const [hours, minutes] = splitTime(now);
  const seconds = secondFormat.format(now);
  const dateLabel = useMemo(() => dateFormat.format(now), [now]);
  const paintLine = useMemo(() => formatPaintLine(now), [now]);
  const horizonMonth = useMemo(() => monthShortFormat.format(now).toUpperCase(), [now]);
  const horizonWeekday = useMemo(() => weekdayShortFormat.format(now).toUpperCase(), [now]);

  if (styleId === "analog") {
    return (
      <div className={`clock-center analog-stage ${saver ? "saver-scale" : ""}`}>
        <AnalogClock now={now} showSeconds={showSeconds} />
        <MetaLine showDate={showDate} showTemp={showTemp} dateLabel={dateLabel} temperature={temperature} />
      </div>
    );
  }

  if (styleId === "paint") {
    return (
      <div className={`clock-center paint-stage ${saver ? "saver-scale" : ""}`}>
        <div className="paint-line">
          {showDate ? paintLine : timeAmPmFormat.format(now).replace(" ", "").toLowerCase()}
          {showSeconds ? <span>:{seconds}</span> : null}
        </div>
        {showTemp ? <div className="paint-temp">{temperature}C</div> : null}
      </div>
    );
  }

  if (styleId === "horizon") {
    return (
      <div className={`clock-center horizon-stage ${saver ? "saver-scale" : ""}`}>
        <div className="horizon-top">
          {showTemp ? <span>{temperature}C</span> : null}
          {showDate ? <span>{horizonMonth} {now.getDate()}</span> : null}
          {showDate ? <span>{horizonWeekday}</span> : null}
        </div>
        <div className="horizon-time">
          <span>{timeAmPmFormat.format(now).replace(" ", "").replace("AM", "").replace("PM", "")}</span>
          <small>{now.getHours() >= 12 ? "PM" : "AM"}</small>
          {showSeconds ? <em>{seconds}</em> : null}
        </div>
      </div>
    );
  }

  if (styleId === "flip") {
    return (
      <div className={`clock-center flip-stage ${saver ? "saver-scale" : ""}`}>
        <div className="flip-row" aria-label={`${hours}:${minutes}`}>
          <FlipUnit value={hours} />
          <span className="clock-separator">:</span>
          <FlipUnit value={minutes} />
          {showSeconds ? <FlipUnit value={seconds} small /> : null}
        </div>
        <MetaLine showDate={showDate} showTemp={showTemp} dateLabel={dateLabel} temperature={temperature} />
      </div>
    );
  }

  if (styleId === "minimal") {
    return (
      <div className={`clock-center minimal-stage ${saver ? "saver-scale" : ""}`}>
        <div className="minimal-time">
          {hours}
          <span>{minutes}</span>
          {showSeconds ? <small>{seconds}</small> : null}
        </div>
        <MetaLine showDate={showDate} showTemp={showTemp} dateLabel={dateLabel} temperature={temperature} />
      </div>
    );
  }

  if (styleId === "codex") {
    return (
      <div className={`clock-center codex-stage ${saver ? "saver-scale" : ""}`}>
        <div className="codex-rule" />
        <div className="codex-time">
          <span>{hours}</span>
          <i>:</i>
          <span>{minutes}</span>
          {showSeconds ? <small>{seconds}</small> : null}
        </div>
        <div className="codex-meta">
          <span>LOCAL</span>
          {showDate ? <span>{dateLabel}</span> : null}
          {showTemp ? <span>{temperature}C</span> : null}
        </div>
      </div>
    );
  }

  return (
    <div className={`clock-center digital-stage ${saver ? "saver-scale" : ""}`}>
      <div className="digital-time" aria-label={`${hours}:${minutes}`}>
        <span>{hours}</span>
        <i>:</i>
        <span>{minutes}</span>
        {showSeconds ? <small>{seconds}</small> : null}
      </div>
      <MetaLine showDate={showDate} showTemp={showTemp} dateLabel={dateLabel} temperature={temperature} />
    </div>
  );
}

function MetaLine({ showDate, showTemp, dateLabel, temperature }) {
  const items = [];
  if (showDate) items.push(dateLabel);
  if (showTemp) items.push(`${temperature}C`);
  if (items.length === 0) return null;

  return (
    <div className="clock-meta">
      {items.map((item, index) => (
        <span className={index > 0 ? "meta-part with-dot" : "meta-part"} key={item}>
          {item}
        </span>
      ))}
    </div>
  );
}

function FlipUnit({ value, small = false }) {
  return (
    <span className={`flip-unit ${small ? "flip-small" : ""}`}>
      <span>{value}</span>
      <b />
    </span>
  );
}

function AnalogClock({ now, showSeconds }) {
  const seconds = now.getSeconds();
  const minutes = now.getMinutes() + seconds / 60;
  const hours = (now.getHours() % 12) + minutes / 60;

  return (
    <svg className="analog-clock" viewBox="0 0 360 360" role="img" aria-label="Analog clock">
      <defs>
        <radialGradient id="dialGlow" cx="50%" cy="45%" r="58%">
          <stop offset="0%" stopColor="rgba(255,255,255,0.96)" />
          <stop offset="72%" stopColor="rgba(255,255,255,0.22)" />
          <stop offset="100%" stopColor="rgba(255,255,255,0.04)" />
        </radialGradient>
      </defs>
      <circle cx="180" cy="180" r="151" className="analog-rim" />
      <circle cx="180" cy="180" r="132" fill="url(#dialGlow)" opacity="0.22" />
      {Array.from({ length: 60 }).map((_, index) => {
        const angle = index * 6;
        const major = index % 5 === 0;
        return (
          <line
            key={index}
            x1="180"
            y1={major ? "42" : "50"}
            x2="180"
            y2={major ? "62" : "58"}
            className={major ? "analog-tick major" : "analog-tick"}
            transform={`rotate(${angle} 180 180)`}
          />
        );
      })}
      <line
        x1="180"
        y1="180"
        x2="180"
        y2="86"
        className="hand hour"
        transform={`rotate(${hours * 30} 180 180)`}
      />
      <line
        x1="180"
        y1="180"
        x2="180"
        y2="56"
        className="hand minute"
        transform={`rotate(${minutes * 6} 180 180)`}
      />
      {showSeconds ? (
        <line
          x1="180"
          y1="196"
          x2="180"
          y2="50"
          className="hand second"
          transform={`rotate(${seconds * 6} 180 180)`}
        />
      ) : null}
      <circle cx="180" cy="180" r="9" className="pin" />
    </svg>
  );
}
