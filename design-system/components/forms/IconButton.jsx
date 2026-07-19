import React from "react";

export function IconButton({ children, active = false, size = 32, title, onClick, disabled = false }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      type="button"
      title={title}
      disabled={disabled}
      onClick={onClick}
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
        background: active ? "rgba(200,154,90,0.14)" : hover && !disabled ? "var(--color-bg-surface)" : "transparent",
        color: active ? "var(--color-accent)" : "var(--color-text-secondary)",
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.45 : 1,
        transitionProperty: "background,color,border-color",
        transitionDuration: "var(--duration-fast)",
      }}
    >
      {children}
    </button>
  );
}
