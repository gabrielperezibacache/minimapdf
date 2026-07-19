import React from "react";

export function ProgressBar({ value = 0 }) {
  return (
    <div style={{ width: "100%", height: 4, background: "var(--color-border)", borderRadius: "var(--radius-pill)", overflow: "hidden" }}>
      <div style={{ width: `${Math.min(100, Math.max(0, value))}%`, height: "100%", background: "var(--color-accent)", transitionProperty: "width", transitionDuration: "var(--duration-fast)" }} />
    </div>
  );
}
