import React from "react";

export function IconButton({ children, active = false, size = 32, title }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      title={title}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: size,
        height: size,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        borderRadius: "var(--radius-sm)",
        border: active ? "1px solid var(--color-accent)" : "1px solid transparent",
        background: active ? "rgba(200,154,90,0.14)" : hover ? "var(--color-bg-surface)" : "transparent",
        color: active ? "var(--color-accent)" : "var(--color-text-secondary)",
        cursor: "pointer",
        transitionProperty: "background,color,border-color",
        transitionDuration: "var(--duration-fast)",
      }}
    >
      {children}
    </button>
  );
}
