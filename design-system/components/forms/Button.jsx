import React from "react";

const sizes = {
  sm: { padding: "6px 12px", fontSize: "var(--text-sm)" },
  md: { padding: "9px 16px", fontSize: "var(--text-base)" },
  lg: { padding: "12px 20px", fontSize: "var(--text-md)" },
};

const variants = {
  primary: { background: "var(--color-accent)", color: "var(--emerald-950)", border: "1px solid var(--color-accent)" },
  secondary: { background: "transparent", color: "var(--color-text-primary)", border: "1px solid var(--color-border)" },
  ghost: { background: "transparent", color: "var(--color-text-secondary)", border: "1px solid transparent" },
  danger: { background: "transparent", color: "var(--color-danger)", border: "1px solid var(--color-danger)" },
};

const hover = {
  primary: { background: "var(--color-accent-hover)", borderColor: "var(--color-accent-hover)" },
  secondary: { background: "var(--color-bg-surface)", borderColor: "var(--color-text-secondary)" },
  ghost: { color: "var(--color-text-primary)" },
  danger: { background: "rgba(192,96,74,0.12)" },
};

export function Button({ children, variant = "primary", size = "md", disabled = false, icon = null, onClick }) {
  const [isHover, setHover] = React.useState(false);
  const base = variants[variant] || variants.primary;
  const h = hover[variant] || {};
  return (
    <button
      disabled={disabled}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onClick={onClick}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 8,
        fontFamily: "var(--font-ui)",
        fontWeight: 600,
        letterSpacing: "var(--tracking-tight)",
        borderRadius: "var(--radius-md)",
        cursor: disabled ? "default" : "pointer",
        transitionProperty: "background,border-color,color",
        transitionDuration: "var(--duration-fast)",
        opacity: disabled ? 0.45 : 1,
        ...sizes[size],
        ...base,
        ...(isHover && !disabled ? h : {}),
      }}
    >
      {icon}
      {children}
    </button>
  );
}
