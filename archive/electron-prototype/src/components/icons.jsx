export function Glyph({ name, className = "" }) {
  const common = {
    className: `glyph ${className}`,
    width: "20",
    height: "20",
    viewBox: "0 0 24 24",
    fill: "none",
    xmlns: "http://www.w3.org/2000/svg",
    "aria-hidden": "true",
  };

  if (name === "grid") {
    return (
      <svg {...common}>
        <path d="M4.8 5.2h5.1v5.1H4.8V5.2ZM14.1 5.2h5.1v5.1h-5.1V5.2ZM4.8 14.1h5.1v5.1H4.8v-5.1ZM14.1 14.1h5.1v5.1h-5.1v-5.1Z" />
      </svg>
    );
  }

  if (name === "display") {
    return (
      <svg {...common}>
        <path d="M4 6.2h16v10.1H4V6.2Z" />
        <path d="M9 20h6M12 16.4V20" />
      </svg>
    );
  }

  if (name === "heart") {
    return (
      <svg {...common}>
        <path d="M12 19.2s-7.1-4.1-7.1-9.1c0-2.2 1.7-3.8 3.8-3.8 1.4 0 2.6.7 3.3 1.9.7-1.2 1.9-1.9 3.3-1.9 2.2 0 3.8 1.6 3.8 3.8 0 5-7.1 9.1-7.1 9.1Z" />
      </svg>
    );
  }

  if (name === "expand") {
    return (
      <svg {...common}>
        <path d="M8.2 4.8H4.8v3.4M4.8 4.8l5 5M15.8 19.2h3.4v-3.4M19.2 19.2l-5-5M19.2 8.2V4.8h-3.4M19.2 4.8l-5 5M4.8 15.8v3.4h3.4M4.8 19.2l5-5" />
      </svg>
    );
  }

  if (name === "play") {
    return (
      <svg {...common}>
        <path d="M9.1 6.7v10.6c0 .6.7.9 1.2.6l8-5.3c.4-.3.4-.9 0-1.2l-8-5.3c-.5-.3-1.2 0-1.2.6Z" />
      </svg>
    );
  }

  if (name === "shuffle") {
    return (
      <svg {...common}>
        <path d="M4.8 7.2h2.4c1.8 0 2.7 1.2 3.7 3.1l2.2 4.1c.9 1.7 1.9 2.4 3.7 2.4h2.4" />
        <path d="m17.2 14.4 2.4 2.4-2.4 2.4M4.8 16.8h2.4c1.5 0 2.3-.8 3.1-2.2M13.6 8.8c.8-1.1 1.6-1.6 3.2-1.6h2.4M17.2 4.8l2.4 2.4-2.4 2.4" />
      </svg>
    );
  }

  if (name === "settings") {
    return (
      <svg {...common}>
        <path d="M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Z" />
        <path d="M18.4 13.2c.1-.4.1-.8.1-1.2s0-.8-.1-1.2l2-1.5-2-3.4-2.4 1a8 8 0 0 0-2.1-1.2L13.6 3h-3.2l-.4 2.7c-.7.3-1.4.7-2.1 1.2l-2.4-1-2 3.4 2 1.5c-.1.4-.1.8-.1 1.2s0 .8.1 1.2l-2 1.5 2 3.4 2.4-1c.6.5 1.3.9 2.1 1.2l.4 2.7h3.2l.4-2.7c.7-.3 1.4-.7 2.1-1.2l2.4 1 2-3.4-2.1-1.5Z" />
      </svg>
    );
  }

  if (name === "check") {
    return (
      <svg {...common}>
        <path d="m5.2 12.4 4.1 4 9.5-9.6" />
      </svg>
    );
  }

  if (name === "ray") {
    return (
      <svg {...common}>
        <path d="M12 4v2.6M12 17.4V20M4 12h2.6M17.4 12H20M6.3 6.3l1.9 1.9M15.8 15.8l1.9 1.9M17.7 6.3l-1.9 1.9M8.2 15.8l-1.9 1.9" />
        <path d="M12 8.9a3.1 3.1 0 1 0 0 6.2 3.1 3.1 0 0 0 0-6.2Z" />
      </svg>
    );
  }

  return null;
}
