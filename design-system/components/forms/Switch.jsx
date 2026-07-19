import React from "react";

export function Switch({ checked, onChange }) {
  return (
    <span
      onClick={onChange}
      role="switch"
      aria-checked={checked}
      style={{
        width: 36,
        height: 20,
        borderRadius: "var(--radius-pill)",
        background: checked ? "var(--color-accent)" : "var(--color-bg-surface)",
        border: "1px solid var(--color-border)",
        display: "inline-flex",
        alignItems: "center",
        padding: 2,
        cursor: "pointer",
        transitionProperty: "background",
        transitionDuration: "var(--duration-fast)",
      }}
    >
      <span
        style={{
          width: 14,
          height: 14,
          borderRadius: "50%",
          background: checked ? "var(--emerald-950)" : "var(--color-text-secondary)",
          transform: checked ? "translateX(16px)" : "translateX(0)",
          transitionProperty: "transform,background",
          transitionDuration: "var(--duration-fast)",
        }}
      />
    </span>
  );
}
